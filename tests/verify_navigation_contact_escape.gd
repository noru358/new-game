extends SceneTree
func _initialize() -> void: call_deferred("_run")
func release_actions() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(action)
func _run() -> void:
	var scene = load("res://game/hybrid_region.tscn").instantiate()
	scene.profile_save_prefix = "user://navigation_escape_%d" % Time.get_ticks_usec()
	scene.growth_save_prefix = scene.profile_save_prefix + "_unlocks"
	root.add_child(scene)
	for i in 4: await physics_frame
	scene.set_physics_process(false)
	scene.wisp.set_physics_process(false)
	# A physically legal point between the southern ramps previously had no grid attachment.
	scene.teleport(Vector2(800, 1632))
	var goal := Vector2(650, 1870)
	var path: PackedVector2Array = scene.navigation.find_path(scene.player.position, goal)
	var failures := 0
	if path.size() < 2:
		printerr("FAIL: sampled real-terrain contact point has no outward route")
		failures += 1
	Engine.time_scale = 4.0
	for target in path:
		var frames := 0
		while scene.player.position.distance_to(target) > 22 and frames < 300:
			var direction: Vector2 = scene.player.position.direction_to(target).rotated(-scene.player.input_rotation)
			release_actions()
			if direction.x < -0.2: Input.action_press("move_left", -direction.x)
			if direction.x > 0.2: Input.action_press("move_right", direction.x)
			if direction.y < -0.2: Input.action_press("move_up", -direction.y)
			if direction.y > 0.2: Input.action_press("move_down", direction.y)
			await physics_frame
			frames += 1
		if frames >= 300:
			printerr("FAIL: physical movement stalled at ", scene.player.position, " toward ", target)
			failures += 1
			break
	release_actions()
	Engine.time_scale = 1.0
	if scene.player.position.distance_to(goal) > 40: failures += 1
	print("Actual temple contact escape: ", failures, " failures; navigation-driven input only, no wall teleport")
	scene.queue_free()
	for i in 3: await process_frame
	quit(1 if failures else 0)
