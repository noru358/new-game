extends SceneTree
## Input/collision and lifecycle contract, not a difficulty or four-minute playtest.
var failures := 0
var reached := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)
func release_movement() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(action)
func walk(scene, goal: Vector2) -> void:
	var path: PackedVector2Array = scene.navigation.find_path(scene.player.position, goal)
	check(not path.is_empty(), "path to %s" % goal)
	for target in path:
		var frames := 0
		while scene.player.position.distance_to(target) > 24 and frames < 400:
			var input: Vector2 = scene.player.position.direction_to(target).rotated(-scene.player.input_rotation)
			release_movement()
			if input.x < -0.2: Input.action_press("move_left", -input.x)
			if input.x > 0.2: Input.action_press("move_right", input.x)
			if input.y < -0.2: Input.action_press("move_up", -input.y)
			if input.y > 0.2: Input.action_press("move_down", input.y)
			await physics_frame
			frames += 1
		check(frames < 400, "input movement reaches %s from %s" % [target, scene.player.position])
		if frames >= 400: break
	release_movement()
	check(scene.player.position.distance_to(goal) < 40, "goal reached %s" % goal)
	reached += 1
func _run() -> void:
	var scene = load("res://game/temple_circuit_run.tscn").instantiate()
	scene.profile_save_prefix = "user://circuit_route_%d" % Time.get_ticks_usec()
	scene.growth_save_prefix = scene.profile_save_prefix + "_unlocks"
	root.add_child(scene)
	current_scene = scene
	for i in 5: await physics_frame
	# Suspend arena scheduling only for input navigation; player collision remains active.
	scene.set_physics_process(false)
	scene.wisp.set_physics_process(false)
	for actor in scene.actors:
		if actor != scene.player: actor.set_physics_process(false)
	Engine.time_scale = 5.0
	var terrain_script = preload("res://game/temple_circuit_trial_terrain.gd")
	for point in terrain_script.MAIN_ROUTE.slice(1): await walk(scene, point)
	# Traverse the alternate branch in reverse without teleporting between branches.
	await walk(scene, terrain_script.THRESHOLD)
	var reverse: Array = terrain_script.WATER_ROUTE.duplicate()
	reverse.reverse()
	for point in reverse.slice(1): await walk(scene, point)
	await walk(scene, Vector2(2800, 900))
	Engine.time_scale = 1.0
	scene.run_time = scene.BOSS_TIME
	scene.temple_section.tick(0.0)
	scene.temple_section.tick(1.3)
	check(scene.boss_spawned and scene.temple_section.boss_active, "candidate destination engages boss")
	if is_instance_valid(scene.boss):
		scene.boss.set_physics_process(false)
		scene.boss.take_hit(10000.0, Vector2.RIGHT, false)
	scene._physics_process(0.0)
	check(scene.run_ended and scene.end_result == "SUCCESS" and not scene.settlement_pending, "boss defeat reaches saved success")
	var saved_currency: int = scene.profile.currency
	var generation: int = scene.profile.generation
	scene._finish_run("SUCCESS")
	check(scene.profile.currency == saved_currency and scene.profile.generation == generation, "duplicate finish awards nothing")
	var restored := RunProfile.new()
	restored.save_prefix = scene.profile_save_prefix
	restored.load_state()
	check(not restored.load_error and restored.currency == saved_currency, "success survives profile reload")
	print("Circuit route completion: ", reached, " input checkpoints; ", failures, " failures. Accelerated navigation + injected boss kill, not human difficulty evidence.")
	paused = false
	scene.queue_free()
	for i in 3: await process_frame
	quit(1 if failures else 0)
