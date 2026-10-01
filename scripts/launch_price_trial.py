"""Open a fresh, isolated Godot 4.6 price trial; never edit the source project.

    python scripts/launch_price_trial.py late2 --godot /path/to/godot
    python scripts/launch_price_trial.py late2 --destination /path/to/trial --resume

baseline = [20, 35], late2 = [20, 70], late3 = [20, 105].
Use --prepare-only to create a fresh copy without starting Godot. Keep the copy
at its original path and resume through this launcher, using the same curve.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import uuid


CURVES = {"baseline": [20, 35], "late2": [20, 70], "late3": [20, 105]}
MANIFEST = "price-trial.json"
RUNTIME = ".price-trial-runtime"
RECEIPT = "price-trial-owner.json"
GROWTH_ANCHOR = b"const GROWTH_COST := [20, 35]"
SAVE_ANCHOR = b'config/custom_user_dir_name="Godot/app_userdata/Loop Conquest - 1G Complete Run v03"'
ENGINE_ERRORS = re.compile(r"(?m)^\s*(?:SCRIPT ERROR:|ERROR:|Parse Error:|FAIL:)")


class TrialError(RuntimeError):
    pass


def digest(data):
    return hashlib.sha256(data).hexdigest()


def json_bytes(value):
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")


def reject_links(path):
    # Refuse symlinks and Windows junctions, including destination ancestors.
    for entry in (path, *path.parents):
        if entry.is_symlink() or (hasattr(entry, "is_junction") and entry.is_junction()):
            raise TrialError(f"Linked paths are not supported: {entry}")


def project_files(root):
    reject_links(root)
    if not (root / "project.godot").is_file() or not (root / "game").is_dir():
        raise TrialError(f"Expected project.godot and game/ in {root}")
    paths = [root / "project.godot", *sorted((root / "game").rglob("*"))]
    contents = {}
    for path in paths:
        reject_links(path)
        if path.is_file():
            contents[path.relative_to(root).as_posix()] = path.read_bytes()
    return contents


def require_once(data, anchor):
    if data.splitlines().count(anchor) != 1 or data.count(anchor) != 1:
        raise TrialError(f"Expected exactly one unchanged anchor: {anchor.decode()}")


def validate_settings(root, config):
    if (root / "override.cfg").exists() or (root / "project.binary").exists():
        raise TrialError("Refusing override.cfg/project.binary; use an unoverridden source/copy")
    # Accept only the source's simple one-assignment-per-line syntax. Godot
    # accepts additional assignments on the same line and escaped quoted names;
    # counting only line-leading keys would miss those effective overrides.
    section = None
    for line in config.splitlines():
        quote = 0
        escaped = False
        assignments = 0
        content_end = len(line)
        for index, char in enumerate(line):
            if quote:
                if escaped:
                    escaped = False
                elif char == 92:  # backslash inside a quoted string
                    escaped = True
                elif char == quote:
                    quote = 0
                    if line[index + 1:].lstrip().startswith(b"="):
                        raise TrialError("Quoted project-setting names are not supported")
            elif char == 59:  # Godot configuration comment: semicolon
                content_end = index
                break
            elif char in (34, 39):  # double/single quoted string
                quote = char
            elif char == 61:
                assignments += 1
                if assignments > 1:
                    raise TrialError("Multiple project-setting assignments per line are not supported")
        if quote:
            raise TrialError("Multiline or unterminated project-setting strings are not supported")
        content = line[:content_end].strip()
        if not content:
            continue
        if content.startswith(b"["):
            header = re.fullmatch(rb"\[([A-Za-z_][A-Za-z0-9_]*)\]", content)
            if not header:
                raise TrialError("Project-setting sections must be standalone bare identifiers")
            section = header.group(1)
        else:
            setting = re.match(rb"^([A-Za-z_][A-Za-z0-9_./]*)\s*=", content)
            if assignments != 1 or not setting:
                raise TrialError("Expected one canonical unquoted setting at the start of the line")
            if section is None and setting.group(1) != b"config_version":
                raise TrialError("Only config_version is supported outside a named section")
    # Feature overrides are resolved by Godot after ordinary settings. Fail closed.
    if re.search(rb"(?m)^\s*config/(?:use_custom_user_dir|custom_user_dir_name)\.", config):
        raise TrialError("User-directory feature overrides are not supported")
    if re.search(rb"(?m)^\s*config/(?:project_settings_override|disable_project_settings_override)(?:\.|\s*=)", config):
        raise TrialError("Project-settings override configuration is not supported")
    require_once(config, b"[application]")
    require_once(config, b"config/use_custom_user_dir=true")
    # Reject duplicates/alternate values, not only missing expected anchors.
    for key in (b"use_custom_user_dir", b"custom_user_dir_name"):
        if len(re.findall(rb"(?m)^\s*config/" + key + rb"\s*=", config)) != 1:
            raise TrialError("Duplicate or malformed user-directory setting")


def patched_files(files, curve, trial_id):
    config = files["project.godot"]
    profile = files["game/run_profile.gd"]
    require_once(config, SAVE_ANCHOR)
    require_once(profile, GROWTH_ANCHOR)
    if len(re.findall(rb"(?m)^\s*const\s+GROWTH_COST\b", profile)) != 1:
        raise TrialError("Duplicate or malformed growth-cost constant")
    changed = dict(files)
    custom_name = f"LoopConquestPriceTrials/{trial_id}"
    changed["project.godot"] = config.replace(
        SAVE_ANCHOR, f'config/custom_user_dir_name="{custom_name}"'.encode()
    ).replace(b"[application]", b"[application]\n\nconfig/disable_project_settings_override=true")
    changed["game/run_profile.gd"] = profile.replace(
        GROWTH_ANCHOR, f"const GROWTH_COST := {CURVES[curve]}".encode()
    )
    return changed, custom_name


def runtime_environment(destination):
    runtime = destination / RUNTIME
    env = dict(os.environ)
    # These changes apply only to the child engine. The caller's environment and
    # normal project/save folders are never changed, including during import.
    for key, folder in {
        "XDG_DATA_HOME": "data", "XDG_CONFIG_HOME": "config",
        "XDG_CACHE_HOME": "cache", "APPDATA": "data", "LOCALAPPDATA": "cache",
    }.items():
        path = runtime / folder
        reject_links(path)
        path.mkdir(parents=True, exist_ok=True)
        env[key] = str(path)
    return env


def user_directory(destination, custom_name):
    root = destination / RUNTIME
    if sys.platform == "darwin":
        # Godot 4.6 macOS OS::get_data_path uses the normal Application Support
        # directory. Do not change HOME; only this unique trial directory is used.
        root = Path.home() / "Library/Application Support"
    elif sys.platform.startswith("linux") or os.name == "nt":
        root = root / "data"
    else:
        raise TrialError("Only Windows, macOS and Linux desktop Godot are supported")
    path = root / custom_name
    reject_links(path)
    return path


def prepare(source, destination, curve, resume=False):
    source = Path(os.path.abspath(source))
    destination = Path(os.path.abspath(destination))
    reject_links(source)
    reject_links(destination)
    if source == destination or source in destination.parents or destination in source.parents:
        raise TrialError("Destination must be outside the source project and its ancestors")
    if resume:
        return verify_copy(destination, curve)
    if destination.exists():
        raise TrialError("Destination already exists; choose a new path or use --resume")
    files = project_files(source)
    if MANIFEST in {p.name for p in source.iterdir()}:
        raise TrialError("Cannot create another trial from a prepared trial copy")
    validate_settings(source, files["project.godot"])
    trial_id = uuid.uuid4().hex
    changed, custom_name = patched_files(files, curve, trial_id)
    manifest = {
        "format": 1, "trial_id": trial_id, "curve": curve, "growth_cost": CURVES[curve],
        "source": str(source), "destination": str(destination), "platform": sys.platform,
        "custom_user_dir_name": custom_name,
        "source_sha256": {name: digest(data) for name, data in files.items()},
        "copy_sha256": {name: digest(data) for name, data in changed.items()},
    }
    manifest_data = json_bytes(manifest)
    # Exclusive creation: a pre-existing directory, even empty, is never adopted.
    destination.mkdir(parents=True, exist_ok=False)
    for name, data in changed.items():
        path = destination / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    (destination / MANIFEST).write_bytes(manifest_data)
    runtime_environment(destination)
    save_dir = user_directory(destination, custom_name)
    save_dir.mkdir(parents=True, exist_ok=False)
    (save_dir / RECEIPT).write_bytes(manifest_data)
    # No profile/gear/currency fixtures belong in a user-playable copy.
    if {name: digest(data) for name, data in project_files(source).items()} != manifest["source_sha256"]:
        raise TrialError("Source changed while copying; discard this incomplete trial and retry")
    return verify_copy(destination, curve)


def verify_copy(destination, curve):
    destination = Path(os.path.abspath(destination))
    reject_links(destination)
    try:
        data = (destination / MANIFEST).read_bytes()
        manifest = json.loads(data)
        if (manifest["format"] != 1 or manifest["curve"] != curve
                or manifest["growth_cost"] != CURVES[curve]
                or manifest["destination"] != str(destination)
                or manifest["platform"] != sys.platform
                or not re.fullmatch(r"[0-9a-f]{32}", manifest["trial_id"])):
            raise TrialError("Curve, path or platform differs from the immutable trial manifest")
        custom_name = f"LoopConquestPriceTrials/{manifest['trial_id']}"
        if manifest["custom_user_dir_name"] != custom_name:
            raise TrialError("Trial profile identity changed")
        files = project_files(destination)
        actual = {name: digest(content) for name, content in files.items()}
        if actual != manifest["copy_sha256"]:
            raise TrialError("Trial project changed; refusing to reuse its existing profile")
        # Validate every expected patch from the source hashes, without requiring
        # the original source checkout to remain available or unchanged on resume.
        config = files["project.godot"]
        require_once(config, b"config/disable_project_settings_override=true")
        original_config = config.replace(b"\n\nconfig/disable_project_settings_override=true", b"")
        original_config = original_config.replace(
            f'config/custom_user_dir_name="{custom_name}"'.encode(), SAVE_ANCHOR
        )
        validate_settings(destination, original_config)
        reconstructed = dict(files)
        reconstructed["project.godot"] = original_config
        reconstructed["game/run_profile.gd"] = files["game/run_profile.gd"].replace(
            f"const GROWTH_COST := {CURVES[curve]}".encode(), GROWTH_ANCHOR
        )
        if {name: digest(content) for name, content in reconstructed.items()} != manifest["source_sha256"]:
            raise TrialError("Source/curve manifest is inconsistent")
        save_dir = user_directory(destination, custom_name)
        # Check all runtime links before reading a receipt or starting the engine.
        for path in (destination / RUNTIME).rglob("*"):
            reject_links(path)
        reject_links(save_dir)
        for path in save_dir.rglob("*"):
            reject_links(path)
        if (save_dir / RECEIPT).read_bytes() != data:
            raise TrialError("Existing profile belongs to a different trial manifest")
        return manifest
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise TrialError(f"Missing or invalid trial copy/profile manifest: {error}") from error


def find_godot(value):
    candidate = value or shutil.which("godot") or shutil.which("godot4")
    if not candidate:
        raise TrialError("Godot 4.6 was not found; pass --godot /path/to/executable")
    path = Path(candidate).expanduser()
    if path.suffix == ".app":
        path = path / "Contents/MacOS/Godot"
    if not path.is_file():
        resolved = shutil.which(str(path))
        if not resolved:
            raise TrialError(f"Godot executable does not exist: {path}")
        path = Path(resolved)
    return path.resolve()


def checked_engine(godot, destination, arguments, timeout=180):
    result = subprocess.run(
        [str(godot), *arguments], cwd=destination, env=runtime_environment(destination),
        text=True, encoding="utf-8", errors="replace", stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, timeout=timeout, check=False,
    )
    if result.returncode or ENGINE_ERRORS.search(result.stdout):
        raise TrialError(f"Godot failed ({result.returncode}):\n{result.stdout}")
    return result.stdout


def import_copy(godot, destination, curve):
    verify_copy(destination, curve)
    version = checked_engine(godot, destination, ["--version"], timeout=20).strip()
    if not re.match(r"^4\.6(?:\.\d+)?\.stable\.", version):
        raise TrialError(f"This launcher requires stable Godot 4.6.x; found {version}")
    checked_engine(godot, destination, ["--headless", "--editor", "--path", str(destination), "--quit"])
    verify_copy(destination, curve)
    return version


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("curve", choices=CURVES)
    parser.add_argument("--destination", type=Path)
    parser.add_argument("--godot", help="Godot 4.6 executable, or Godot.app on macOS")
    parser.add_argument("--resume", action="store_true", help="resume this same immutable copy and curve")
    parser.add_argument("--prepare-only", action="store_true", help="copy only; do not start Godot")
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[1]
    if args.resume and args.destination is None:
        parser.error("--resume requires --destination")
    destination = args.destination or source.parent / (source.name + "-price-trials") / (args.curve + "-" + uuid.uuid4().hex[:12])
    destination = Path(os.path.abspath(destination.expanduser()))
    try:
        godot = None if args.prepare_only else find_godot(args.godot)
        manifest = prepare(source, destination, args.curve, args.resume)
        print(f"Price trial {args.curve}: {manifest['growth_cost']}\nCopy: {destination}\nSaves: {user_directory(destination, manifest['custom_user_dir_name'])}", flush=True)
        engine_option = f' --godot "{godot}"' if godot else ""
        print(f'Resume: python "{Path(__file__).resolve()}" {args.curve} --destination "{destination}" --resume{engine_option}', flush=True)
        if args.prepare_only:
            return 0
        version = import_copy(godot, destination, args.curve)
        print(f"Starting Godot {version}; close the game to return", flush=True)
        return subprocess.run([str(godot), "--path", str(destination)], cwd=destination,
                              env=runtime_environment(destination), check=False).returncode
    except (TrialError, OSError, subprocess.TimeoutExpired) as error:
        print(f"Price trial refused: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
