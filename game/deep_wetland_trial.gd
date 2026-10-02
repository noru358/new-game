extends "res://game/hybrid_height.gd"
## Standalone construction sample: no profile, XP, settlement or new unlocks.
const Wetland = preload("res://game/deep_wetland_terrain.gd")

func _init() -> void:
	terrain = Wetland.new()
	start_point = Wetland.ENTRY
	enemy_points = [Vector2(1300, 2180), Vector2(2140, 1550), Vector2(2840, 1510), Vector2(3230, 1030)]
	landmark_points = {"입구": Wetland.ENTRY, "참배길": Wetland.PROCESSION, "얼굴 유적": Wetland.FACE_BANK, "사원뜰": Wetland.TEMPLE_COURT}
	combat_camera_size = 9.0
	overview_camera_size = 48.0
	camera_offset = Vector3(14, 13.864, 14)
	ground_color = Color("4c6858")
	scene_title = "Deep Temple Wetland — representative route"
	show_practice_controls = false
	moving_slash_practice = true
	growth_save_prefix = "user://deep_wetland_trial_unused_unlocks"

func _ready() -> void:
	super._ready()
	growth.growth_ended = true
	growth.hud.hide()
	growth.xp_bar.hide()
	growth.last_choice_label.hide()
	player.set_combo_rank(2)
	build_summary_label.hide()
	minimap.hide()
	_update_hud()

func _build_ui() -> void:
	super._build_ui()
	for canvas in get_children():
		if not canvas is CanvasLayer: continue
		var hint := canvas.get_node_or_null("ControlsHint")
		if hint != null:
			hint.text = "WASD 이동 · J 공격 · Space 베기 · Shift 대시 · Tab 지도 · Esc 정지 · R 재시작 · G 야영지"
			hint.position = Vector2(20, 680)

func _on_enemy_defeated(_enemy: TrainingEnemy) -> void:
	kills += 1

func _update_hud() -> void:
	if hud == null or not is_instance_valid(player): return
	hud.text = "깊은 사원 습지 · 대표 구간\n%s · HP %d · 저장/보상 없음" % [terrain.surface_name(player.position), ceili(player.health)]
	if player_health_bar != null:
		player_health_bar.max_value = player.max_health
		player_health_bar.value = player.health

func _process(delta: float) -> void:
	super._process(delta)
	if overview:
		camera.position = terrain.world_point(terrain.map_size * 0.5) + camera_offset.normalized() * 90.0
		camera.look_at(terrain.world_point(terrain.map_size * 0.5), Vector3.UP)

func _top(st: SurfaceTool, area: Rect2, elevation: Callable, color: Color) -> void:
	# This place sample has no prototype checkerboard. Preserve physical boundaries.
	var tint := Color("294e50") if color == Color("39858b") else color
	var points: Array = []
	for p in [area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)]:
		points.append(Vector3(p.x, elevation.call(p), p.y))
	_quad(st, points, tint)

func _build_terrain(render_bounds := Rect2()) -> void:
	super._build_terrain(render_bounds)
	_build_dry_paths()
	# Broad irregular stone facets, not noisy pebble carpets.
	for i in 12:
		var p := Vector2(1050 + i * 70, 2080 + sin(i * 0.7) * 55)
		_stone(p, Vector3(0.55, 0.022, 0.65), Color("a0a087"))
	for p in [Vector2(1080, 1980), Vector2(1810, 1970), Vector2(2940, 610), Vector2(3340, 570)]:
		_stone(p, Vector3(0.72, 1.2, 0.68), Color("8a9279"))
	for p in [Vector2(2940, 660), Vector2(2940, 1100), Vector2(3340, 660), Vector2(3340, 1100)]:
		_stone(p, Vector3(0.65, 0.065, 0.75), Color("b9b28e"))
	_build_face()
	# Silhouettes stay in blocked water along the far bank, not over the route.
	for p in [Vector2(330, 450), Vector2(420, 1110), Vector2(390, 1900), Vector2(1140, 300), Vector2(1770, 350), Vector2(3650, 400), Vector2(3670, 1000)]:
		_stone(p, Vector3(0.55, 2.4, 0.7), Color("394f44"))
		_stone(p + Vector2(-35, 25), Vector3(1.45, 0.8, 1.25), Color("355b4a"), 340)
	# Far-bank canopy clusters grow into blocked water only; the walking bank stays clear.
	for i in 24:
		var p := Vector2(820 + i * 79, 220 + sin(i * 0.6) * 90)
		_stone(p, Vector3(0.3, 1.7 + 0.15 * (i % 3), 0.4), Color("344e40"))
		for offset in [Vector2(-45, 0), Vector2(45, 20), Vector2(0, -50)]:
			_stone(p + offset, Vector3(0.95, 0.42, 0.85), Color("3d6450"), 295 + (i % 4) * 14)
	# Reed clusters mark only existing blocked water boundaries.
	for i in 24:
		var p := Vector2(2470 + i * 53, 1810 + 15 * sin(i))
		_stone(p, Vector3(0.055, 0.25 + 0.08 * (i % 3), 0.055), Color("66866a"))

func _stone(p: Vector2, size: Vector3, color: Color, lift: float = 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.radial_segments = 7
	mesh.rings = 1
	mesh.top_radius = 0.78
	mesh.bottom_radius = 1.0
	mesh.height = 2.0
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.scale = size
	node.position = terrain.world_point(p, lift) + Vector3.UP * size.y
	node.rotation.y = fmod(p.x * 0.031, TAU)
	node.material_override = _material(color)
	add_child(node)
	return node

func _build_face() -> void:
	var p: Vector2 = Wetland.FACE
	_stone(p, Vector3(1.08, 1.6, 0.9), Color("8c9981"))
	_stone(p + Vector2(0, 5), Vector3(1.24, 0.22, 1.0), Color("70896e"), 288)
	# Eyes, brow and nose face the dry southern bank; no glowing gimmicks.
	for x in [-46, 46]:
		_stone(p + Vector2(x, 79), Vector3(0.29, 0.09, 0.07), Color("354b42"), 189)
		_stone(p + Vector2(x, 80), Vector3(0.37, 0.09, 0.10), Color("a3aa8a"), 213)
	_stone(p + Vector2(0, 90), Vector3(0.17, 0.38, 0.23), Color("a0a788"), 128)
	_stone(p + Vector2(0, 82), Vector3(0.38, 0.065, 0.09), Color("485e4d"), 101)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
		_set_paused(false)
		get_tree().change_scene_to_file("res://game/travel_camp.tscn")
		return
	super._input(event)

func _build_dry_paths() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	for route in [Wetland.WAYPOINTS, Wetland.SIDE_ROUTE]:
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
				for water in terrain.water_areas:
					if water.grow(20).intersects(footprint): dry = false
				if not dry: continue
				var points: Array = []
				for corner in corners: points.append(Vector3(corner.x, 0.7, corner.y))
				_quad(st, points, Color("7c8868"))
				count += 1
	if count == 0: return
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	var material := _material(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	node.material_override = material
	add_child(node)
