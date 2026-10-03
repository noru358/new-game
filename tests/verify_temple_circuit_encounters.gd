extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var scene = load("res://game/temple_circuit_run.tscn").instantiate()
	scene.profile_save_prefix = "user://circuit_encounter_%d" % Time.get_ticks_usec()
	scene.growth_save_prefix = scene.profile_save_prefix + "_unlocks"
	root.add_child(scene)
	current_scene = scene
	for i in 3: await physics_frame
	var failures := 0
	for time in [0.0, 44.0, 50.0, 70.0, 95.0, 140.0, 170.0, 200.0, 230.0]:
		scene.run_time = time
		for p in [Vector2(2450, 2100), Vector2(1450, 1350), Vector2(3400, 2080)]:
			var weights: Array[float] = scene._place_weights(p)
			var total := 0.0
			for value in weights:
				total += value
				if value < 0: failures += 1
			if not is_equal_approx(total, 100.0): failures += 1
			if time < 45 and scene._roll_role() != TrainingEnemy.Role.FRAGMENT: failures += 1
	scene.run_time = 140.0
	var corridor: Array[float] = scene._place_weights(Vector2(1450, 1350))
	var water: Array[float] = scene._place_weights(Vector2(3400, 2080))
	if corridor[1] <= water[1] or water[2] <= corridor[2]: failures += 1
	paused = false
	scene.queue_free()
	for i in 3: await process_frame
	print("Temple place/time encounter composition: ", failures, " failures")
	quit(1 if failures else 0)
