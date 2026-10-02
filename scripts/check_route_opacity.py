#!/usr/bin/env python3
"""Mac-only isolated route/opacity checks. Never changes HOME or ordinary saves."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import uuid


def digest(paths):
    return {str(p): hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else "absent" for p in paths}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--phase", choices=("opacity", "route", "render"), default="opacity")
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    if sys.platform != "darwin" or output.exists() or source in output.parents:
        parser.error("requires Mac and a new output directory outside source")
    output.mkdir(parents=True)
    project = output / "project"
    project.mkdir()
    for name in ("game", "tests"):
        shutil.copytree(source / name, project / name)
    # Shared mount files belong to integration. Apply the reviewable lane
    # patches only to this isolated project; accept an already mounted source.
    mount_states = []
    for name in ("environment-opacity-mount.patch", "jungle-route-mount.patch"):
        patch = source / "patches" / name
        forward = subprocess.run(["git", "apply", "--check", str(patch)], cwd=project, capture_output=True)
        if forward.returncode == 0:
            subprocess.run(["git", "apply", str(patch)], cwd=project, check=True)
            state = "applied to isolated copy"
        else:
            reverse = subprocess.run(["git", "apply", "--reverse", "--check", str(patch)], cwd=project, capture_output=True)
            if reverse.returncode:
                raise RuntimeError(f"mount patch conflicts with current source: {name}\n{forward.stderr.decode()}")
            state = "source already mounted"
        mount_states.append({"patch": name, "state": state, "sha256": hashlib.sha256(patch.read_bytes()).hexdigest()})
    config = (source / "project.godot").read_text()
    anchor = 'config/custom_user_dir_name="Godot/app_userdata/Loop Conquest - 1G Complete Run v03"'
    assert config.count(anchor) == 1
    trial_id = str(uuid.uuid4())
    (project / "project.godot").write_text(config.replace(anchor, f'config/custom_user_dir_name="LoopConquestMapTrials/{trial_id}"'))
    normal = Path.home() / "Library/Application Support/Godot/app_userdata/Loop Conquest - 1G Complete Run v03"
    paths = [source / "project.godot"] + sorted(p for p in (source / "game").rglob("*") if p.is_file())
    paths += [normal / "play_settings.cfg"] + [normal / (p + suffix) for p in ("loop_conquest_profile", "loop_conquest_1d_unlocks") for suffix in ("_a.json", "_b.json")]
    before = digest(paths)
    results = []

    def run(name, command, env=None):
        with (output / (name + ".log")).open("w") as log:
            result = subprocess.run([args.godot, "--path", str(project)] + command, stdout=log, stderr=subprocess.STDOUT, env=env, timeout=240)
        log = (output / (name + ".log")).read_text()
        ok = result.returncode == 0 and not any(s in log for s in ("SCRIPT ERROR:", "Parse Error:", "FAIL:", "leaked"))
        results.append({"name": name, "exit_code": result.returncode, "passed": ok})
        print(name, "PASS" if ok else "FAIL", flush=True)
        if not ok: print(log, flush=True)
        return ok

    try:
        if not run("import", ["--headless", "--editor", "--quit"]): return 1
        if args.phase == "opacity":
            scripts = ("verify_temple_occlusion_candidate", "verify_canal_overhead_occlusion", "verify_temple_environment", "verify_opening_temple_environment", "verify_canal_city", "verify_boss_visibility")
        elif args.phase == "route":
            scripts = ("verify_jungle_route", "verify_jungle_pass", "verify_jungle_section", "verify_jungle_warden", "verify_terrain_coherence", "verify_surface_overlap")
        else:
            scripts = ()
        for script in scripts:
            run(script, ["--headless", "--script", f"res://tests/{script}.gd"])
        if args.phase == "render":
            for variant in ("baseline", "candidate"):
                for large in (False, True):
                    label = variant + ("-1280" if large else "-960")
                    command = ["--script", "res://tests/capture_jungle_route.gd", "--", "--large"] if large else ["--script", "res://tests/capture_jungle_route.gd", "--"]
                    if variant == "baseline": command += ["--jungle-route-baseline"]
                    env = dict(os.environ, ROUTE_OUTPUT=str(output / label))
                    run(label, command, env)
            run("opaque-assets-render", ["--script", "res://tests/capture_opaque_environment.gd"], dict(os.environ, OPAQUE_OUTPUT=str(output / "opaque-assets")))
        return 0 if all(r["passed"] for r in results) else 1
    finally:
        after = digest(paths)
        preserved = before == after
        (output / "summary.json").write_text(json.dumps({"base_commit": "6dbe4b3e529d50f96bffa67c4a0e612065915876", "mount_states": mount_states, "trial_id": trial_id, "phase": args.phase, "results": results, "ordinary_save_and_source_preserved": preserved, "before": before, "after": after}, indent=2) + "\n")
        if not preserved: raise RuntimeError("source or ordinary saves changed during checks")


if __name__ == "__main__":
    sys.exit(main())
