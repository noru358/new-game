"""Engine-free placement preparation, not a Godot parser/render/physics test."""
import ast, copy, hashlib, json, math, pathlib, re, subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
BASE = "296bde54f987372750e652c608c62b8e6309192c"
text = (ROOT / "game/jungle_waterfall_sources.gd").read_text()
layout = (ROOT / "game/jungle_grotto_layout.gd").read_text()

def array(source, name):
    value = re.search(r"const " + name + r" := (\[[\s\S]*?\n\])", source).group(1)
    for label, vector in [("LEFT", "(-1,0)"), ("RIGHT", "(1,0)"), ("DOWN", "(0,1)")]:
        value = value.replace("Vector2." + label, vector)
    value = value.replace("ALTAR", "Vector2(9860,440)")
    value = value.replace("FIELD_ENTRY", "Vector2(6290,2630)")
    value = re.sub(r"(?:Vector2|Rect2)\(([^()]+)\)", r"(\1)", value)
    return ast.literal_eval(value)

main, hidden = array(text, "MAIN"), array(text, "HIDDEN")
paths = array(layout, "PATHS")
clears = [(7300,2060,880,440),(8920,1640,550,450),(9520,220,530,430)]
pools = [(7450,1650,430,380),(8970,1090,390,370),(8280,930,570,350),(6300,2740,740,100),(7040,2600,560,240)]
rims = [(1240,590,150,30,185),(1350,430,100,200,185),(1350,630,100,190,21),(1240,760,150,40,21),(1110,440,230,110,185)]

def inside(rect, p, closed=False):
    x,y,w,h = rect[:4]
    return x <= p[0] <= x+w and y <= p[1] <= y+h if closed else x <= p[0] < x+w and y <= p[1] < y+h

def walk(p):
    if any(inside(a,p) for a in clears): return True
    for route in paths:
        for a,b in zip(route["points"],route["points"][1:]):
            vx,vy=b[0]-a[0],b[1]-a[1]
            u=max(0,min(1,((p[0]-a[0])*vx+(p[1]-a[1])*vy)/(vx*vx+vy*vy)))
            if math.hypot(p[0]-a[0]-u*vx,p[1]-a[1]-u*vy) <= route["width"]: return True
    return False

def kind(p):
    c=math.floor((p[0]-6000)/140);r=math.floor((p[1]-80)/140)
    center=(6000+(c+.5)*140,80+(r+.5)*140)
    if walk(center): return 0
    if any(inside(a,center) for a in pools): return 1
    return 3 if walk((center[0]-140,center[1])) or walk((center[0],center[1]-140)) else 2

def valid(spec):
    tangent=(-spec["out"][1],spec["out"][0])
    for sign in (-1,1):
        p=tuple(spec["lip"][i]+tangent[i]*spec["half"]*sign for i in range(2))
        probe=tuple(p[i]-spec["out"][i]*.2 for i in range(2))
        foot=tuple(spec["bottom"][i]+tangent[i]*spec["bottom_half"]*sign for i in range(2))
        if not inside(spec["receiver"],foot,True): return False
        if spec["field"] == "main":
            if not any(tuple(r[:4])==spec["wall"] and r[4]==spec["height"] and inside(r,probe,True) for r in rims): return False
        elif kind(probe) not in (2,3) or kind(foot) != 1: return False
    for p in spec["feed"]:
        if spec["field"] == "main":
            if not any(r[4]==spec["height"] and inside(r,p,True) for r in rims): return False
        elif kind(tuple(p[i]-spec["out"][i]*.2 for i in range(2))) not in (2,3): return False
    return True

assert len(main)==4 and len(hidden)==2 and len({s["id"] for s in main+hidden})==6
assert all(valid(s) for s in main+hidden)
raised=copy.deepcopy(main[2]);raised["height"]=190
assert not valid(raised), "legacy 190-height sheet above21-rim must fail"
floated=copy.deepcopy(hidden[0]);floated["lip"]=(7600,1650)
assert not valid(floated), "legacy source over open pool must fail"
for forbidden in ["generate_triangle_mesh", "_process(", "_physics_process(", "Particles", "water_areas.append", "wall_areas.append"]:
    assert forbidden not in text, forbidden
unchanged=[]
for name in subprocess.check_output(["git","ls-files","game","project.godot"],cwd=ROOT,text=True).splitlines():
    if name in {"game/jungle_hidden_sanctuary.gd","game/jungle_waterfall_sources.gd"}: continue
    assert (ROOT/name).read_bytes()==subprocess.check_output(["git","show",BASE+":"+name],cwd=ROOT),name
    unchanged.append(name)
result={"base":BASE,"engine_runs":0,"scope":"Python declared placement audit only; not GDScript parse, actual mesh/physics, render or performance acceptance","sources":main+hidden,"water_mesh_nodes_before":6,"water_mesh_nodes_prepared":6,"water_triangles_before":72,"water_triangles_prepared":sum(8+2+len(s["feed"])-2 for s in main+hidden),"negative_controls":["190-height over21-rim rejected","pool-centered floating hidden source rejected"],"nonowned_game_config_byte_identical":len(unchanged),"sha256":{n:hashlib.sha256((ROOT/n).read_bytes()).hexdigest() for n in ["game/jungle_hidden_sanctuary.gd","game/jungle_waterfall_sources.gd","tests/verify_jungle_waterfall_sources.gd","tests/verify_jungle_waterfall_visibility.gd"]},"remaining":["Godot import/parser and source-contact negative controls","actual fixed-camera960/1280 waterfall approach/return and actor/tell readability","bounded performance delta; no lag-fix claim"]}
out=ROOT/"docs/measurements/jungle-waterfall-source-v50"
out.mkdir(parents=True,exist_ok=True)
(out/"static-preparation.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")
print(json.dumps({k:result[k] for k in ["engine_runs","water_mesh_nodes_before","water_mesh_nodes_prepared","water_triangles_before","water_triangles_prepared","nonowned_game_config_byte_identical","negative_controls"]},ensure_ascii=False))
