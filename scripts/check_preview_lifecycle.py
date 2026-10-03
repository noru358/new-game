#!/usr/bin/env python3
"""Bounded three-runtime shared-preview restart contract; synthetic wins, not gameplay QA.

Only a freshly created, owner-marked evidence directory is touched. The actual v45
preview save-family name is tested under a new XDG_DATA_HOME, never normal userdata.
One editor import prepares resources; A/B/C are three fresh runtime processes.
"""
from __future__ import annotations
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

FAMILY = "LoopConquest-FieldPreview-v45"
MARKER = ".preview-lifecycle-owner.json"
GUARDED = ("game", "project.godot")


def hashes(root: Path, include_imports: bool = False) -> dict[str, str]:
    paths = [root / "project.godot"] + sorted((root / "game").rglob("*"))
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in paths if p.is_file() and (include_imports or not p.name.endswith(".import"))}


def dump(path: Path, obj: object) -> None:
    path.write_text(json.dumps(obj, indent=2, sort_keys=True) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="/usr/local/bin/godot")
    parser.add_argument("--output", type=Path, help="New directory only; existing directories are rejected")
    args = parser.parse_args()
    if sys.platform != "linux":
        parser.error("This launcher guards Linux XDG paths only")
    source = Path(__file__).resolve().parents[1]
    token = uuid.uuid4().hex
    output = (args.output or source / "docs/measurements/preview-lifecycle-v46" / ("run-" + token[:12])).absolute()
    if output.exists() or output.is_symlink():
        parser.error("Output must not exist; no reuse, cleanup or deletion of prior data is permitted")
    if source not in output.parents:
        parser.error("Output must be inside this worktree")
    # Resolve the existing parent first: do not allow a symlink to escape the worktree.
    if source.resolve() not in output.parent.resolve().parents and output.parent.resolve() != source.resolve():
        parser.error("Output parent escapes the worktree")
    output.mkdir(parents=True)
    output = output.resolve()
    project, home, data = output / "project", output / "home", output / "xdg-data"
    expected_data = data / FAMILY
    owner = {"suite": "preview-lifecycle-v46", "token": token, "source": str(source),
             "output": str(output), "project": str(project), "userdata": str(expected_data)}
    dump(output / MARKER, owner)
    before = hashes(source, True)
    dump(output / "source-before.json", before)
    report = {"passed": False, "source_commit": subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=source, text=True).strip(),
        "scope": "Synthetic state contracts; not natural wins, power-loss durability, balance or human acceptance",
        "save_family": FAMILY, "processes": [], "owner": owner}
    try:
        project.mkdir()
        shutil.copytree(source / "game", project / "game", ignore=shutil.ignore_patterns("*.import"))
        (project / "tests").mkdir()
        shutil.copy2(source / "tests/preview_lifecycle_scenario.gd", project / "tests/preview_lifecycle_scenario.gd")
        config = (source / "project.godot").read_text()
        anchor = 'config/custom_user_dir_name="Godot/app_userdata/Loop Conquest - 1G Complete Run v03"'
        entry = 'run/main_scene="res://game/travel_camp.tscn"'
        if config.count(anchor) != 1 or config.count(entry) != 1:
            raise RuntimeError("Unexpected source save/main-scene contract")
        if re.search(r"(?m)^config/(?:custom_user_dir_name|use_custom_user_dir)\.", config):
            raise RuntimeError("Feature-specific userdata override is unsupported")
        config = config.replace(anchor, f'config/custom_user_dir_name="{FAMILY}"')
        config = config.replace(entry, 'run/main_scene="res://game/field_preview_entry.tscn"')
        (project / "project.godot").write_text(config)
        for directory in (home, data, output / "xdg-config", output / "xdg-cache", expected_data):
            directory.mkdir(parents=True, exist_ok=True)
        dump(expected_data / MARKER, owner)
        dump(home / MARKER, owner)
        env = dict(os.environ, HOME=str(home), XDG_DATA_HOME=str(data),
                   XDG_CONFIG_HOME=str(output / "xdg-config"), XDG_CACHE_HOME=str(output / "xdg-cache"),
                   PREVIEW_LIFECYCLE_OUTPUT=str(output), PREVIEW_LIFECYCLE_USERDATA=str(expected_data),
                   PREVIEW_LIFECYCLE_TOKEN=token, GODOT_SILENCE_ROOT_WARNING="1")
        immutable = hashes(project)
        dump(output / "copy-before.json", immutable)

        def run(name: str, options: list[str]) -> None:
            if hashes(project) != immutable or hashes(source, True) != before:
                raise RuntimeError("Source/copy changed before process " + name)
            log_path = output / (name + ".txt")
            command = [args.godot, "--headless", "--path", str(project)] + options
            with log_path.open("w") as log:
                process = subprocess.Popen(command, cwd=project, env=dict(env, PREVIEW_LIFECYCLE_PHASE=name),
                                           stdout=log, stderr=subprocess.STDOUT)
                try:
                    code = process.wait(timeout=180)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
                    raise RuntimeError(name + " exceeded the 180-second bounded phase timeout")
            content = log_path.read_text()
            failed = any(s in content for s in ("SCRIPT ERROR:", "Parse Error:", "FAIL:", "ERROR:", "leaked"))
            result = {"phase": name, "pid": process.pid, "exit_code": code,
                      "passed": code == 0 and not failed, "log": log_path.name}
            report["processes"].append(result)
            dump(output / "summary.json", report)
            print(name + (" PASS" if result["passed"] else " FAIL"), flush=True)
            if not result["passed"]:
                raise RuntimeError(name + " failed; first-divergence evidence retained in " + str(output))
            after_copy = hashes(project)
            generated_uids = set(after_copy) - set(immutable)
            allowed = name == "import" and all(p.endswith(".gd.uid") for p in generated_uids)
            if any(after_copy.get(p) != digest for p, digest in immutable.items()) or (generated_uids and not allowed) or hashes(source, True) != before:
                raise RuntimeError("Source/copy changed while running " + name)

        run("import", ["--editor", "--quit"])
        immutable = hashes(project)  # Import-only .gd.uid generation is now frozen too.
        dump(output / "copy-runtime-baseline.json", immutable)
        for phase in ("A", "B", "C"):
            run(phase, ["--script", "res://tests/preview_lifecycle_scenario.gd"])
        phases = [json.loads((output / (p + "-report.json")).read_text()) for p in ("A", "B", "C")]
        if len(set(p["pid"] for p in phases)) != 3 or phases[-1]["settlements"] != 7 or phases[-1]["departures"] != 8:
            raise RuntimeError("Unexpected process or lifecycle counts")
        report.update(passed=True, runtime_process_count=3, import_process_count=1,
                      checks=sum(p["checks"] for p in phases), settlements=7, abandoned_departures=1,
                      final_profile=phases[-1]["profile"], final_unlocks=phases[-1]["unlocks"])
    except Exception as exc:
        report["error"] = str(exc)
        print(str(exc), file=sys.stderr)
    finally:
        after = hashes(source, True)
        dump(output / "source-after.json", after)
        report["source_hashes_preserved"] = before == after
        report["passed"] = report["passed"] and before == after
        dump(output / "summary.json", report)
        print("Evidence: " + str(output), flush=True)
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
