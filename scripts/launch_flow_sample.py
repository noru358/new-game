"""Create an immutable isolated developer sample copy. Never reuse campaign saves.
This launcher measures the unmounted180/210 flow proposal against baseline play.
Example: python3 scripts/launch_flow_sample.py --godot /path/Godot --preset fresh
"""
import argparse
import hashlib
import json
import re
from pathlib import Path
import shutil
import subprocess
import sys
import uuid
import launch_price_trial as safety


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--preset', choices=['fresh', 'grown'], default='fresh')
    parser.add_argument('--seconds', type=float, default=300)
    parser.add_argument('--runs', type=int, choices=[1, 2, 3], default=1)
    parser.add_argument('--seed', type=int, default=250)
    parser.add_argument('--slash-chain-cap-trial', action='store_true')
    parser.add_argument('--script', default='sample_flow_comparison.gd')
    parser.add_argument('--resume-checkpoint', type=Path)
    parser.add_argument('--destination', type=Path)
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[1]
    destination = (args.destination or source.parent / ('flow-sample-' + uuid.uuid4().hex)).absolute()
    if not 0 < args.seconds <= 330 or not (source / 'tests' / args.script).is_file():
        parser.error('require0<seconds<=330 and a tests script')
    safety.reject_links(destination)
    if source == destination or source in destination.parents or destination in source.parents or destination.exists():
        parser.error('destination must be fresh and outside source')
    config = (source / 'project.godot').read_bytes()
    safety.validate_settings(source, config)
    safety.require_once(config, safety.SAVE_ANCHOR)
    files = safety.project_files(source)
    for path in sorted((source / 'tests').glob('*.gd')):
        files[path.relative_to(source).as_posix()] = path.read_bytes()
    token = uuid.uuid4().hex
    custom = 'LoopConquestFlowSamples/' + token
    save_dir = safety.user_directory(destination, custom)
    if save_dir.exists():
        parser.error('unique sample save path unexpectedly exists')
    changed = dict(files)
    changed['project.godot'] = config.replace(safety.SAVE_ANCHOR, f'config/custom_user_dir_name="{custom}"'.encode())
    if args.slash_chain_cap_trial:
        anchor = b'var slash_chain_cap_trial_enabled := false'
        safety.require_once(changed['game/run_growth.gd'], anchor)
        changed['game/run_growth.gd'] = changed['game/run_growth.gd'].replace(anchor, b'var slash_chain_cap_trial_enabled := true')
    destination.mkdir(parents=True, exist_ok=False)
    for name, data in changed.items():
        path = destination / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    hashes = {name: safety.digest(data) for name, data in files.items()}
    manifest = {'token': token, 'source': str(source), 'destination': str(destination), 'save_dir': str(save_dir), 'source_sha256': hashes, 'copy_sha256': {name: safety.digest(data) for name, data in changed.items()}, 'preset': args.preset, 'slash_chain_cap_trial': args.slash_chain_cap_trial, 'engine_time_scale': 1, 'growth_price_source': 'unchanged game/run_profile.gd', 'script': args.script}
    save_dir.mkdir(parents=True, exist_ok=False)
    for path in [destination / 'flow-sample.json', save_dir / 'flow-sample-owner.json']:
        path.write_text(json.dumps(manifest, indent=2) + '\n')
    godot = safety.find_godot(args.godot)
    engine = safety.checked_engine(godot, destination, ['--version'], timeout=20).strip()
    if not re.match(r'^4\.6(?:\.\d+)?\.stable\.', engine):
        raise safety.TrialError('require a stable Godot4.6 family engine')
    (destination / 'import.log').write_text(safety.checked_engine(godot, destination, ['--headless', '--editor', '--path', str(destination), '--quit']))
    report = destination / 'report.json'
    arguments = ['--headless', '--path', str(destination), '--script', 'res://tests/' + args.script, '--', '--preset=' + args.preset, '--seconds=' + str(args.seconds), '--seed=' + str(args.seed), '--report-path=' + str(report), '--expected-user-dir=' + str(save_dir), '--runs=' + str(args.runs), '--run-diagnostics']
    if args.resume_checkpoint:
        arguments.append('--resume-checkpoint=' + str(args.resume_checkpoint.absolute()))
    print('ISOLATED_SAMPLE ' + str(destination), flush=True)
    output = safety.checked_engine(godot, destination, arguments, timeout=args.seconds * args.runs + 250)
    (destination / 'run.log').write_text(output)
    for name, digest in hashes.items():
        if safety.digest((source / name).read_bytes()) != digest:
            raise safety.TrialError('source changed during sample: ' + name)
    for name, digest in manifest['copy_sha256'].items():
        if safety.digest((destination / name).read_bytes()) != digest:
            raise safety.TrialError('copy changed during sample: ' + name)
    print(output[-2500:])
    print('REPORT ' + str(report))

if __name__ == '__main__':
    main()
