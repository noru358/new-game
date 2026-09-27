extends SceneTree

const PREFIX := "user://verify_terrain_coherence_profile"
const UNLOCKS := "user://verify_terrain_coherence_unlocks"
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _run() -> void:
	var scene: Node3D = load("res://game/jungle_pass.tscn").instantiate()
	scene.profile_save_prefix = PREFIX
	scene.growth_save_prefix = UNLOCKS
	root.add_child(scene)
	await physics_frame
	await physics_frame
	for region in [scene.terrain, TempleHybridTerrain.new(), HybridTerrain.new()]:
		for wall in region.wall_areas:
			if not wall.get("visual", true): continue
			var center: Vector2 = wall.area.get_center()
			_check(float(wall.height) > region.height_at(center) + 20.0, "visible blocker rises above its walking surface")
			_check(is_equal_approx(float(wall.get("base", 0.0)), region.height_at(center)), "visible blocker starts at local floor height")
	var edge_case := {"area": Rect2(0, 0, 100, 100), "openings": {"north": [[0.0, 60.0]]}}
	var north_edges: Array = scene.terrain.plateau_edge_spans(edge_case).filter(func(edge): return edge.side == "north")
	_check(north_edges.size() == 1 and north_edges[0].start == 60.0 and north_edges[0].end == 100.0, "an opening at the cliff corner leaves only the blocked edge visible")
	_check(scene.navigation.is_open(Vector2(4595, 1160), scene.ACTOR_CLEARANCE), "clear gate passage remains open")
	for column in scene.terrain.gate_columns:
		_check(not scene.navigation.is_open(column.area.get_center(), scene.ACTOR_CLEARANCE), "visible column blocks its own footprint")
	_check(not scene.navigation.is_open(JunglePassTerrain.CANOPY_POINTS[0], scene.ACTOR_CLEARANCE), "tree silhouette and small trunk footprint agree")
	_check(scene.canopy_visuals.size() == JunglePassTerrain.CANOPY_POINTS.size(), "every blocking canopy trunk has a visible tree")
	for point in JunglePassTerrain.CANOPY_POINTS:
		var trunk: MeshInstance3D = scene.canopy_visuals.get(point)
		_check(trunk != null and trunk.visible and Vector2(trunk.position.x, trunk.position.z).distance_to(point * JunglePassTerrain.SCALE) < 0.01, "canopy visual sits on its collision footprint: %s" % point)
	_check(scene._attack_reach_at(Vector2(2400, 860), Vector2.DOWN.angle(), 130.0) >= 129.0, "same-height colored floor boundary does not trim the slash")
	_check(scene._attack_reach_at(Vector2(2210, 570), Vector2.RIGHT.angle(), 130.0) < 100.0, "slash trims only at the now-visible canopy trunk")
	for chasm in scene.terrain.chasm_areas:
		_check(not scene.navigation.is_open(chasm.get_center(), scene.ACTOR_CLEARANCE), "visible canyon void blocks its own footprint")
	scene.teleport(Vector2(2590, 1770))
	await physics_frame
	_check(scene.gate_route_encounter == "rocks" and scene._active_enemy_count() == 2, "lower canyon starts with a separate ledge encounter: %s / %d" % [scene.gate_route_encounter, scene._active_enemy_count()])
	scene.teleport(Vector2(3420, 1780))
	await physics_frame
	_check(scene.gate_route_crest_triggered and scene._active_enemy_count() == 4, "canyon bridge adds a second encounter before the gate")
	var lintel: MeshInstance3D = scene.get_node("GateLintel")
	var lintel_mesh: BoxMesh = lintel.mesh
	var column_left: float = (JunglePassTerrain.GATE_COLUMN_CENTERS[0].x - JunglePassTerrain.GATE_COLUMN_SIZE.x * 0.5) * JunglePassTerrain.SCALE
	var column_top: float = scene.terrain.gate_columns[0].height * JunglePassTerrain.SCALE
	_check(lintel.position.x - lintel_mesh.size.x * 0.5 < column_left - 0.1 and lintel.position.y - lintel_mesh.size.y * 0.5 < column_top - 0.1, "lintel overlaps columns without coincident outer faces")
	var player: SandboxPlayer = scene.player
	var guided := player._ramp_guided_direction(Vector2(1, 1).normalized())
	player.global_position = Vector2(3270, 1460)
	guided = player._ramp_guided_direction(Vector2(1, 1).normalized())
	_check(guided.x > 0.0 and guided.y < 0.0, "off-center approach guides inward toward ramp mouth")
	player.global_position = Vector2(3270, 1580)
	_check(player._ramp_guided_direction(Vector2(1, 1).normalized()).is_equal_approx(Vector2(1, 1).normalized()), "no assist away from ramp mouth")
	player.moving_slash_enabled = true
	player.global_position = Vector2(3270, 1400)
	player._start_moving_slash(Vector2(1, 1))
	for i in 22: await physics_frame
	_check(player.global_position.x > 3350.0 and player.global_position.y < 1450.0, "moving slash enters the gate ramp from its corner")
	player.moving_slash_time = 0.0
	player.global_position = Vector2(3270, 1400)
	Input.action_press("move_down")
	for i in 32: await physics_frame
	Input.action_release("move_down")
	_check(player.global_position.x > 3350.0 and player.global_position.y < 1450.0, "diagonal walking also enters the gate ramp")
	player.global_position = Vector2(3420, 1120)
	Input.action_press("move_down")
	for i in 30: await physics_frame
	Input.action_release("move_down")
	var single_key_distance: float = player.global_position.x - 3420.0
	player.global_position = Vector2(3420, 1120)
	Input.action_press("move_down")
	Input.action_press("move_right")
	for i in 30: await physics_frame
	Input.action_release("move_down")
	Input.action_release("move_right")
	var diagonal_key_distance: float = player.global_position.x - 3420.0
	_check(single_key_distance > diagonal_key_distance * 0.9, "screen-axis travel keeps full ramp speed: %.1f / %.1f" % [single_key_distance, diagonal_key_distance])
	for region in [scene.terrain, TempleHybridTerrain.new(), HybridTerrain.new()]:
		player.ramp_areas = region.ramps
		for ramp in region.ramps:
			player.global_position = ramp.area.get_center()
			var along := Vector2.RIGHT if ramp.axis == 0 else Vector2.DOWN
			var corrected: Vector2 = player._ramp_guided_direction(Vector2(1, 1).normalized())
			_check(absf(corrected.dot(along)) > 0.99 and is_equal_approx(corrected.length(), 1.0), "single-key input maintains full speed on %s" % ramp.name)
	player.ramp_areas = scene.terrain.ramps
	var dash_events := InputMap.action_get_events("dash")
	var slash_events := InputMap.action_get_events("moving_slash")
	_check(dash_events.size() == 1 and dash_events[0] is InputEventKey and dash_events[0].physical_keycode == KEY_SHIFT, "dash is bound to Shift")
	_check(slash_events.size() == 1 and slash_events[0] is InputEventKey and slash_events[0].physical_keycode == KEY_SPACE, "moving slash is bound to Space")
	scene.queue_free()
	await physics_frame
	paused = false
	for prefix in [PREFIX, UNLOCKS]:
		for suffix in ["_a.json", "_b.json"]:
			var path := ProjectSettings.globalize_path(prefix + suffix)
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	if failures == 0: print("Terrain coherence verification passed: visible blockers, gate passage, ramp guidance")
	quit(1 if failures else 0)
