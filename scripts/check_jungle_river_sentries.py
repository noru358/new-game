#!/usr/bin/env python3
"""Prepare a private Mac project, apply only the mount patch, verify and compare.

Never changes HOME, source files or the ordinary game's save directory.
The Mac engine creates one unique Application Support/LoopConquestMapTrials dir.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import uuid


def hashes(paths):
    return {str(p): hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else "absent" for p in paths}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--render", action="store_true")
    parser.add_argument("--render-only", action="store_true", help="new isolated copy; rerun only capture after a capture-tool repair")
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    if output.exists() or source == output or source in output.parents:
        parser.error("output must be a new directory outside the source")
    output.mkdir(parents=True)
    project = output / "project"
    project.mkdir()
    for name in ("game", "tests"):
        shutil.copytree(source / name, project / name)
    trial_id = str(uuid.uuid4())
    config = (source / "project.godot").read_text()
    anchor = 'config/custom_user_dir_name="Godot/app_userdata/Loop Conquest - 1G Complete Run v03"'
    assert config.count(anchor) == 1
    (project / "project.godot").write_text(config.replace(anchor, f'config/custom_user_dir_name="LoopConquestMapTrials/{trial_id}"'))
    subprocess.run(["git", "apply", str(source / "patches/jungle-river-sentry-mount.patch")], cwd=project, check=True)
    protected_source = [source / "project.godot"] + sorted((source / "game").rglob("*"))
    protected_source = [p for p in protected_source if p.is_file()]
    normal = Path.home() / "Library/Application Support/Godot/app_userdata/Loop Conquest - 1G Complete Run v03"
    protected_saves = [normal / "play_settings.cfg"] + [normal / (prefix + suffix) for prefix in ("loop_conquest_profile", "loop_conquest_1d_unlocks") for suffix in ("_a.json", "_b.json")]
    before = hashes(protected_source + protected_saves)
    results = []

    def run(name, options, env=None):
        with (output / (name + ".log")).open("w") as log:
            result = subprocess.run([args.godot, "--path", str(project)] + options, stdout=log, stderr=subprocess.STDOUT, env=env, timeout=240)
        text = (output / (name + ".log")).read_text()
        passed = result.returncode == 0 and not any(marker in text for marker in ("SCRIPT ERROR:", "Parse Error:", "FAIL:", "leaked"))
        results.append({"name": name, "exit_code": result.returncode, "passed": passed})
        print(name, "PASS" if passed else "FAIL", flush=True)
        if not passed:
            print(text)
        return passed

    try:
        if not run("import", ["--headless", "--editor", "--quit"]): return 1
        scripts = () if args.render_only else ("verify_jungle_river_sentries", "verify_jungle_pass", "verify_jungle_section", "verify_jungle_warden", "verify_growth_rewards", "verify_encounter_variation")
        for script in scripts:
            options = ["--headless", "--script", f"res://tests/{script}.gd"]
            if script == "verify_jungle_river_sentries": options += ["--", "--require-mount"]
            run(script, options)
        if args.render or args.render_only:
            import os
            for large in (False, True):
                for variant in ("baseline", "candidate"):
                    label = variant + ("-1280" if large else "-960")
                    folder = output / label
                    env = dict(os.environ, JUNGLE_RIVER_OUTPUT=str(folder))
                    options = ["--script", "res://tests/capture_jungle_river_sentries.gd", "--", "--require-mount"]
                    if large: options.append("--large")
                    if variant == "candidate": options.append("--candidate")
                    run(label, options, env)
        return 0 if all(r["passed"] for r in results) else 1
    finally:
        after = hashes(protected_source + protected_saves)
        preserved = before == after
        summary = {"trial_id": trial_id, "base_commit": "93674fdb64dc1251e4de0d991cd34b47422576fe", "source": str(source), "project": str(project), "results": results, "ordinary_save_and_source_preserved": preserved, "before": before, "after": after}
        (output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
        if not preserved:
            raise RuntimeError("source or ordinary save snapshot changed during fixture")


if __name__ == "__main__":
    sys.exit(main())
