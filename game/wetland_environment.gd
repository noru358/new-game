extends RefCounted
const Wetland = preload("res://game/deep_wetland_terrain.gd")
static func build(arena: Node3D) -> void:
	dry_paths(arena)
	# Broad irregular stone facets, not noisy pebble carpets.
	for i in 12:
		var p := Vector2(1050 + i * 70, 2080 + sin(i * 0.7) * 55)
		stone(arena, p, Vector3(0.55, 0.022, 0.65), Color("a0a087"))
	for p in [Vector2(1080, 1980), Vector2(1810, 1970), Vector2(2940, 610), Vector2(3340, 570)]:
		stone(arena, p, Vector3(0.72, 1.2, 0.68), Color("8a9279"))
	for p in [Vector2(2940, 660), Vector2(2940, 1100), Vector2(3340, 660), Vector2(3340, 1100)]:
		stone(arena, p, Vector3(0.65, 0.065, 0.75), Color("b9b28e"))
	face(arena)
	arena.add_child(preload("res://game/wetland_root_environment.gd").build(arena))
	var groves: Array = arena._far_bank_groves().duplicate()
	for i in 24:
		groves.append(Vector2(820+i*79,230+sin(i*0.6)*90))
	arena.add_child(preload("res://game/wetland_canopy_environment.gd").build(arena,groves,"FarBankCanopyKit"))
	arena.add_child(preload("res://game/wetland_waterbank_details.gd").build(arena))

static func stone(arena: Node3D, p: Vector2, size: Vector3, color: Color, lift: float = 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.radial_segments = 7
	mesh.rings = 1
	mesh.top_radius = 0.78
	mesh.bottom_radius = 1.0
	mesh.height = 2.0
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.scale = size
	node.position = arena.terrain.world_point(p, lift) + Vector3.UP * size.y
	node.rotation.y = fmod(p.x * 0.031, TAU)
	node.material_override = arena._material(color)
	arena.add_child(node)
	return node

static func face(arena: Node3D) -> void:
	# A singular far-bank monument, contrasted with unchanged human-scale ruins.
	# Keep the opaque geometry inside impassable water; no camera zoom or cutaway.
	var first_child := arena.get_child_count()
	_face_components(arena)
	var pieces: Array[Node] = []
	for i in range(first_child, arena.get_child_count()): pieces.append(arena.get_child(i))
	var monument := Node3D.new()
	monument.name = "MonumentalWetlandFace"
	arena.add_child(monument)
	monument.position = arena.terrain.world_point(Wetland.FACE)
	for piece in pieces: piece.reparent(monument, true)
	monument.scale = Vector3(2.4, 2.4, 2.4)
	monument.position = arena.terrain.world_point(Vector2(2440, 950))
	monument.set_meta("visual_only", true)
	monument.set_meta("scale_trial", Vector3(2.4, 2.4, 2.4))

static func _face_components(arena: Node3D) -> void:
	var p: Vector2 = Wetland.FACE
	stone(arena, p, Vector3(1.08, 1.6, 0.9), Color("8c9981"))
	stone(arena, p + Vector2(0, 5), Vector3(1.24, 0.22, 1.0), Color("70896e"), 288)
	# Eyes, brow and nose face the dry southern bank; no glowing gimmicks.
	for x in [-46, 46]:
		stone(arena, p + Vector2(x, 79), Vector3(0.29, 0.09, 0.07), Color("354b42"), 189)
		stone(arena, p + Vector2(x, 80), Vector3(0.37, 0.09, 0.10), Color("a3aa8a"), 213)
	stone(arena, p + Vector2(0, 90), Vector3(0.17, 0.38, 0.23), Color("a0a788"), 128)
	stone(arena, p + Vector2(0, 82), Vector3(0.38, 0.065, 0.09), Color("485e4d"), 101)
	# Broad layered headdress and moss cap tie the face to the temple architecture.
	stone(arena,p,Vector3(1.35,0.13,1.08),Color("83967b"),310)
	stone(arena,p,Vector3(1.12,0.16,0.9),Color("a0ab8a"),335)
	stone(arena,p+Vector2(-38,17),Vector3(0.60,0.09,0.5),Color("5d7858"),362)

static func dry_paths(arena: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	for route in arena._dry_routes():
		for i in range(route.size() - 1):
			var a: Vector2 = route[i]
			var b: Vector2 = route[i + 1]
			var along: Vector2 = a.direction_to(b)
			var side := along.orthogonal()
			var steps := maxi(1, ceili(a.distance_to(b) / 90.0))
			for j in steps:
				var first := a.lerp(b, float(j) / steps)
				var last := a.lerp(b, float(j + 1) / steps)
				var width := 72.0 + 18.0 * sin(float(i * 7 + j) * 0.5)
				var corners := [first + side * width, last + side * width, last - side * width, first - side * width]
				var dry := true
				var footprint := Rect2(corners[0], Vector2.ZERO)
				for corner in corners: footprint = footprint.expand(corner)
				for water in arena.terrain.water_areas:
					if water.grow(20).intersects(footprint): dry = false
				if not dry: continue
				var points: Array = []
				for corner in corners: points.append(Vector3(corner.x, 0.7, corner.y))
				arena._quad(st, points, Color("7c8868"))
				count += 1
	if count == 0: return
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	var material: StandardMaterial3D = arena._material(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	node.material_override = material
	arena.add_child(node)


static func build_field(arena: Node3D) -> void:
	for area in arena._inner_ruins():
		stone(arena, area.get_center(), Vector3(area.size.x / 200.0, 0.55, area.size.y / 200.0), Color("85927a"))
	# The inner temple silhouette lives on the blocked far bank; its combat floor stays clear.
	for x in [4740, 4940, 5140]:
		stone(arena, Vector2(x, 380), Vector3(0.8, 2.0, 0.8), Color("677e70"))
		stone(arena, Vector2(x, 380), Vector3(1.15, 0.18, 1.0), Color("899982"), 360)
	var beam = stone(arena,Vector2(4840,380),Vector3(1.20,0.16,0.77),Color("8a987e"),390)
	beam.rotation.y=0
	var broken_beam = stone(arena,Vector2(5060,380),Vector3(0.72,0.18,0.77),Color("7c9077"),391)
	broken_beam.rotation.y=0
	arena.add_child(preload("res://game/wetland_canopy_environment.gd").build(arena,[Vector2(4350,300),Vector2(5440,300)],"InnerCanopyKit"))
