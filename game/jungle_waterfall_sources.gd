extends RefCounted
## Six static water meshes: supported headwater, rock lip, drop and receiving
## surface. No new nodes, colliders, processing, particles or gameplay records.
const COLOR := Color(0.4,0.82,0.85,0.55)
const MAIN := [
	{"id":"mouth", "field":"main", "lip":Vector2(1240,605), "out":Vector2.LEFT, "half":12.0, "bottom":Vector2(1225,690), "bottom_half":25.0, "height":185.0, "wall":Rect2(1240,590,150,30), "feed":[Vector2(1240,593),Vector2(1358,593),Vector2(1358,535),Vector2(1382,535),Vector2(1382,617),Vector2(1240,617)], "receiver":Rect2(1200,660,45,60)},
	{"id":"upper_south", "field":"main", "lip":Vector2(1290,550), "out":Vector2.DOWN, "half":40.0, "bottom":Vector2(1290,550.35), "bottom_half":40.0, "height":185.0, "wall":Rect2(1110,440,230,110), "feed":[Vector2(1260,478),Vector2(1275,478),Vector2(1275,442),Vector2(1305,442),Vector2(1305,530),Vector2(1330,550),Vector2(1250,550),Vector2(1275,530),Vector2(1275,502),Vector2(1260,502)], "receiver":Rect2(1250,550,80,38)},
	{"id":"lower_rim", "field":"main", "lip":Vector2(1240,780), "out":Vector2.LEFT, "half":18.0, "bottom":Vector2(1239.65,780), "bottom_half":18.0, "height":21.0, "wall":Rect2(1240,760,150,40), "feed":[Vector2(1240,762),Vector2(1380,762),Vector2(1380,798),Vector2(1240,798)], "receiver":Rect2(1205,760,35,40)},
	{"id":"upper_west", "field":"main", "lip":Vector2(1110,490), "out":Vector2.LEFT, "half":40.0, "bottom":Vector2(1109.65,490), "bottom_half":40.0, "height":185.0, "wall":Rect2(1110,440,230,110), "feed":[Vector2(1110,450),Vector2(1145,478),Vector2(1260,478),Vector2(1260,502),Vector2(1145,502),Vector2(1110,530)], "receiver":Rect2(1078,450,32,80)},
]
const HIDDEN := [
	{"id":"receiving_pool", "field":"hidden", "lip":Vector2(7820,1830), "out":Vector2.LEFT, "half":40.0, "bottom":Vector2(7819.65,1830), "bottom_half":40.0, "feed":[Vector2(7820,1790),Vector2(7855,1830),Vector2(7820,1870)], "receiver":Rect2(7780,1790,40,80)},
	{"id":"return_pool", "field":"hidden", "lip":Vector2(8240,1130), "out":Vector2.RIGHT, "half":40.0, "bottom":Vector2(8240.35,1130), "bottom_half":40.0, "feed":[Vector2(8240,1090),Vector2(8205,1130),Vector2(8240,1170)], "receiver":Rect2(8240,1090,40,80)},
]

static func authored(node: Node) -> bool:
	return node is MeshInstance3D and node.has_meta("waterfall_source_id") and node.get_meta("existing_water",false)

static func rock_point(p: Vector2,spec: Dictionary,profiles: Array = []) -> Vector3:
	if spec.field == "main": return Vector3(p.x,spec.height,p.y)*0.01
	# Interpolate the producer's existing bank-cell triangles during construction.
	# No additional BVH, whole-mesh scan or per-frame terrain query is introduced.
	var probe := p
	if absf((p-spec.lip).dot(spec.out)) < 0.01: probe -= spec.out*0.2
	for record in profiles:
		var area: Rect2 = record.area
		if not area.has_point(probe): continue
		var count := maxi(1,ceili(area.size.x/140.0))
		var index := mini(count-1,floori((probe.x-area.position.x)/(area.size.x/count)))
		var x0 := area.position.x+index*area.size.x/count
		var x1 := area.end.x if index == count-1 else area.position.x+(index+1)*area.size.x/count
		var center := Vector2((x0+x1)*0.5,area.get_center().y)
		var corners := [Vector2(x0,area.position.y),Vector2(x1,area.position.y),Vector2(x1,area.end.y),Vector2(x0,area.end.y)]
		for edge in 4:
			var a: Vector2 = corners[edge]
			var b: Vector2 = corners[(edge+1)%4]
			var u := (probe-center).cross(b-center)/(a-center).cross(b-center)
			var v := (a-center).cross(probe-center)/(a-center).cross(b-center)
			if minf(minf(u,v),1.0-u-v) < -0.0001: continue
			var level: float = record.height*(0.86 if record.get("foreground_edge",false) else 0.98)
			var y := _edge_height(record,a)*u+_edge_height(record,b)*v+level*(1.0-u-v)
			return Vector3(p.x,y,p.y)*0.01
	assert(false,"Waterfall source has no real bank: "+spec.id)
	return Vector3.INF

static func _edge_height(record: Dictionary,p: Vector2) -> float:
	return record.height*(0.58 if record.get("foreground_edge",false) else 0.74+0.13*sin(p.x*0.009+p.y*0.016))

static func receiving_point(terrain,p: Vector2,spec: Dictionary) -> Vector3:
	var height := 1.0 if spec.field == "hidden" else float(terrain.height_at(p))
	if spec.field == "main":
		for floor in terrain.floor_areas:
			if floor.area.has_point(p): height = maxf(height,float(floor.get("height",0.7)))
	return Vector3(p.x,height+0.1,p.y)*0.01

static func build(arena,spec: Dictionary,profiles: Array = []) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tangent: Vector2 = Vector2(-spec.out.y,spec.out.x)
	var anchors := PackedVector3Array()
	var heads := PackedVector3Array()
	var feet := PackedVector3Array()
	for sign in [-1.0,1.0]:
		var lip: Vector2 = spec.lip+tangent*spec.half*sign
		var anchor := rock_point(lip,spec,profiles)+Vector3.UP*0.002
		anchors.append(anchor)
		heads.append(anchor+Vector3(spec.out.x,0,spec.out.y)*0.0035)
		feet.append(receiving_point(arena.terrain,spec.bottom+tangent*spec.bottom_half*sign,spec))
	# Thin water over the lip joins the upstream surface to the falling face.
	_quad(st,anchors[0],anchors[1],heads[1],heads[0])
	for step in 3:
		var a := float(step)/3.0
		var b := float(step+1)/3.0
		_quad(st,_drop(heads[0],feet[0],a),_drop(heads[1],feet[1],a),_drop(heads[1],feet[1],b),_drop(heads[0],feet[0],b))
	var feed := PackedVector2Array(spec.feed)
	var indices := Geometry2D.triangulate_polygon(feed)
	for i in range(0,indices.size(),3):
		for j in 3: st.add_vertex(rock_point(feed[indices[i+j]],spec,profiles)+Vector3.UP*0.002)
	var r: Rect2 = spec.receiver
	_quad(st,receiving_point(arena.terrain,r.position,spec),receiving_point(arena.terrain,Vector2(r.end.x,r.position.y),spec),receiving_point(arena.terrain,r.end,spec),receiving_point(arena.terrain,Vector2(r.position.x,r.end.y),spec))
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.name = "AuthoredWaterCurtain"
	node.mesh = st.commit()
	var material: StandardMaterial3D = arena._material(COLOR,true)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.set_meta("existing_water",true)
	node.set_meta("waterfall_source_id",spec.id)
	node.set_meta("source_points",anchors)
	node.set_meta("drop_head_points",heads)
	node.set_meta("drop_foot_points",feet)
	node.set_meta("source_spec",spec)
	return node

static func _drop(head: Vector3,foot: Vector3,t: float) -> Vector3:
	var point := head.lerp(foot,t)
	point.y = lerpf(head.y,foot.y,t*t)
	return point

static func _quad(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3) -> void:
	for p in [a,b,c,a,c,d]: st.add_vertex(p)
