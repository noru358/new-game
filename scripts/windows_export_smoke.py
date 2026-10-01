"""Verify an exported Windows release starts without an editor or loose project.

Uses standard-library Python and official, checksum-verified Godot 4.6 files.
The report is deliberately limited to runner/headless startup, not device QA.
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
import time
import urllib.request
import zipfile


VERSION = "4.6-stable"
BASE_URL = f"https://github.com/godotengine/godot-builds/releases/download/{VERSION}"
EDITOR_ARCHIVE = f"Godot_v{VERSION}_win64.exe.zip"
TEMPLATE_ARCHIVE = f"Godot_v{VERSION}_export_templates.tpz"
ERROR_PATTERN = re.compile(r"(?m)^\s*(?:SCRIPT ERROR:|ERROR:|Parse Error:|FAIL:)")


def digest(path, algorithm):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, algorithm).hexdigest()


def download(name, destination):
    print(f"Downloading official {name}", flush=True)
    with urllib.request.urlopen(f"{BASE_URL}/{name}", timeout=90) as source:
        with destination.open("wb") as target:
            shutil.copyfileobj(source, target, 1024 * 1024)


def checked_run(arguments, cwd, environment, log_path, timeout):
    started = time.monotonic()
    with log_path.open("w", encoding="utf-8") as log:
        log.write(f"Command: {json.dumps([str(arg) for arg in arguments])}\n")
        log.flush()
        try:
            result = subprocess.run(
                [str(arg) for arg in arguments], cwd=cwd, env=environment,
                stdout=log, stderr=subprocess.STDOUT, timeout=timeout, check=False,
            )
        except subprocess.TimeoutExpired as error:
            raise RuntimeError(f"Timed out after {timeout}s: {log_path.name}") from error
    contents = log_path.read_text(encoding="utf-8", errors="replace")
    if result.returncode != 0 or ERROR_PATTERN.search(contents):
        print(contents, flush=True)
        raise RuntimeError(f"Process/log failure ({result.returncode}): {log_path.name}")
    return {"exit_code": result.returncode, "seconds": round(time.monotonic() - started, 3)}


def smoke(args, report):
    if os.name != "nt":
        raise RuntimeError("This smoke must execute on native Windows, not Wine or Linux")
    workspace = args.workspace.resolve()
    checked_out_commit = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=workspace, text=True,
    ).strip()
    if checked_out_commit != args.commit:
        raise RuntimeError("Checked-out source does not match the requested commit")
    scratch = args.scratch.resolve()
    # Refuse to reuse potentially stale exports or saves. Each job has fresh RUNNER_TEMP.
    scratch.mkdir(parents=True, exist_ok=False)
    downloads = scratch / "downloads"
    downloads.mkdir()
    install_data = scratch / "editor-appdata"
    template_dir = install_data / "Godot/export_templates/4.6.stable"
    template_dir.mkdir(parents=True)
    editor_dir = scratch / "editor"
    editor_dir.mkdir()
    deployment = scratch / "standalone"
    deployment.mkdir()
    runtime_data = scratch / "runtime-appdata"
    runtime_data.mkdir()
    runtime_cache = scratch / "runtime-localappdata"
    runtime_cache.mkdir()

    sums = downloads / "SHA512-SUMS.txt"
    download(sums.name, sums)
    checksums = {}
    for line in sums.read_text(encoding="utf-8").splitlines():
        fields = line.split()
        if len(fields) == 2:
            checksums[fields[1].lstrip("*")] = fields[0].lower()
    report["downloads"] = []
    for name in (EDITOR_ARCHIVE, TEMPLATE_ARCHIVE):
        archive = downloads / name
        download(name, archive)
        actual = digest(archive, "sha512")
        if actual != checksums.get(name):
            raise RuntimeError(f"Official SHA512 mismatch or missing checksum: {name}")
        report["downloads"].append({"url": f"{BASE_URL}/{name}", "sha512": actual})
        with zipfile.ZipFile(archive) as bundle:
            for entry in bundle.infolist():
                filename = Path(entry.filename).name
                if name == EDITOR_ARCHIVE and filename in (
                    f"Godot_v{VERSION}_win64.exe", f"Godot_v{VERSION}_win64_console.exe"
                ):
                    target = editor_dir / filename
                elif name == TEMPLATE_ARCHIVE and entry.filename.startswith("templates/") and (
                    filename.startswith("windows_") or filename == "version.txt"
                ) and not entry.is_dir():
                    target = template_dir / filename
                else:
                    continue
                with bundle.open(entry) as source, target.open("wb") as destination:
                    shutil.copyfileobj(source, destination)

    editor = editor_dir / f"Godot_v{VERSION}_win64_console.exe"
    editor_env = dict(os.environ, APPDATA=str(install_data), LOCALAPPDATA=str(runtime_cache))
    report["import"] = checked_run(
        [editor, "--headless", "--editor", "--path", workspace, "--quit"],
        workspace, editor_env, args.report / "import.log", 180,
    )
    executable = deployment / "LoopConquest.exe"
    report["export"] = checked_run(
        [editor, "--headless", "--path", workspace, "--export-release", "Windows", executable],
        workspace, editor_env, args.report / "export.log", 180,
    )
    if not executable.is_file() or executable.stat().st_size < 1024 * 1024:
        raise RuntimeError("Windows release executable is missing or unexpectedly small")
    report["executable"] = {"name": executable.name, "bytes": executable.stat().st_size,
                            "sha256": digest(executable, "sha256")}
    # Start the actual exported GUI executable, not the editor or console wrapper.
    # An empty standalone working directory prevents a loose project fallback.
    if (deployment / "project.godot").exists() or (deployment / "game").exists():
        raise RuntimeError("Standalone export directory unexpectedly contains project sources")
    runtime_env = dict(os.environ, APPDATA=str(runtime_data), LOCALAPPDATA=str(runtime_cache))
    engine_log = args.report / "startup-engine.log"
    report["startup"] = checked_run(
        [executable, "--headless", "--verbose", "--max-fps", "60", "--quit-after", "120",
         "--log-file", engine_log],
        deployment, runtime_env, args.report / "startup-process.log", 45,
    )
    contents = engine_log.read_text(encoding="utf-8", errors="replace")
    if ERROR_PATTERN.search(contents):
        raise RuntimeError("Exported game reports an engine/script error; see startup-engine.log")
    if "Godot Engine v4.6.stable.official" not in contents:
        raise RuntimeError("Expected official release engine banner missing")
    main_scene = "res://game/travel_camp.tscn"
    exported_scenes = {main_scene}
    # Default exports remap text scenes to binary .scn resources. Read the real
    # export cache rather than weakening the check to any matching filename.
    for cache in (workspace / ".godot/exported").glob("*/file_cache"):
        for line in cache.read_text(encoding="utf-8").splitlines():
            fields = line.split("::")
            if len(fields) == 4 and fields[0] == main_scene:
                exported_scenes.add(fields[3])
    loaded_scene = next((scene for scene in sorted(exported_scenes)
                         if f"Loading resource: {scene}" in contents), None)
    if loaded_scene is None:
        raise RuntimeError("Exported game did not report loading its configured camp scene")
    config = (workspace / "project.godot").read_text(encoding="utf-8")
    custom_dir = re.search(r'^config/custom_user_dir_name="([^\"]+)"$', config, re.MULTILINE)
    if not custom_dir or 'config/use_custom_user_dir=true' not in config:
        raise RuntimeError("User-data isolation check needs the current custom-directory contract")
    expected_user_dir = (runtime_data / custom_dir.group(1)).resolve()
    if not expected_user_dir.is_relative_to(runtime_data) or not expected_user_dir.is_dir():
        raise RuntimeError("Expected isolated Godot user-data directory was not created")
    report["startup"].update({"main_scene": main_scene, "loaded_scene_resource": loaded_scene,
                              "quit_after_iterations_requested": 120,
                              "isolated_user_data": str(expected_user_dir)})
    report["status"] = "passed"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--scratch", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--commit", required=True)
    args = parser.parse_args()
    args.report = args.report.resolve()
    args.report.mkdir(parents=True, exist_ok=True)
    report = {"source_commit": args.commit, "godot": VERSION, "status": "failed",
              "scope": "Windows runner headless release export/startup only; no GPU, input, audio or play acceptance"}
    try:
        smoke(args, report)
    except Exception as error:
        report["error"] = str(error)
        print(f"SMOKE FAILED: {error}", file=sys.stderr)
    finally:
        (args.report / "summary.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
