extends "res://game/deep_wetland_trial.gd"
## Topology only. Existing temple, garden discovery and save IDs are untouched.
const Circuit = preload("res://game/temple_circuit_trial_terrain.gd")

func _init() -> void:
	terrain = Circuit.new()
	combat_camera_size = 9.0
	camera_offset = Vector3(14, 13.864, 14)
	show_practice_controls = false
	moving_slash_practice = true
	start_point = Circuit.ENTRY
	enemy_points = [Vector2(2200, 2170), Vector2(1400, 1500), Vector2(3400, 1900), Vector2(2700, 1040)]
	landmark_points = {"입구": Circuit.ENTRY, "중심 뜰": Circuit.CENTRAL_COURT, "회랑": Circuit.CLOISTER, "성소": Circuit.SANCTUARY}
	ground_color = Color("889e83")
	scene_title = "Temple — full-field circuit layout candidate"
	growth_save_prefix = "user://temple_circuit_trial_unused_unlocks"
	overview_camera_size = 54.0

func _build_terrain(_render_bounds := Rect2()) -> void:
	# Shared base mesh builder, deliberately without wetland dressing.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_top(st, Rect2(Vector2.ZERO, terrain.map_size), func(_p): return 0.0, ground_color)
	for floor in terrain.floor_areas:
		_top(st, floor.area, func(_p): return floor.height, floor.color)
	for water in terrain.water_areas:
		_top(st, water, func(_p): return 1.0, Color("39858b"))
	st.generate_normals()
	terrain_mesh = MeshInstance3D.new()
	terrain_mesh.mesh = st.commit()
	var mat := _material(Color.WHITE)
	mat.vertex_color_use_as_albedo = true
	terrain_mesh.material_override = mat
	add_child(terrain_mesh)
	for wall in terrain.wall_areas:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(wall.area.size.x, wall.height, wall.area.size.y) * 0.01
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.position = terrain.world_point(wall.area.get_center(), wall.height * 0.5)
		node.material_override = _material(wall.color)
		add_child(node)

func _update_hud() -> void:
	super._update_hud()
	if hud != null: hud.text = hud.text.replace("깊은 사원 습지 · 대표 구간", "사원 · 전체 동선 후보")
