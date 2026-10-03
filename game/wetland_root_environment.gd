extends RefCounted
## Interlocked root silhouettes on submerged banks, using shared mesh batches.
const CLUSTERS := [Vector2(2270, 800), Vector2(2660, 770), Vector2(3660, 620), Vector2(360, 1160), Vector2(360, 1840)]
const ROOT_RADIUS := 85.0
static func build(arena: Node3D, clusters: Array = CLUSTERS) -> Node3D:
	var root := Node3D.new()
	root.name = "SubmergedRootGroves"
	var wood := SurfaceTool.new()
	var leaves := SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in clusters.size():
		var p: Vector2 = clusters[index]
		var base: Vector3 = arena.terrain.world_point(p)
		var bend := Vector3(0.22 if index % 2 else -0.22, 2.4, -0.16)
		var crown := base + bend + Vector3(0.13, 1.25, 0.10)
		_tube(wood, base, base + bend, 0.25, 0.16, Color("35453a"))
		_tube(wood, base + bend, crown, 0.16, 0.09, Color("445442"))
		for arm in 5:
			var angle := float(arm) * TAU / 5.0 + index * 0.4
			var edge := base + Vector3(cos(angle), 0, sin(angle)) * ROOT_RADIUS * 0.01
			var elbow := base.lerp(edge, 0.43) + Vector3.UP * 0.38
			_tube(wood, base + Vector3.UP * 0.74, elbow, 0.15, 0.10, Color("45523e"))
			_tube(wood, elbow, edge, 0.10, 0.025, Color("4d6048"))
		for arm in 3:
			var angle := float(arm) * TAU / 3.0 + index
			var tip := crown + Vector3(cos(angle) * 0.6, -0.12, sin(angle) * 0.6)
			_tube(wood, base + bend, tip, 0.095, 0.035, Color("35453a"))
			_tube(leaves, tip - Vector3.UP * 0.10, tip + Vector3.UP * 0.43, 0.73, 0.43, Color("355440") if arm % 2 else Color("46654b"))
	for pair in [[wood, "RootsAndTrunks"], [leaves, "BrokenCanopy"]]:
		var mesh := MeshInstance3D.new()
		mesh.name = pair[1]
		mesh.mesh = pair[0].commit()
		var material: StandardMaterial3D = arena._material(Color.WHITE)
		material.vertex_color_use_as_albedo = true
		mesh.material_override = material
		root.add_child(mesh)
	root.set_meta("visual_only", true)
	return root

static func _tube(st: SurfaceTool, start: Vector3, end: Vector3, first_radius: float, last_radius: float, color: Color) -> void:
	var axis := start.direction_to(end)
	var side := axis.cross(Vector3.RIGHT if absf(axis.dot(Vector3.UP)) > 0.95 else Vector3.UP).normalized()
	var other := axis.cross(side).normalized()
	for index in 7:
		var a := float(index) * TAU / 7.0
		var b := float(index + 1) * TAU / 7.0
		var first := side * cos(a) + other * sin(a)
		var second := side * cos(b) + other * sin(b)
		var vertices := [start + first * first_radius, end + first * last_radius, end + second * last_radius, start + second * first_radius]
		var normal: Vector3 = (vertices[2] - vertices[0]).cross(vertices[1] - vertices[0]).normalized()
		for i in [0, 2, 1, 0, 3, 2]:
			st.set_color(color)
			st.set_normal(normal)
			st.add_vertex(vertices[i])
		for vertex in [end, end + first * last_radius, end + second * last_radius]:
			st.set_color(color)
			st.set_normal(axis)
			st.add_vertex(vertex)
