"""Create an isolated QA snapshot and run one bounded engine at a time.
Native invocation requires the parent's allocated GUI slot.
"""
import argparse
import json
import shutil
import subprocess
import uuid
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('--engine', required=True)
p.add_argument('--output', required=True)
p.add_argument('--native', action='store_true')
a = p.parse_args()
source = Path(__file__).resolve().parents[1]
output = Path(a.output).resolve()
assert not output.is_relative_to(source), 'QA output must be outside source checkout'
output.mkdir(parents=True, exist_ok=True)
project = output / 'project'
assert not project.exists(), 'Use a fresh output directory per run'
shutil.copytree(source, project, ignore=shutil.ignore_patterns('.git', '.godot'))
config = project / 'project.godot'
user_dir = 'FennecIdle-' + str(uuid.uuid4())
text = config.read_text()
text = text.replace('Godot/app_userdata/Loop Conquest - 1G Complete Run v03', user_dir)
assert user_dir in text
config.write_text(text)
engine = str(Path(a.engine).resolve())
version = subprocess.check_output([engine, '--version'], text=True).strip()
assert version == '4.6.stable.official.89cea1439', version
commands = [[engine, '--headless', '--path', str(project), '--editor', '--import', '--quit'], [engine] + ([] if a.native else ['--headless']) + ['--path', str(project), '--script', 'res://tests/capture_fennec_idle.gd']]
import os
env = dict(os.environ, FENNEC_OUTPUT=str(output / 'captures'))
for i, command in enumerate(commands):
    with (output / ('import.txt' if i == 0 else 'capture.txt')).open('w') as log:
        result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, env=env, timeout=120)
    content = (output / ('import.txt' if i == 0 else 'capture.txt')).read_text()
    assert result.returncode == 0 and 'SCRIPT ERROR' not in content and 'ERROR:' not in content, content[-3000:]
report = json.loads((output / 'captures/report.json').read_text())
assert not report['failures'] and report['native'] == a.native
if a.native:
    from PIL import Image
    for r in report['records']:
        png = output / 'captures' / (r['view'] + '-' + str(r['width']) + '.png')
        assert Image.open(png).size == (r['width'], r['height'])
print(json.dumps({'engine':version,'userdata':user_dir,'native':a.native,'records':len(report['records']),'failures':len(report['failures']),'output':str(output)}))
