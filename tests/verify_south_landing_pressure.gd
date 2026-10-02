extends SceneTree
## Geometry/pressure contract only: scripted stationary player, companion disabled.
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var scene = load("res://game/jungle_south_circuit.tscn").instantiate()
	scene.profile_save_prefix = "user://south_pressure_%d" % Time.get_ticks_usec()
	scene.growth_save_prefix = scene.profile_save_prefix + "_unlocks"
	root.add_child(scene)
	for i in 4: await physics_frame
	scene.set_physics_process(false)
	scene.wisp.set_physics_process(false)
	var failures := 0
	var samples := []
	var landing_spawn := Vector2.INF
	for point in [Vector2(3010, 2130), Vector2(2080, 2910), Vector2(3540, 2660)]:
		scene.teleport(point)
		for i in 3: await process_frame
		scene.rng.seed = 250
		var valid := 0
		for i in 100:
			var spawn: Vector2 = scene._choose_spawn_point(false)
			if spawn != Vector2.INF:
				valid += 1
				if point == Vector2(3540, 2660) and landing_spawn == Vector2.INF: landing_spawn = spawn
		samples.append({"point": [point.x, point.y], "valid_of_100": valid})
		if valid == 0:
			printerr("FAIL: place has no reachable ambient spawn ", point)
			failures += 1
	if landing_spawn != Vector2.INF:
		var enemy = scene._spawn_enemy_at(landing_spawn, TrainingEnemy.Role.FRAGMENT, 100)
		var starting_health: float = scene.player.health
		Engine.time_scale = 4.0
		var frames := 0
		while scene.player.health >= starting_health and frames < 900:
			await physics_frame
			frames += 1
		Engine.time_scale = 1.0
		if scene.player.health >= starting_health:
			printerr("FAIL: spawned enemy could not physically pressure landing player; enemy=", enemy.position)
			failures += 1
		print("LANDING_PURSUIT ", JSON.stringify({"spawn": [landing_spawn.x, landing_spawn.y], "frames": frames, "damage_received": starting_health - scene.player.health, "accelerated": true}))
	print("SOUTH_SPAWN_SAMPLES ", JSON.stringify(samples))
	print("South landing pressure: ", failures, " failures; not a balance or human difficulty test")
	scene.queue_free()
	paused = false
	for i in 3: await process_frame
	quit(1 if failures else 0)
