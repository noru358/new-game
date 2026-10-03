extends RefCounted
## Original cel-form palace kit. Reference image stays outside the repository.
const IVORY := Color("f2e5c9")
const GOLD := Color("c49b42")
const RED := Color("a74840")
const TEAL := Color("23776e")
const INK := Color("314b4d")
const Layout = preload("res://game/palace_temple_terrain.gd")
var surface := SurfaceTool.new()
var transform := Transform3D.IDENTITY
var vertices := 0

static func build(arena: Node3D) -> Node3D:
	return load("res://game/palace_temple_kit.gd").new()._build(arena)

func _begin() -> void:
	surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	transform = Transform3D.IDENTITY

func _end(root: Node3D, title: String) -> void:
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = title
	mesh.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = material
	root.add_child(mesh)

func _tri(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	for p in [a,b,c]:
		surface.set_color(color)
		surface.add_vertex((transform * p) * 0.01)
		vertices += 1

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_tri(a,b,c,color)
	_tri(a,c,d,color)

func _box(center: Vector3, size: Vector3, color: Color) -> void:
	var a := center - size * 0.5
	var b := center + size * 0.5
	_quad(Vector3(a.x,b.y,a.z),Vector3(a.x,b.y,b.z),b,Vector3(b.x,b.y,a.z),color.lightened(0.06))
	_quad(Vector3(a.x,a.y,b.z),Vector3(b.x,a.y,b.z),b,Vector3(a.x,b.y,b.z),color)
	_quad(Vector3(b.x,a.y,a.z),Vector3(a.x,a.y,a.z),Vector3(a.x,b.y,a.z),Vector3(b.x,b.y,a.z),color.darkened(0.16))
	_quad(Vector3(a.x,a.y,a.z),Vector3(a.x,a.y,b.z),Vector3(a.x,b.y,b.z),Vector3(a.x,b.y,a.z),color.darkened(0.09))
	_quad(Vector3(b.x,a.y,b.z),Vector3(b.x,a.y,a.z),Vector3(b.x,b.y,a.z),b,color.darkened(0.04))
	_quad(Vector3(a.x,a.y,a.z),Vector3(b.x,a.y,a.z),Vector3(b.x,a.y,b.z),Vector3(a.x,a.y,b.z),color.darkened(0.2))

func _frustum(center: Vector3, bottom: float, top: float, height: float, color: Color, sides := 8) -> void:
	for i in sides:
		var angle := TAU * i / sides
		var next := TAU * (i+1) / sides
		var a := center + Vector3(cos(angle)*bottom,-height*0.5,sin(angle)*bottom)
		var b := center + Vector3(cos(next)*bottom,-height*0.5,sin(next)*bottom)
		var c := center + Vector3(cos(next)*top,height*0.5,sin(next)*top)
		var d := center + Vector3(cos(angle)*top,height*0.5,sin(angle)*top)
		_quad(a,b,c,d,color.lightened(0.035 * (i%3)))
		_tri(center+Vector3(0,height*0.5,0),d,c,color.lightened(0.1))
		_tri(center-Vector3(0,height*0.5,0),b,a,color.darkened(0.15))

func _ellipsoid(center: Vector3, size: Vector3, color: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.radius = 1.0
	mesh.height = 2.0
	var faces := mesh.get_faces()
	for i in range(0,faces.size(),3):
		_tri(center+faces[i]*size,center+faces[i+1]*size,center+faces[i+2]*size,color)

func _roof(center: Vector3, width: float, depth: float, rise: float, color: Color) -> void:
	var a := center+Vector3(-width*0.5,0,-depth*0.5)
	var b := center+Vector3(-width*0.5,0,depth*0.5)
	var c := center+Vector3(width*0.5,0,depth*0.5)
	var d := center+Vector3(width*0.5,0,-depth*0.5)
	var ridge1 := center+Vector3(0,rise,-depth*0.5)
	var ridge2 := center+Vector3(0,rise,depth*0.5)
	_quad(a,b,ridge2,ridge1,color)
	_quad(ridge1,ridge2,c,d,color.lightened(0.12))
	_tri(a,ridge1,d,RED)
	_tri(b,c,ridge2,RED)
	_box(center+Vector3(-width*0.5,0,0),Vector3(12,12,depth+15),GOLD)
	_box(center+Vector3(width*0.5,0,0),Vector3(12,12,depth+15),GOLD)
	_box(center+Vector3(0,rise,0),Vector3(10,12,depth+20),GOLD)
	for z in [-depth*0.5,depth*0.5]:
		for x in [-width*0.5,width*0.5]:
			_tri(center+Vector3(x,0,z),center+Vector3(x,50,z),center+Vector3(x-signf(x)*42,5,z),GOLD)
		_frustum(center+Vector3(0,rise+34,z),14,0,68,GOLD,4)

func _guardian(root: Node3D, point: Vector2, paint: Color, title: String) -> void:
	_begin()
	transform = Transform3D(Basis(Vector3.UP,PI/4.0),Vector3(point.x,0,point.y))
	var accent := RED if paint == TEAL else TEAL
	# Three dominant forms: flared lower body, shoulder fan, oversized face/crown.
	_box(Vector3(0,22,0),Vector3(180,44,180),IVORY.darkened(0.18))
	_box(Vector3(0,51,0),Vector3(165,16,165),GOLD)
	for side in [-1.0,1.0]:
		_ellipsoid(Vector3(side*43,90,19),Vector3(31,33,45),paint.darkened(0.1))
		_frustum(Vector3(side*36,137,0),27,30,80,accent)
	_frustum(Vector3(0,202,0),92,58,110,paint)
	_frustum(Vector3(0,255,0),61,61,18,GOLD)
	_ellipsoid(Vector3(0,303,0),Vector3(78,58,47),paint)
	_frustum(Vector3(0,306,0),76,83,76,GOLD)
	_ellipsoid(Vector3(0,304,55),Vector3(47,45,14),accent)
	for side in [-1.0,1.0]:
		_ellipsoid(Vector3(side*92,317,0),Vector3(40,33,42),paint)
		_frustum(Vector3(side*92,329,0),39,29,24,GOLD)
		_ellipsoid(Vector3(side*79,271,31),Vector3(26,43,25),paint)
		_ellipsoid(Vector3(side*45,245,67),Vector3(36,23,22),paint)
	_frustum(Vector3(0,179,97),14,14,252,INK)
	_frustum(Vector3(0,301,97),23,18,27,GOLD)
	# Broad cheeks / jaw carry the face; eye and tusk shapes survive camera9.
	_ellipsoid(Vector3(0,395,0),Vector3(76,69,57),paint)
	_ellipsoid(Vector3(0,358,38),Vector3(55,28,35),paint.darkened(0.08))
	for side in [-1.0,1.0]:
		_ellipsoid(Vector3(side*74,403,0),Vector3(20,35,21),paint)
		_ellipsoid(Vector3(side*32,416,51),Vector3(28,19,13),INK)
		_ellipsoid(Vector3(side*32,416,62),Vector3(23,14,5),IVORY)
		_ellipsoid(Vector3(side*32,416,67),Vector3(10,12,3),INK)
		_tri(Vector3(side*7,440,57),Vector3(side*64,436,48),Vector3(side*50,454,47),GOLD)
		_frustum(Vector3(side*47,373,65),13,1,52,IVORY,6)
	_box(Vector3(0,369,62),Vector3(65,20,13),INK)
	_box(Vector3(0,369,70),Vector3(42,8,3),IVORY)
	_ellipsoid(Vector3(0,400,62),Vector3(18,18,16),paint.lightened(0.18))
	_frustum(Vector3(0,455,0),76,69,20,GOLD)
	_frustum(Vector3(0,482,0),62,43,34,accent)
	_frustum(Vector3(0,508,0),45,27,22,GOLD)
	_frustum(Vector3(0,543,0),23,0,54,GOLD)
	_end(root,title)

func _build(arena: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "PalaceTempleKit"
	_begin()
	_box(Vector3(2200,-6,1800),Vector3(4400,12,31390),Color("afbe85"))
	for record in arena.terrain.floor_areas:
		for a in arena.terrain.surface_areas(record):
			_box(Vector3(a.get_center().x,0.25,a.get_center().y),Vector3(a.size.x,0.5,a.size.y),record.color)
	# Wide, sparse courses frame quiet combat paving; no busy checkerboard.
	for z in [2080,3160]:
		_box(Vector3(2775,0.7,z),Vector3(2250,0.3,14),Color("bebba0"))
	for x in [1700,3850]:
		_box(Vector3(x,0.7,2630),Vector3(14,0.3,1050),Color("bebba0"))
	_box(Vector3(3200,0.8,1910),Vector3(1820,0.3,240),Color("748e88"))
	_end(root,"QuietPavingAndCloisterShade")
	_begin()
	var gate_basis := Basis(Vector3.UP,3.0*PI/4.0)
	transform = Transform3D(gate_basis,Vector3(1500,0,1800)-gate_basis*Vector3(960,0,1555))
	for z in [1180,1930]:
		_box(Vector3(960,40,z),Vector3(150,80,240),IVORY.darkened(0.14))
		_box(Vector3(960,245,z),Vector3(125,330,210),IVORY)
		_box(Vector3(960,376,z),Vector3(142,26,230),GOLD)
		_box(Vector3(1030,250,z),Vector3(10,290,165),RED)
	_box(Vector3(960,422,1555),Vector3(140,55,960),IVORY)
	_roof(Vector3(960,451,1555),350,1060,138,TEAL)
	_roof(Vector3(960,530,1555),265,865,110,RED)
	_roof(Vector3(960,601,1555),170,620,90,TEAL)
	_end(root,"ProcessionalGateLayeredRoofs")
	_guardian(root,Layout.gate_point(Layout.GUARDIAN_LOCAL[0]),TEAL,"TurquoiseYakshaGuardian")
	_guardian(root,Layout.gate_point(Layout.GUARDIAN_LOCAL[1]),RED,"VermilionYakshaGuardian")
	_begin()
	_box(Vector3(3185,115,1530),Vector3(1850,230,120),IVORY)
	_box(Vector3(3185,125,1600),Vector3(1540,150,12),INK)
	for x in [2340,2700,3060,3420,3780,4080]:
		_box(Vector3(x+26,20,1766),Vector3(82,40,82),IVORY.darkened(0.18))
		_frustum(Vector3(x+26,137,1766),26,23,195,IVORY)
		_box(Vector3(x+26,229,1766),Vector3(70,25,70),GOLD)
		if x == 4080: continue
		# One broad mural panel per bay, restrained flat color and diamond motif.
		_box(Vector3(x+142,125,1609),Vector3(195,125,4),TEAL if x%720==60 else RED.darkened(0.2))
		_tri(Vector3(x+107,130,1612),Vector3(x+142,165,1612),Vector3(x+177,130,1612),GOLD)
		_tri(Vector3(x+107,130,1612),Vector3(x+177,130,1612),Vector3(x+142,95,1612),GOLD)
	_box(Vector3(3185,247,1750),Vector3(1850,24,44),RED)
	# Ridge follows the long x axis using the same roof module turned 90 degrees.
	transform = Transform3D(Basis(Vector3.UP,PI/2.0),Vector3(3185,0,1645))
	_roof(Vector3(0,265,0),380,1920,93,TEAL)
	_roof(Vector3(0,328,0),260,1810,74,RED)
	_end(root,"ShadedPillaredCloister")
	_begin()
	_box(Vector3(4195,120,1415),Vector3(300,240,540),IVORY.darkened(0.16))
	_box(Vector3(4195,345,1415),Vector3(255,210,495),IVORY)
	_roof(Vector3(4195,468,1415),480,690,135,RED)
	_roof(Vector3(4195,553,1415),320,480,105,TEAL)
	_frustum(Vector3(4195,741,1390),73,35,180,GOLD)
	_frustum(Vector3(4195,876,1390),35,0,100,GOLD)
	_end(root,"DistantRaisedHall")
	root.set_meta("region_hierarchy",["동남아","왕궁 사원 후보","행렬문→밝은 중정→그늘 회랑"])
	root.set_meta("vertices",vertices)
	root.set_meta("opaque_landmarks",true)
	return root
