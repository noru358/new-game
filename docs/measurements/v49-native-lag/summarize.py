import json,sys,statistics
from pathlib import Path
for name in sys.argv[1:]:
 r=json.loads(Path(name).read_text()); result={k:v for k,v in r.items() if k!='phases'}
 result['phases']=[]
 for p in r['phases']:
  s={'enemies':p['enemies'],'samples':len(p['frames'])}
  for i,key in enumerate(['frame_ms','engine_process_ms','physics_ms','render_cpu_ms','render_gpu_ms','draw_calls','render_objects','nodes','physics_active','collision_pairs','islands']):
   a=sorted(row[i] for row in p['frames']);s[key]={'mean':round(statistics.mean(a),3),'p95':round(a[int(.95*(len(a)-1))],3),'worst':round(max(a),3)}
  result['phases'].append(s)
 out=Path(name).with_name(Path(name).stem+'-summary.json');out.write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
