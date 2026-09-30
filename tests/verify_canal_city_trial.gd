extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var city: Node3D = load("res://game/canal_city_trial.tscn").instantiate()
	root.add_child(city)
	await process_frame
	_check(city.terrain.map_size == Vector2(7200, 4800), "v2 trial size")
	_check(city.terrain.plateaus.is_empty() and city.terrain.ramps.is_empty(), "flat traversal")
	_check(not city.growth.unlocks.save_enabled, "no permanent growth progress")
	_check(_enemy_count(city) == 0, "scenic mode starts without enemies")
	for point in [Vector2(4000, 2410), Vector2(4050, 1080), Vector2(2550, 3700), Vector2(430, 730)]:
		_check(not city.navigation.is_open(point, 30.0), "water/building/boundary blocked at %s" % point)
	for point in [Vector2(3420, 2430), Vector2(5190, 2500), Vector2(4460, 2610), city.start_point]:
		_check(city.navigation.is_open(point, 30.0), "bridge/dock/entrance open at %s" % point)
	var route := [city.start_point, Vector2(4510, 1510), Vector2(4570, 3140), Vector2(1840, 1500), city.start_point]
	for i in route.size() - 1:
		var path: PackedVector2Array = city.navigation.find_path(route[i], route[i + 1])
		_check(path.size() > 2, "route %d available" % i)
		if path.size() > 2: print("Canal route %d: %d nodes, %.0f units" % [i, path.size(), _path_length(path)])
	for bridge in CanalCityTerrain.BRIDGES:
		var mid_x: float = bridge.get_center().x
		for segment in [[Vector2(mid_x, 2040), Vector2(mid_x, 2940)], [Vector2(mid_x, 2940), Vector2(mid_x, 2040)]]:
			_check(city.navigation.find_path(segment[0], segment[1]).size() > 2, "bridge %.0f roundtrip" % mid_x)
	city.teleport(Vector2(4000, 2150))
	Input.action_press("move_left", 0.707)
	Input.action_press("move_down", 0.707)
	for frame in 100: await physics_frame
	Input.action_release("move_left")
	Input.action_release("move_down")
	_check(city.player.position.y <= CanalCityTerrain.WATER_Y - 29.0, "physical player cannot walk into water")
	city.teleport(Vector2(4040, 1420))
	Input.action_press("move_right", 0.707)
	Input.action_press("move_up", 0.707)
	for frame in 100: await physics_frame
	Input.action_release("move_right")
	Input.action_release("move_up")
	_check(city.player.position.y >= 1374.0, "physical player cannot walk into shop")
	city._toggle_enemies()
	_check(_enemy_count(city) == 5, "combat mode has five ordinary enemies")
	for actor in city.actors:
		if actor is TrainingEnemy:
			_check(city.navigation.is_open(actor.global_position, 30.0), "enemy starts outside obstacles")
			_check(city.navigation.find_path(actor.global_position, city.start_point).size() > 2, "enemy can path to entrance")
	city._toggle_enemies()
	await process_frame
	_check(_enemy_count(city) == 0, "scenic toggle clears enemies")
	city.queue_free()
	await process_frame
	print("Canal city trial verification %s (%d failures)" % ["passed" if failures == 0 else "failed", failures])
	quit(1 if failures else 0)


func _enemy_count(city: Node3D) -> int:
	var count := 0
	for actor in city.actors:
		if actor is TrainingEnemy and is_instance_valid(actor) and not actor.is_queued_for_deletion(): count += 1
	return count


func _path_length(path: PackedVector2Array) -> float:
	var length := 0.0
	for i in range(1, path.size()): length += path[i - 1].distance_to(path[i])
	return length


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)
