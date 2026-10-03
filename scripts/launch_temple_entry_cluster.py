"""Isolated official-Godot temple sample runner. Native rendering requires a GUI slot.

python launch_temple_entry_cluster.py walk --godot /path/to/official/Godot \
    --destination /fresh/workspace/path --native-slot-granted [--baseline]

Uses only a fresh project copy and UUID userdata. Never launches a packaged app.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import uuid

ANCHOR = 'config/custom_user_dir_name="Godot/app_userdata/Loop Conquest - 1G Complete Run v03"'
ERRORS = re.compile(r"(?m)^\s*(?:ERROR:|SCRIPT ERROR:|FAIL:)")

def source_hashes(root):
    paths = [root / "project.godot", *sorted((root / "game").rglob("*")),
             root / "tests/capture_temple_entry_cluster.gd",
             root / "tests/capture_temple_entry_combat.gd",
             root / "tests/verify_temple_entry_cluster.gd",
             root / "tests/verify_temple_entry_impact.gd"]
    return {p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in paths if p.is_file() and p.suffix != ".import"}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("kind", choices=["verify", "impact", "walk", "combat"])
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--destination", required=True, type=Path)
    parser.add_argument("--baseline", action="store_true")
    parser.add_argument("--measure-only", action="store_true")
    parser.add_argument("--all-sizes", action="store_true")
    parser.add_argument("--native-slot-granted", action="store_true")
    args = parser.parse_args()
    native = args.kind in ["walk", "combat"] and not args.measure_only
    if native and not args.native_slot_granted:
        parser.error("Request the shared GUI engine slot before native rendering")
    if args.kind in ["verify", "impact"] and args.baseline:
        parser.error("Verification expects the candidate; baseline is for comparisons")
    root = Path(__file__).resolve().parents[1]
    dest = args.destination.absolute()
    if dest.exists() or any(p.is_symlink() for p in [dest, *dest.parents]):
        parser.error("Destination must be fresh and have no symlink ancestors")
    hashes = source_hashes(root)
    config = (root / "project.godot").read_text()
    if config.count(ANCHOR) != 1:
        parser.error("Expected unchanged source userdata anchor")
    version = subprocess.check_output([str(args.godot), "--version"], text=True).strip()
    if version != "4.6.stable.official.89cea1439":
        parser.error("This evidence recipe is pinned to official4.6.stable.89cea1439")
    dest.mkdir(parents=True)
    project = dest / "project"
    project.mkdir()
    for directory in ["game", "tests"]:
        shutil.copytree(root / directory, project / directory,
                        ignore=shutil.ignore_patterns("*.import"))
    identifier = str(uuid.uuid4())
    data_name = "RegionalLandmarkV47/TempleEntryCluster/" + identifier
    (project / "project.godot").write_text(config.replace(ANCHOR,
                       'config/custom_user_dir_name="' + data_name + '"'))
    # Import serialized resources and global class cache before one test engine.
    commands = [[str(args.godot), "--headless", "--path", str(project),
                 "--editor", "--import", "--quit"]]
    script = {"verify": "verify_temple_entry_cluster.gd",
              "impact": "verify_temple_entry_impact.gd",
              "walk": "capture_temple_entry_cluster.gd",
              "combat": "capture_temple_entry_combat.gd"}[args.kind]
    command = [str(args.godot), "--path", str(project)]
    if not native: command.append("--headless")
    command += ["--script", "res://tests/" + script]
    user_args = []
    if args.baseline: user_args.append("--temple-entry-baseline")
    if args.measure_only: user_args.append("--measure-only")
    if args.all_sizes: user_args.append("--entry-all-sizes")
    if user_args: command += ["--", *user_args]
    commands.append(command)
    env = dict(os.environ, REGION_LANDMARK="temple",
               REGIONAL_LANDMARK_OUTPUT=str(dest / "captures"),
               TEMPLE_ENTRY_OUTPUT=str(dest / "captures"))
    codes = []
    for index, command in enumerate(commands):
        with (dest / f"engine-{index}.log").open("w") as log:
            completed = subprocess.run(command, env=env, stdout=log,
                                       stderr=subprocess.STDOUT, timeout=540)
        codes.append(completed.returncode)
        text = (dest / f"engine-{index}.log").read_text()
        if completed.returncode or ERRORS.search(text): break
    source_preserved = hashes == source_hashes(root)
    receipt = {"version": version, "uuid": identifier, "userdata_name": data_name,
               "variant": "baseline" if args.baseline else "candidate",
               "kind": args.kind, "native": native, "engine_exit_codes": codes,
               "source_preserved": source_preserved, "source_hashes": hashes,
               "source_commit": subprocess.check_output(["git", "rev-parse", "HEAD"],
                                                         cwd=root, text=True).strip()}
    (dest / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    good = len(codes) == 2 and all(code == 0 for code in codes) and source_preserved
    good = good and all(not ERRORS.search((dest / f"engine-{i}.log").read_text())
                       for i in range(len(codes)))
    print(json.dumps({"complete":good,"kind":args.kind,"native":native,
                      "variant":receipt["variant"],"source_preserved":source_preserved,
                      "exit_codes":codes,"evidence":str(dest)}))
    return 0 if good else 1

if __name__ == "__main__":
    raise SystemExit(main())
