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
	scene.growth_save_prefix = "user://verify_hybrid_region_temp"
	root.add_child(scene)
	await _frames(4)
	scene.player.hurt_immunity = 1000.0
	for actor in scene.actors:
		if actor is TrainingEnemy: actor.set_physics_process(false)
	for companion in scene.growth.wisps: companion.set_physics_process(false)
	_check(scene.terrain.map_size == Vector2(3840, 2160) and scene.player.position.distance_to(Vector2(650, 1870)) < 10.0, "the actual 1F region opens in the hybrid first-court slice")
	_check(scene.terrain.height_at(Vector2(500, 1200)) == 160.0 and scene.terrain.height_at(Vector2(980, 1100)) == 320.0 and scene.terrain.height_at(Vector2(1950, 1100)) == 0.0, "first-court levels join three flat later spaces")
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
	var start_map: Vector2 = scene.minimap._map_point_at(Vector2(200, 200), 0.0)
	var east_map: Vector2 = scene.minimap._map_point_at(Vector2(500, 200), 0.0)
	var south_map: Vector2 = scene.minimap._map_point_at(Vector2(200, 500), 0.0)
	_check(east_map.x > start_map.x and south_map.x < start_map.x, "the full-region minimap uses the gameplay camera diamond")
	var distant_path: PackedVector2Array = scene.navigation.find_path(Vector2(3250, 1100), Vector2(650, 1200))
	_check(distant_path.size() > 2, "one 2D navigation graph connects the first court to the sanctuary")
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
	scene.queue_free()
	await _frames(3)
	for suffix in ["_a.json", "_b.json"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://verify_hybrid_region_temp" + suffix))
	if failures == 0:
		print("Hybrid region verification passed: 3840x2160 terrain, diamond map, enemy spawns, water, routes and height links")
	quit(1 if failures else 0)
