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
	scene.teleport(Vector2(2590, 1690))
	await physics_frame
	_check(scene.gate_route_encounter == "rocks" and scene._active_enemy_count() == 2, "southern cliff approach starts with a separate ledge encounter: %s / %d" % [scene.gate_route_encounter, scene._active_enemy_count()])
	scene.teleport(Vector2(3420, 1700))
	await physics_frame
	_check(scene.gate_route_crest_triggered and scene._active_enemy_count() == 4, "southern cliff route adds a second encounter before the gate")
	var lintel: MeshInstance3D = scene.get_node("GateLintel")
	var lintel_mesh: BoxMesh = lintel.mesh
	var column_left: float = (JunglePassTerrain.GATE_COLUMN_CENTERS[0].x - JunglePassTerrain.GATE_COLUMN_SIZE.x * 0.5) * JunglePassTerrain.SCALE
	var column_top: float = scene.terrain.gate_columns[0].height * JunglePassTerrain.SCALE
	_check(lintel.position.x - lintel_mesh.size.x * 0.5 < column_left - 0.1 and lintel.position.y - lintel_mesh.size.y * 0.5 < column_top - 0.1, "lintel overlaps columns without coincident outer faces")
	var player: SandboxPlayer = scene.player
	var guided := player._ramp_guided_direction(Vector2(1, 1).normalized())
	player.global_position = Vector2(3520, 1460)
	guided = player._ramp_guided_direction(Vector2(1, 1).normalized())
	_check(guided.x > 0.0 and guided.y < 0.0, "off-center approach guides inward toward ramp mouth")
	player.global_position = Vector2(3520, 1580)
	_check(player._ramp_guided_direction(Vector2(1, 1).normalized()).is_equal_approx(Vector2(1, 1).normalized()), "no assist away from ramp mouth")
	player.global_position = Vector2(3520, 1460)
	player.moving_slash_enabled = true
	player._start_moving_slash(Vector2(1, 1))
	for i in 22: await physics_frame
	_check(player.global_position.x > 3600.0 and player.global_position.y < 1450.0, "moving slash enters the gate ramp from its corner")
	player.moving_slash_time = 0.0
	player.global_position = Vector2(3520, 1460)
	Input.action_press("move_down")
	for i in 32: await physics_frame
	Input.action_release("move_down")
	_check(player.global_position.x > 3600.0 and player.global_position.y < 1450.0, "diagonal walking also enters the gate ramp")
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
