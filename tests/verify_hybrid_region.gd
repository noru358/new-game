extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _walk(direction: Vector2, count: int, actor: SandboxPlayer) -> void:
	var screen := direction.rotated(PI / 4.0)
	var actions: Array[String] = []
	if screen.x > 0.1: actions.append("move_right")
	if screen.x < -0.1: actions.append("move_left")
	if screen.y > 0.1: actions.append("move_down")
	if screen.y < -0.1: actions.append("move_up")
	for action in actions: Input.action_press(action)
	await _frames(count)
	for action in actions: Input.action_release(action)
	await _frames(2)


func _run() -> void:
	var scene = load("res://game/hybrid_region.tscn").instantiate()
	scene.practice_mode = true
	scene.growth_save_prefix = "user://verify_hybrid_region_temp"
	root.add_child(scene)
	await _frames(4)
	scene.player.hurt_immunity = 1000.0
	for actor in scene.actors:
		if actor is TrainingEnemy: actor.set_physics_process(false)
	for companion in scene.growth.wisps: companion.set_physics_process(false)
	_check(scene.display_bounds().size == Vector2(5100, 2160) and scene.player.position.distance_to(Vector2(650, 1870)) < 10.0, "the wider 1G region opens in the hybrid first-court slice")
	_check(scene.terrain.height_at(Vector2(250, 1200)) == 160.0 and scene.terrain.height_at(Vector2(980, 1100)) == 320.0 and scene.terrain.height_at(Vector2(1950, 1100)) == 0.0, "first-court levels join three flat later spaces")
	var actors_ok := true
	var enemy_count := 0
	for actor in scene.actors:
		if actor is TrainingEnemy:
			enemy_count += 1
			if not scene.navigation.is_open(actor.position, scene.ACTOR_CLEARANCE): actors_ok = false
	_check(enemy_count == 8 and actors_ok, "all eight accepted enemy roles spawn on open hybrid-region ground")
	var all_routes := true
	for point in scene.enemy_points:
		if scene.navigation.find_path(point, scene.player.position).size() < 2:
			all_routes = false
	_check(all_routes, "every placed enemy has a navigation route to the player start")
	_check(not scene.clear_attack(Vector2(180, 1670), Vector2(520, 1670)) and scene.clear_attack(Vector2(180, 1880), Vector2(520, 1880)), "first-court water blocks combat but leaves a dry southern path")
	var footprint: PackedVector2Array = scene.minimap.camera_ground_footprint()
	_check(is_equal_approx(scene.camera.size, 9.0) and footprint.size() == 4 and footprint[0].distance_to(footprint[1]) < 1700.0 and footprint[0].distance_to(footprint[3]) < 1700.0, "the main region has a measured closer combat view")
	scene.overview = true
	scene.camera.size = scene.overview_camera_size
	scene._process(1.0)
	var full_overview := true
	for corner in [Vector2.ZERO, Vector2(5100, 0), Vector2(5100, 2160), Vector2(0, 2160)]:
		var pixel: Vector2 = scene.camera.unproject_position(Vector3(corner.x, 0.0, corner.y) * HybridTerrain.SCALE)
		if not Rect2(Vector2.ZERO, Vector2(1280, 720)).has_point(pixel): full_overview = false
	_check(full_overview, "Tab overview centers the entire integrated region")
	scene.overview = false
	scene.camera.size = scene.combat_camera_size
	scene.teleport(Vector2(1070, 1680))
	scene.player.attack_step = 1
	var strike: Dictionary = scene.player._attack_spec(1)
	scene.player.attack_elapsed = strike.windup + strike.active * 0.45
	scene.player.attack_direction = Vector2.RIGHT
	scene._draw_attack()
	var blade_vertices: PackedVector3Array = scene.attack_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var blade_colors: PackedColorArray = scene.attack_mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var bright_over_water := false
	for i in blade_vertices.size():
		var ground := Vector2(blade_vertices[i].x, blade_vertices[i].z) / HybridTerrain.SCALE
		if blade_colors[i].a > 0.4 and Rect2(1100, 1635, 250, 90).has_point(ground): bright_over_water = true
	_check(not bright_over_water, "the bright air slash does not claim range beyond blocking water")
	scene.player.attack_step = 0
	_check(not scene._ring_segment_clear(Vector2(1070, 1680), -0.02, 0.02, EnemyZone.RADIUS), "area warnings omit water-blocked sectors too")
	var lamp: TrainingEnemy = scene.actors.keys().filter(func(actor): return actor is TrainingEnemy and actor.role == TrainingEnemy.Role.LAMP)[0]
	lamp.position = Vector2(1030, 1680)
	scene.actor_motion[lamp] = [lamp.position, lamp.position]
	lamp.locked_direction = Vector2.RIGHT
	lamp.warning_time = 0.3
	scene._draw_enemy_warnings(1.0)
	var shot_vertices: PackedVector3Array = scene.warning_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var warning_over_water := false
	for vertex in shot_vertices:
		if Rect2(1100, 1635, 250, 90).has_point(Vector2(vertex.x, vertex.z) / HybridTerrain.SCALE): warning_over_water = true
	_check(not warning_over_water, "the ranged enemy's warning line also stops at deep water")
	lamp.warning_time = 0.0
	var start_map: Vector2 = scene.minimap._map_point_at(Vector2(200, 200), 0.0)
	var east_map: Vector2 = scene.minimap._map_point_at(Vector2(500, 200), 0.0)
	var south_map: Vector2 = scene.minimap._map_point_at(Vector2(200, 500), 0.0)
	_check(east_map.x > start_map.x and south_map.x < start_map.x, "the full-region minimap uses the gameplay camera diamond")
	_check(not scene.navigation.has_clear_path(Vector2(1900, 1100), Vector2(2660, 1100)) and scene.navigation.has_clear_path(Vector2(1900, 850), Vector2(2660, 850)) and scene.navigation.has_clear_path(Vector2(1900, 1350), Vector2(2660, 1350)), "expanded temple grounds keep two broad combat routes")
	_check(not scene.navigation.has_clear_path(Vector2(3180, 900), Vector2(3180, 1260)) and scene.navigation.has_clear_path(Vector2(3400, 900), Vector2(3400, 1260)), "wider gallery keeps two lanes with a cross passage")
	_check(scene.navigation.has_clear_path(Vector2(4450, 850), Vector2(4450, 1390)) and not scene.navigation.is_open(Vector2(4870, 1060), 18), "sanctuary center allows boss dodging while its relocated altar remains solid")
	var distant_path: PackedVector2Array = scene.navigation.find_path(Vector2(4750, 1100), Vector2(650, 1200))
	_check(distant_path.size() > 2, "one 2D navigation graph connects the first court to the sanctuary")
	var pull_target: TrainingEnemy = scene.actors.keys().filter(func(actor): return actor is TrainingEnemy)[0]
	scene.teleport(Vector2(1650, 1000))
	pull_target.position = Vector2(1820, 1000)
	pull_target.stagger_time = 1.0
	pull_target.set_physics_process(true)
	scene.player.set_combo_rank(2)
	scene.player.next_combo_step = 3
	scene.player.facing = Vector2.RIGHT
	scene.player._start_attack()
	for i in 12:
		await physics_frame
		if pull_target.gathering: break
	_check(pull_target.gathering, "the third hit catches an enemy at the visible reach edge")
	if pull_target.gathering:
		var pull_start: Vector2 = pull_target.position
		await _frames(2)
		_check(pull_target.position.distance_to(pull_start) > 30.0, "the pulled enemy moves visibly within two physics frames")
		await _frames(12)
		_check(pull_target.position.distance_to(pull_target.gather_target) < 8.0, "the edge target arrives near the player before the next combo hit")
	pull_target.set_physics_process(false)
	scene.player.attack_step = 0
	scene.teleport(Vector2(640, 1850))
	await _walk(Vector2.UP, 125, scene.player)
	_check(scene.terrain.height_at(scene.player.position) == 160.0, "player walks from the waterside lowland into the raised court")
	scene.teleport(Vector2(620, 1120))
	await _walk(Vector2.RIGHT, 130, scene.player)
	_check(scene.terrain.height_at(scene.player.position) == 320.0, "player reaches the upper terrace through its ramp")
	scene.teleport(Vector2(1170, 1150))
	await _walk(Vector2.RIGHT, 160, scene.player)
	_check(scene.terrain.height_at(scene.player.position) == 0.0 and scene.player.position.x > 1470.0, "player exits the raised first court into the flat temple grounds: %s" % scene.player.position)
	scene.teleport(Vector2(1150, 1150))
	var chaser: TrainingEnemy = scene.actors.keys().filter(func(actor): return actor is TrainingEnemy)[0]
	chaser.position = Vector2(1550, 1150)
	_check(scene.navigation.has_clear_path(chaser.position, scene.player.position), "the east connector is wide enough for direct enemy pursuit")
	chaser.set_physics_process(true)
	await _frames(420)
	_check(chaser.position.x < 1200.0 and scene.terrain.height_at(chaser.position) >= 160.0, "a distant enemy follows the east connector up into the court: %s" % chaser.position)
	scene.teleport(Vector2(4450, 1390))
	chaser.position = Vector2(4450, 850)
	chaser.velocity = Vector2.ZERO
	chaser.knockback = Vector2.ZERO
	chaser.navigation_path.clear()
	chaser.navigation_repath_time = 0.0
	await _frames(200)
	_check(chaser.position.distance_to(scene.player.position) < 300.0, "a sanctuary pursuer crosses the cleared central combat floor: %s" % chaser.position)
	scene.queue_free()
	await _frames(3)
	for suffix in ["_a.json", "_b.json"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://verify_hybrid_region_temp" + suffix))
	if failures == 0:
		print("Hybrid region verification passed: 5100x2160 terrain, diamond map, enemy spawns, water, routes and height links")
	quit(1 if failures else 0)
