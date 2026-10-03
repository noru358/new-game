extends RefCounted
## Original cel-form palace kit. Reference image stays outside the repository.
const IVORY := Color("f2e5c9")
const GOLD := Color("c49b42")
const RED := Color("a74840")
const TEAL := Color("23776e")
const INK := Color("314b4d")
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
	_box(Vector3(0,18,0),Vector3(165,36,180),IVORY.darkened(0.2))
	_box(Vector3(0,48,0),Vector3(150,24,166),IVORY)
	for side in [-1.0,1.0]:
		_box(Vector3(side*35,83,13),Vector3(45,48,75),paint.darkened(0.1))
		_frustum(Vector3(side*32,130,0),24,29,70,RED if paint == TEAL else TEAL)
	_frustum(Vector3(0,190,0),76,52,100,paint)
	_frustum(Vector3(0,245,0),55,55,18,GOLD)
	_ellipsoid(Vector3(0,288,0),Vector3(68,58,40),paint)
	# Broad breastplate, paired shoulders and rigid club make an upright yaksha.
	_box(Vector3(0,284,39),Vector3(73,72,13),GOLD)
	_box(Vector3(0,284,47),Vector3(42,44,5),RED if paint == TEAL else TEAL)
	for side in [-1.0,1.0]:
		_ellipsoid(Vector3(side*76,306,0),Vector3(28,26,32),GOLD)
		_ellipsoid(Vector3(side*72,265,26),Vector3(21,44,23),paint)
		_ellipsoid(Vector3(side*42,236,52),Vector3(33,20,21),paint)
		_box(Vector3(side*44,237,70),Vector3(24,24,20),GOLD)
	_frustum(Vector3(0,171,86),11,11,270,INK)
	_frustum(Vector3(0,289,86),20,16,38,GOLD)
	_frustum(Vector3(0,46,86),22,16,16,GOLD)
	_ellipsoid(Vector3(0,365,4),Vector3(56,51,45),paint)
	for side in [-1.0,1.0]:
		_ellipsoid(Vector3(side*54,371,0),Vector3(17,26,15),paint)
		_box(Vector3(side*24,380,45),Vector3(32,14,9),INK)
		_box(Vector3(side*24,377,51),Vector3(21,6,4),IVORY)
		_box(Vector3(side*24,377,54),Vector3(5,7,3),INK)
		# Raised eyebrows and upward ivory tusks; no borrowed idol face.
		_tri(Vector3(side*7,394,46),Vector3(side*46,391,44),Vector3(side*39,405,43),GOLD)
		_tri(Vector3(side*32,333,46),Vector3(side*43,365,48),Vector3(side*24,349,54),IVORY)
	_box(Vector3(0,350,45),Vector3(58,13,14),INK)
	_box(Vector3(0,350,54),Vector3(42,6,3),IVORY)
	_ellipsoid(Vector3(0,367,51),Vector3(13,12,13),paint.lightened(0.2))
	_frustum(Vector3(0,410,0),58,54,17,GOLD)
	_frustum(Vector3(0,431,0),48,35,26,RED if paint == TEAL else TEAL)
	_frustum(Vector3(0,454,0),34,20,20,GOLD)
	_frustum(Vector3(0,480,0),18,0,36,GOLD)
	_end(root,title)

func _build(arena: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "PalaceTempleKit"
	_begin()
	_box(Vector3(1700,-6,1250),Vector3(3400,12,2500),Color("afbe85"))
	for record in arena.terrain.floor_areas:
		var a: Rect2 = record.area
		_box(Vector3(a.get_center().x,0.25,a.get_center().y),Vector3(a.size.x,0.5,a.size.y),record.color)
	# Wide, sparse courses frame quiet combat paving; no busy checkerboard.
	for z in [1190,2010]:
		_box(Vector3(2130,0.7,z),Vector3(1740,0.3,14),Color("bebba0"))
	for x in [1330,2830]:
		_box(Vector3(x,0.7,1600),Vector3(14,0.3,830),Color("bebba0"))
	_box(Vector3(2200,0.8,1030),Vector3(1550,0.3,190),Color("748e88"))
	_end(root,"QuietPavingAndCloisterShade")
	_begin()
	for z in [1180,1930]:
		_box(Vector3(960,40,z),Vector3(150,80,240),IVORY.darkened(0.14))
		_box(Vector3(960,245,z),Vector3(125,330,210),IVORY)
		_box(Vector3(960,376,z),Vector3(142,26,230),GOLD)
		_box(Vector3(1030,250,z),Vector3(10,290,165),RED)
	_box(Vector3(960,422,1555),Vector3(140,55,960),IVORY)
	_roof(Vector3(960,451,1555),350,1060,138,TEAL)
	_roof(Vector3(960,530,1555),265,865,110,RED)
	_roof(Vector3(960,601,1555),170,620,90,TEAL)
	for z in [1030,2075]:
		_box(Vector3(590,80,z),Vector3(620,160 if z == 1030 else 85,65),IVORY)
		_box(Vector3(590,166 if z == 1030 else 126,z),Vector3(640,14,80),RED)
	_end(root,"ProcessionalGateLayeredRoofs")
	_guardian(root,Vector2(800,1180),TEAL,"TurquoiseYakshaGuardian")
	_guardian(root,Vector2(800,1930),RED,"VermilionYakshaGuardian")
	_begin()
	_box(Vector3(2225,115,680),Vector3(1610,230,120),IVORY)
	_box(Vector3(2225,125,750),Vector3(1540,150,12),INK)
	for x in [1500,1860,2220,2580,2940]:
		_box(Vector3(x+26,20,916),Vector3(82,40,82),IVORY.darkened(0.18))
		_frustum(Vector3(x+26,137,916),26,23,195,IVORY)
		_box(Vector3(x+26,229,916),Vector3(70,25,70),GOLD)
		# One broad mural panel per bay, restrained flat color and diamond motif.
		_box(Vector3(x+142,125,759),Vector3(195,125,4),TEAL if x%720==60 else RED.darkened(0.2))
		_tri(Vector3(x+107,130,762),Vector3(x+142,165,762),Vector3(x+177,130,762),GOLD)
		_tri(Vector3(x+107,130,762),Vector3(x+177,130,762),Vector3(x+142,95,762),GOLD)
	_box(Vector3(2225,247,900),Vector3(1660,24,44),RED)
	# Ridge follows the long x axis using the same roof module turned 90 degrees.
	transform = Transform3D(Basis(Vector3.UP,PI/2.0),Vector3(2225,0,795))
	_roof(Vector3(0,265,0),380,1740,93,TEAL)
	_roof(Vector3(0,328,0),260,1630,74,RED)
	_end(root,"ShadedPillaredCloister")
	_begin()
	_box(Vector3(3100,120,625),Vector3(300,240,540),IVORY.darkened(0.16))
	_box(Vector3(3100,345,625),Vector3(255,210,495),IVORY)
	_roof(Vector3(3100,468,625),480,690,135,RED)
	_roof(Vector3(3100,553,625),320,480,105,TEAL)
	_frustum(Vector3(3100,741,600),73,35,180,GOLD)
	_frustum(Vector3(3100,876,600),35,0,100,GOLD)
	_end(root,"DistantRaisedHall")
	root.set_meta("region_hierarchy",["동남아","왕궁 사원 후보","행렬문→밝은 중정→그늘 회랑"])
	root.set_meta("vertices",vertices)
	root.set_meta("opaque_landmarks",true)
	return root
