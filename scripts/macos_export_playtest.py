"""Build and verify a self-contained macOS playtest on standard hosted runners.

The actual distributed ZIP is extracted and started headlessly, with no loose
project or editor beside it. This is package/startup evidence, not device QA.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import plistlib
import re
import shutil
import subprocess
import sys
import time
import urllib.request
import zipfile

from windows_export_smoke import verify_release_contents

VERSION = "4.6.3-stable"
BASE_URL = f"https://github.com/godotengine/godot-builds/releases/download/{VERSION}"
SAVE_NAME = "Godot/app_userdata/Loop Conquest - 1G Complete Run v03"
ARCHIVE_NAME = "LoopConquest-v38-macOS.zip"
ERROR_PATTERN = re.compile(r"(?m)^\s*(?:SCRIPT ERROR:|ERROR:|Parse Error:|FAIL:)")


def digest(path, algorithm="sha256"):
    hasher = hashlib.new(algorithm)
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def run(arguments, cwd, log_path, timeout=180, check_errors=True):
    started = time.monotonic()
    display_arguments = [str(arg) for arg in arguments]
    for variable in ("RUNNER_TEMP", "GITHUB_WORKSPACE"):
        value = os.environ.get(variable)
        if value:
            display_arguments = [arg.replace(value, f"${variable}") for arg in display_arguments]
    with log_path.open("w", encoding="utf-8") as log:
        log.write(f"Command: {json.dumps(display_arguments)}\n")
        log.flush()
        result = subprocess.run([str(arg) for arg in arguments], cwd=cwd,
                                stdout=log, stderr=subprocess.STDOUT,
                                timeout=timeout, check=False)
    contents = log_path.read_text(encoding="utf-8", errors="replace")
    if result.returncode or (check_errors and ERROR_PATTERN.search(contents)):
        print(contents, flush=True)
        raise RuntimeError(f"Process/log failure ({result.returncode}): {log_path.name}")
    return {"exit_code": result.returncode, "seconds": round(time.monotonic() - started, 3)}


def download(name, destination):
    print(f"Downloading official {name}", flush=True)
    with urllib.request.urlopen(f"{BASE_URL}/{name}", timeout=120) as source:
        with destination.open("wb") as target:
            shutil.copyfileobj(source, target, 1024 * 1024)


def app_files(app):
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    executable = app / "Contents/MacOS" / info["CFBundleExecutable"]
    packs = list((app / "Contents/Resources").glob("*.pck"))
    if not executable.is_file() or not os.access(executable, os.X_OK) or len(packs) != 1:
        raise RuntimeError("App executable mode or embedded pack is invalid")
    if packs[0].stat().st_size < 100000 or info["CFBundleIdentifier"] != "com.noru358.loopconquest1a":
        raise RuntimeError("Unexpected resource pack or app identity")
    archs = subprocess.check_output(["lipo", "-archs", str(executable)], text=True).split()
    if set(archs) != {"arm64", "x86_64"}:
        raise RuntimeError(f"Expected Universal 2 architectures, got {archs}")
    return executable, packs[0], info, archs


def build(args, report):
    workspace = args.workspace.resolve()
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=workspace, text=True).strip()
    tree = subprocess.check_output(["git", "rev-parse", "HEAD^{tree}"], cwd=workspace, text=True).strip()
    if commit != args.commit or tree != args.tree:
        raise RuntimeError("Source commit/tree does not match the frozen v38 source")
    config = (workspace / "project.godot").read_text()
    for expected in ['config/name="Loop Conquest - Consolidated Playtest v38"',
                     f'config/custom_user_dir_name="{SAVE_NAME}"',
                     'config/use_custom_user_dir=true',
                     'run/main_scene="res://game/travel_camp.tscn"']:
        if expected not in config:
            raise RuntimeError(f"Unexpected project contract: {expected}")
    downloads = args.scratch / "downloads"
    downloads.mkdir()
    editor_dir = args.scratch / "editor"
    editor_dir.mkdir()
    download("SHA512-SUMS.txt", downloads / "SHA512-SUMS.txt")
    checksums = {}
    for line in (downloads / "SHA512-SUMS.txt").read_text().splitlines():
        fields = line.split()
        if len(fields) == 2:
            checksums[fields[1].lstrip("*")] = fields[0].lower()
    report["downloads"] = []
    editor_archive = f"Godot_v{VERSION}_macos.universal.zip"
    template_archive = f"Godot_v{VERSION}_export_templates.tpz"
    for name in (editor_archive, template_archive):
        path = downloads / name
        download(name, path)
        actual = digest(path, "sha512")
        if actual != checksums.get(name):
            raise RuntimeError(f"Official SHA512 mismatch: {name}")
        report["downloads"].append({"url": f"{BASE_URL}/{name}", "sha512": actual})
    run(["ditto", "-x", "-k", downloads / editor_archive, editor_dir],
        args.scratch, args.report / "extract-editor.log")
    editor = editor_dir / "Godot.app/Contents/MacOS/Godot"
    # Official editor self-contained mode; HOME and system permissions are untouched.
    (editor_dir / "_sc_").touch()
    template_dir = editor_dir / "editor_data/export_templates/4.6.3.stable"
    template_dir.mkdir(parents=True)
    with zipfile.ZipFile(downloads / template_archive) as bundle:
        for name in ("macos.zip", "version.txt"):
            (template_dir / name).write_bytes(bundle.read(f"templates/{name}"))
    report["import"] = run([editor, "--headless", "--editor", "--path", workspace, "--quit"],
                           workspace, args.report / "import.log")
    package = args.scratch / "LoopConquest-v38-macOS"
    package.mkdir()
    app = package / "LoopConquest-v38.app"
    report["export"] = run([editor, "--headless", "--path", workspace,
                            "--export-release", "macOS", app],
                           workspace, args.report / "export.log")
    report["release_contents"] = verify_release_contents(workspace, (args.report / "export.log").read_text())
    executable, pack, info, archs = app_files(app)
    report["signature"] = run(["codesign", "--verify", "--deep", "--strict", "--verbose=2", app],
                              package, args.report / "signature-verify.log")
    run(["codesign", "--display", "--verbose=4", app], package, args.report / "signature-display.log")
    signature = (args.report / "signature-display.log").read_text()
    if "Signature=adhoc" not in signature:
        raise RuntimeError("Expected the configured built-in ad-hoc signature")
    main_scene = "res://game/travel_camp.tscn"
    camp_resources = {main_scene}
    for cache in (workspace / ".godot/exported").glob("*/file_cache"):
        for line in cache.read_text().splitlines():
            fields = line.split("::")
            if len(fields) == 4 and fields[0] == main_scene:
                camp_resources.add(fields[3])
    metadata = {"source_commit": commit, "source_tree": tree, "godot": VERSION,
                "architectures": archs, "signature": "ad-hoc; not Apple notarized",
                "executable": str(executable.relative_to(app)), "executable_sha256": digest(executable),
                "pack": str(pack.relative_to(app)), "pack_sha256": digest(pack),
                "main_scene": main_scene, "camp_resources": sorted(camp_resources),
                "save_directory": f"~/Library/Application Support/{SAVE_NAME}",
                "prices": "baseline 20/35"}
    (package / "BUILD_INFO.json").write_text(json.dumps(metadata, indent=2) + "\n")
    shutil.copyfile(Path(__file__).with_name("macos_playtest_README_KO.txt"), package / "먼저 읽어주세요.txt")
    notices_url = "https://raw.githubusercontent.com/godotengine/godot/4.6.3-stable/COPYRIGHT.txt"
    with urllib.request.urlopen(notices_url, timeout=60) as source:
        (package / "GODOT_COPYRIGHT.txt").write_bytes(source.read())
    # No content is added to the signed .app after export.
    archive = args.report / ARCHIVE_NAME
    run(["ditto", "-c", "-k", "--keepParent", package, archive], args.scratch,
        args.report / "package.log")
    subprocess.run(["git", "diff", "--exit-code", "HEAD"], cwd=workspace, check=True)
    report["build_info"] = metadata
    return archive


def verify_archive(args, archive, report):
    extracted = args.scratch / "distributed"
    extracted.mkdir()
    with zipfile.ZipFile(archive) as bundle:
        for entry in bundle.infolist():
            path = Path(entry.filename)
            if path.is_absolute() or ".." in path.parts:
                raise RuntimeError("Unsafe ZIP path")
        if bundle.testzip() is not None:
            raise RuntimeError("Distributed ZIP CRC check failed")
    run(["ditto", "-x", "-k", archive, extracted], args.scratch, args.report / "extract-distributed.log")
    package = extracted / "LoopConquest-v38-macOS"
    app = package / "LoopConquest-v38.app"
    metadata = json.loads((package / "BUILD_INFO.json").read_text())
    if metadata["source_commit"] != args.commit or metadata["source_tree"] != args.tree:
        raise RuntimeError("Distributed source identity mismatch")
    executable, pack, info, archs = app_files(app)
    if digest(executable) != metadata["executable_sha256"] or digest(pack) != metadata["pack_sha256"]:
        raise RuntimeError("Distributed executable/pack checksum mismatch")
    report["distributed_signature"] = run(
        ["codesign", "--verify", "--deep", "--strict", "--verbose=2", app],
        extracted, args.report / "distributed-signature.log")
    if (extracted / "project.godot").exists() or (extracted / "game").exists():
        raise RuntimeError("Unexpected loose source in runtime directory")
    user_dir = Path.home() / "Library/Application Support" / SAVE_NAME
    # This is a fresh disposable GitHub-hosted account, never the user's Mac.
    # macOS user:// does not follow Linux XDG/Windows APPDATA overrides.
    # Import/export can create empty engine directories. No campaign profile or
    # unlock file may exist before the exported game is started.
    prior_profiles = [p for p in user_dir.rglob("*") if p.is_file() and
                      (p.name.startswith("loop_conquest_profile") or p.name.startswith("loop_conquest_1d_unlocks"))]
    if prior_profiles:
        raise RuntimeError("Refusing startup: campaign profile/unlock files already exist")
    report["profile"]["campaign_files_absent_before_startup"] = True
    engine_log = args.report / "startup-engine.log"
    report["startup"] = run([executable, "--headless", "--verbose", "--max-fps", "60",
                             "--quit-after", "120", "--log-file", engine_log],
                            extracted, args.report / "startup-process.log", 45)
    contents = engine_log.read_text(encoding="utf-8", errors="replace")
    if ERROR_PATTERN.search(contents) or "Godot Engine v4.6.3.stable.official" not in contents:
        raise RuntimeError("Engine/script error or wrong version in exported game log")
    loaded_scene = next((scene for scene in metadata["camp_resources"]
                         if f"Loading resource: {scene}" in contents), None)
    if loaded_scene is None or not user_dir.is_dir():
        raise RuntimeError("Expected camp resource/user-data directory was not loaded")
    report["profile"]["created_after"] = True
    report["startup"].update({"loaded_scene_resource": loaded_scene, "native_architecture": platform.machine(),
                              "quit_after_iterations_requested": 120})
    report["archive"] = {"name": archive.name, "bytes": archive.stat().st_size,
                         "sha256": digest(archive), "architectures": archs,
                         "executable_sha256": digest(executable), "pack_sha256": digest(pack)}
    report["status"] = "passed"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", type=Path)
    parser.add_argument("--scratch", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--tree", required=True)
    parser.add_argument("--verify-archive", type=Path)
    args = parser.parse_args()
    args.scratch = args.scratch.resolve()
    args.report = args.report.resolve()
    args.report.mkdir(parents=True, exist_ok=True)
    report = {"source_commit": args.commit, "source_tree": args.tree, "godot": VERSION, "status": "failed",
              "scope": "native macOS hosted-runner package/signature/headless startup only; no interactive GPU/input/audio/device acceptance"}
    try:
        if sys.platform != "darwin" or os.environ.get("RUNNER_ENVIRONMENT") != "github-hosted":
            raise RuntimeError("Use a fresh standard GitHub-hosted macOS runner only")
        user_dir = Path.home() / "Library/Application Support" / SAVE_NAME
        if user_dir.exists():
            raise RuntimeError("Refusing job: campaign data directory already exists")
        report["profile"] = {"path": f"~/Library/Application Support/{SAVE_NAME}", "directory_absent_before_job": True,
                             "context": "fresh disposable GitHub-hosted runner account; HOME unchanged"}
        args.scratch.mkdir(parents=True, exist_ok=False)
        archive = args.verify_archive.resolve() if args.verify_archive else build(args, report)
        verify_archive(args, archive, report)
    except Exception as error:
        report["error"] = str(error)
        print(f"MACOS PLAYTEST FAILED: {error}", file=sys.stderr)
    finally:
        (args.report / "summary.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
