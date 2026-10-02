#!/usr/bin/env python3
"""Isolated Mac sample QA; shared patch is applied only to the copied project."""
import argparse, hashlib, json, os, shutil, subprocess, sys, uuid
from pathlib import Path

def digest(paths):
    return {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths if p.is_file()}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot',required=True)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--phase',choices=['import','regression','baseline-960','candidate-960','baseline-1280','candidate-1280'],required=True)
    a=p.parse_args(); source=Path(__file__).resolve().parents[1]; output=a.output.resolve()
    if sys.platform != 'darwin': p.error('Mac only')
    output.mkdir(exist_ok=True,parents=True); project=output/'project'
    normal=Path.home()/'Library/Application Support/Godot/app_userdata/Loop Conquest - 1G Complete Run v03'
    guarded=list((source/'game').rglob('*'))+[source/'project.godot']+list(normal.glob('*.json'))+list(normal.glob('*.cfg'))
    guarded=[q for q in guarded if q.is_file()]; before=digest(guarded)
    if not project.exists():
        project.mkdir()
        for name in ['game','tests']: shutil.copytree(source/name,project/name)
        subprocess.run(['git','apply',str(source/'patches/jungle-worn-stone-mount.patch')],cwd=project,check=True)
        config=(source/'project.godot').read_text()
        anchor='config/custom_user_dir_name="Godot/app_userdata/Loop Conquest - 1G Complete Run v03"'
        assert config.count(anchor)==1
        (project/'project.godot').write_text(config.replace(anchor,'config/custom_user_dir_name="LoopConquestMapTrials/worn-'+str(uuid.uuid4())+'"'))
    results=[]
    def run(name,commands,env=None):
        with (output/(name+'.log')).open('w') as log:
            r=subprocess.run([a.godot,'--path',str(project)]+commands,stdout=log,stderr=subprocess.STDOUT,env=env,timeout=120)
        log=(output/(name+'.log')).read_text()
        ok=r.returncode==0 and not any(s in log for s in ['SCRIPT ERROR:','Parse Error:','FAIL:','leaked'])
        results.append({'name':name,'exit_code':r.returncode,'passed':ok})
        print(name, 'PASS' if ok else 'FAIL',flush=True)
        if not ok: print(log,flush=True)
    if a.phase=='import': run('import',['--headless','--editor','--quit'])
    elif a.phase=='regression':
        for script in ['verify_jungle_pass','verify_jungle_route','verify_terrain_coherence','verify_surface_overlap']:
            run(script,['--headless','--script','res://tests/'+script+'.gd'])
    else:
        commands=['--script','res://tests/capture_worn_stone_sample.gd','--']
        if a.phase.startswith('baseline'): commands.append('--worn-stone-baseline')
        if a.phase.endswith('1280'): commands.append('--large')
        run(a.phase,commands,dict(os.environ,WORN_OUTPUT=str(output/a.phase)))
    preserved=before==digest(guarded)
    (output/(a.phase+'-summary.json')).write_text(json.dumps({'phase':a.phase,'results':results,'source_and_ordinary_saves_preserved':preserved,'before':before,'after':digest(guarded)},indent=2)+'\n')
    return 0 if preserved and all(r['passed'] for r in results) else 1
if __name__=='__main__': sys.exit(main())
