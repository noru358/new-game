extends RefCounted
## One emergent tree in a physically blocked, northwest-closed forest corner.
## World-space geometry: no camera scaling, fading, particles or gameplay nodes.
const POCKET := [Rect2(0, 0, 680, 800), Rect2(680, 0, 100, 650), Rect2(680, 650, 60, 100)]
const CONTOUR := [Vector2(0,0), Vector2(780,0), Vector2(780,650), Vector2(740,650), Vector2(740,750), Vector2(680,750), Vector2(680,800), Vector2(0,800)]
const REPLACED_TREES := [Vector2(350,470), Vector2(650,360)]
const OLD_ROCK := Rect2(600,500,180,250)
const ORIGIN := Vector3(3.5,0,4.7)

static func contains_ground(point: Vector2, epsilon: float = 0.001) -> bool:
	for area in POCKET:
		if area.grow(epsilon).has_point(point): return true
	return false

static func install(terrain) -> void:
	for i in range(terrain.wall_areas.size()-1,-1,-1):
		var area: Rect2 = terrain.wall_areas[i].area
		if area == OLD_ROCK or area == Rect2(REPLACED_TREES[0]-Vector2.ONE*23,Vector2.ONE*46) or area == Rect2(REPLACED_TREES[1]-Vector2.ONE*23,Vector2.ONE*46):
			terrain.wall_areas.remove_at(i)
	for point in REPLACED_TREES: terrain.route_canopy_points.erase(point)
	for area in POCKET:
		terrain.wall_areas.append({"area":area,"base":0.0,"height":90.0,"rise":90.0,"color":Color("59634e"),"visual":false,"minimap_visible":true,"emergent_tree_pocket":true})

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "JungleEmergentTree"
	var stone := SurfaceTool.new()
	var wood := SurfaceTool.new()
	var leaves := SurfaceTool.new()
	for st in [stone,wood,leaves]: st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_ledge(stone)
	# Fluted, bent bole; a low, visibly woody fork survives combat-camera cropping.
	var bole := [ORIGIN+Vector3(0,0.55,0),ORIGIN+Vector3(-0.12,1.8,0.07),ORIGIN+Vector3(0.16,3.2,-0.15),ORIGIN+Vector3(-0.22,5.25,-0.35),ORIGIN+Vector3(-0.1,7.7,-0.5)]
	_taper(wood,bole,[0.79,0.56,0.43,0.30,0.12],Color("5b5843"),11,0.16)
	_taper(wood,[bole[2],ORIGIN+Vector3(1.05,4.1,0.0),ORIGIN+Vector3(1.7,5.8,-0.35),ORIGIN+Vector3(1.7,7.0,-0.45)],[0.39,0.28,0.19,0.06],Color("646047"),9,0.12)
	_taper(wood,[bole[2]+Vector3(0,0.35,0),ORIGIN+Vector3(-1.1,4.8,-0.35),ORIGIN+Vector3(-1.8,6.5,-0.8)],[0.30,0.22,0.07],Color("51533f"),9,0.13)
	# Buttress webs widen at ground, taper into the bole, with long low root toes.
	for i in 8:
		var a := float(i)*TAU/8.0+0.17
		var direction := Vector3(cos(a),0,sin(a))
		var side := Vector3(-sin(a),0,cos(a))
		var tip := ORIGIN+direction*(2.05+0.23*sin(i*2.3))
		var heel := ORIGIN+direction*0.48
		var top := heel+Vector3.UP*(1.75+0.23*cos(i*1.9))
		var left := heel+side*0.30+Vector3.UP*0.52
		var right := heel-side*0.30+Vector3.UP*0.52
		var toe := tip+Vector3.UP*0.40
		_tri(wood,left,top,toe,Color("666248"))
		_tri(wood,top,right,toe,Color("514f3d"))
		_taper(wood,[heel+Vector3.UP*0.64,ORIGIN+direction*1.4+Vector3.UP*0.48,toe],[0.26,0.15,0.035],Color("5c5941"),7,0.1)
	# Broad scalloped leaf plates; restrained four-tier crown, not sphere stacks.
	_lobe(leaves,ORIGIN+Vector3(-1.65,6.55,-0.65),Vector3(1.35,0.57,1.12),Color("45644c"),1)
	_lobe(leaves,ORIGIN+Vector3(1.45,7.10,-0.60),Vector3(1.48,0.58,1.36),Color("4b6c50"),3)
	_lobe(leaves,ORIGIN+Vector3(-0.65,7.72,-0.88),Vector3(2.08,0.62,1.56),Color("567452"),5)
	_lobe(leaves,ORIGIN+Vector3(0.26,8.35,-0.86),Vector3(1.77,0.65,1.27),Color("617c55"),7)
	for pair in [[stone,"RockRootLedge"],[wood,"ButtressAndFork"],[leaves,"EmergentCrown"]]:
		var node := MeshInstance3D.new()
		node.name = pair[1]
		node.mesh = pair[0].commit()
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 1.0
		node.material_override = material
		root.add_child(node)
	root.set_meta("blocked_contour",CONTOUR)
	return root

static func _ledge(st: SurfaceTool) -> void:
	# Exact continuous top coverage of the collision union, triangulated without
	# convex-hull spill over the stepped southeast corner.
	var polygon := PackedVector2Array(CONTOUR)
	var indices := Geometry2D.triangulate_polygon(polygon)
	var top: Array[Vector3] = []
	for i in CONTOUR.size():
		var p: Vector2 = CONTOUR[i]*0.01
		top.append(Vector3(p.x,0.40+0.10*sin(i*1.7),p.y))
	for i in range(0,indices.size(),3):
		_tri_up(st,top[indices[i]],top[indices[i+1]],top[indices[i+2]],Color("626b54").lightened(0.02*(i%3)))
	for i in top.size():
		var j := (i+1)%top.size()
		var a: Vector3 = top[i]
		var b: Vector3 = top[j]
		var low_a := Vector3(a.x,0,a.z)
		var low_b := Vector3(b.x,0,b.z)
		_tri(st,low_a,b,a,Color("4b5949"))
		_tri(st,low_a,low_b,b,Color("4b5949"))
	# Low angular boulders break up the ledge interior; still one opaque batch.
	for spec in [[Vector3(1.2,0.45,1.5),Vector3(1.05,0.44,1.05)],[Vector3(6.35,0.40,5.2),Vector3(1.02,0.5,1.05)],[Vector3(5.4,0.4,7.15),Vector3(0.95,0.38,0.55)],[Vector3(1.0,0.4,6.8),Vector3(0.85,0.32,0.85)]]:
		_lobe(st,spec[0],spec[1],Color("647059"),2)

static func _taper(st: SurfaceTool, centers: Array, radii: Array, color: Color, sides: int, flute: float) -> void:
	var rings: Array = []
	for j in centers.size():
		var ring: Array[Vector3] = []
		for i in sides:
			var a := TAU*float(i)/sides
			var radius: float = radii[j]*(1.0+flute*cos(i*2.7+j*0.8))
			ring.append(centers[j]+Vector3(cos(a)*radius,0,sin(a)*radius))
		rings.append(ring)
	for j in range(rings.size()-1):
		for i in sides:
			var k := (i+1)%sides
			var tint := color.lightened(0.035*sin(i*1.3))
			_tri(st,rings[j][i],rings[j+1][k],rings[j+1][i],tint)
			_tri(st,rings[j][i],rings[j][k],rings[j+1][k],tint)
	for i in sides:
		_tri_up(st,centers[-1],rings[-1][i],rings[-1][(i+1)%sides],color)

static func _lobe(st: SurfaceTool, center: Vector3, size: Vector3, color: Color, seed: int) -> void:
	var rings: Array = []
	for level in 3:
		var ring: Array[Vector3] = []
		var scale_xz: float = [0.66,1.0,0.76][level]
		var elevation: float = [-0.55,0.05,0.64][level]
		for i in 12:
			var a := TAU*float(i)/12.0
			var ripple := 0.91+0.09*sin(i*2.3+seed)
			ring.append(center+Vector3(cos(a)*size.x*scale_xz*ripple,size.y*(elevation+0.09*sin(i*1.7+seed)),sin(a)*size.z*scale_xz*ripple))
		rings.append(ring)
	for j in 2:
		for i in 12:
			var k := (i+1)%12
			var tint := color.darkened(0.16 if j==0 else 0.0).lightened(0.015*sin(i+seed))
			_tri(st,rings[j][i],rings[j+1][k],rings[j+1][i],tint)
			_tri(st,rings[j][i],rings[j][k],rings[j+1][k],tint)
	for i in 12:
		_tri_up(st,center+Vector3.UP*size.y,rings[2][i],rings[2][(i+1)%12],color.lightened(0.025))
		_tri(st,center-Vector3.UP*size.y*0.7,rings[0][(i+1)%12],rings[0][i],color.darkened(0.2))

static func _tri_up(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
	if (c-a).cross(b-a).y < 0: _tri(st,a,c,b,color)
	else: _tri(st,a,b,c,color)

static func _tri(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
	var normal := (c-a).cross(b-a).normalized()
	for p in [a,b,c]:
		st.set_color(color)
		st.set_normal(normal)
		st.add_vertex(p)
