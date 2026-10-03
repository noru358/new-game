#!/usr/bin/env python3
"""Sequential engine runs in byte copies with UUID private macOS userdata.

Never reads normal saves, never edits source config, never reuses an output root.
The existing controller is fixed; only instrumentation and Mac isolation differ.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import uuid


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--builds", default="movement")
    parser.add_argument("--seconds", type=float, default=330)
    parser.add_argument("--seed", type=int, default=481)
    parser.add_argument("--scripts", help="Comma separated fixture paths; omits natural sample")
    parser.add_argument("--matched-episodes", action="store_true", help="Synthetic fixed nine-opportunity comparison, not a natural run")
    parser.add_argument("--mount-flow-end", action="store_true", help="Apply parent-owned end-of-run mount in this disposable copy only")
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    if sys.platform != "darwin" or output.exists() or output.is_symlink() or source in output.parents:
        raise ValueError("Requires macOS, a new output outside source, and no output symlink")
    output.mkdir(parents=True)
    project = output / "project"
    project.mkdir()
    for name in ["game", "tests"]:
        shutil.copytree(source / name, project / name, copy_function=shutil.copy2)
    shutil.copy2(source / "project.godot", project / "project.godot")
    if args.mount_flow_end:
        shared = project / "game/hybrid_region.gd"
        original = shared.read_text()
        anchor_end = '\trun_ended = true\n\tend_result = result\n'
        if original.count(anchor_end) != 1:
            raise ValueError("Unexpected run-end mount anchor")
        shared.write_text(original.replace(anchor_end, '\trun_ended = true\n\tplayer.clear_flow_weave()\n\tend_result = result\n'))
    hashes = {str(p.relative_to(source)): hashlib.sha256(p.read_bytes()).hexdigest()
              for p in [source / "project.godot", *(source / "game").rglob("*")]
              if p.is_file()}
    anchor = 'config/custom_user_dir_name="Godot/app_userdata/Loop Conquest - 1G Complete Run v03"'
    config = (project / "project.godot").read_text()
    if config.count(anchor) != 1 or (source / "override.cfg").exists():
        raise ValueError("Unexpected source userdata/override configuration")
    summary = {"source": str(source), "source_sha256": hashes, "runs": [], "human_playtest": False, "mount_flow_end": args.mount_flow_end,
               "engine": subprocess.check_output([args.godot, "--version"], text=True).strip()}

    def run(label, options):
        private_name = "Codex-Combat-Actions-v48/" + str(uuid.uuid4())
        private = Path.home() / "Library/Application Support" / private_name
        if private.exists():
            raise ValueError("Refusing existing private userdata")
        (project / "project.godot").write_text(config.replace(anchor, f'config/custom_user_dir_name="{private_name}"'))
        env = dict(os.environ, BUILD_ACTION_USER_DIR=str(private))
        for key in list(env):
            if key.startswith(("BUILD_COMPARISON_", "COMPANION_FOCUS_", "LC_", "CAPTURE_")):
                del env[key]
        with (output / f"{label}.log").open("w") as log:
            result = subprocess.run([args.godot, "--headless", "--path", str(project),
                                     "--log-file", str(output / f"{label}-engine.log"), *options],
                                    env=env, stdout=log, stderr=subprocess.STDOUT, timeout=args.seconds + 240)
        text = (output / f"{label}.log").read_text()
        row = {"label": label, "exit_code": result.returncode, "private_userdata": str(private),
               "script_error": any(x in text for x in ["SCRIPT ERROR:", "Parse Error:", "ERROR:", "FAIL:"])}
        summary["runs"].append(row)
        (output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
        print(json.dumps(row), flush=True)
        if result.returncode or row["script_error"]:
            raise RuntimeError(f"Engine run failed: {label}; see retained log")

    run("import", ["--editor", "--quit"])
    if args.matched_episodes:
        for build in args.builds.split(","):
            run(build, ["--script", "res://tests/sample_matched_build_actions.gd", "--", f"--build={build}", f"--report-path={output / (build + '.json')}"])
    elif args.scripts:
        for script in args.scripts.split(","):
            label = Path(script).stem
            run(label, ["--script", "res://" + script, "--", f"--report-path={output / (label + '.json')}"])
    else:
        run("flow-reposition", ["--script", "res://tests/sample_flow_reposition.gd", "--", f"--report-path={output / 'flow-reposition.json'}"])
        for build in args.builds.split(","):
            run(build, ["--script", "res://tests/sample_build_actions.gd", "--", f"--build={build}",
                        "--policy=common", f"--seed={args.seed}", f"--seconds={args.seconds}",
                        f"--report-path={output / (build + '.json')}"])
    after = {name: hashlib.sha256((source / name).read_bytes()).hexdigest() for name in hashes}
    summary["source_preserved"] = after == hashes
    (output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    if after != hashes:
        raise RuntimeError("Source bytes changed during sample")


if __name__ == "__main__":
    main()
