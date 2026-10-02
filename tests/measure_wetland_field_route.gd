extends SceneTree
## Accelerated collision/input check. Not a player-time or enjoyment measurement.
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var scene = load("res://game/deep_wetland_field.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 4: await physics_frame
	for actor in scene.actors:
		if actor != scene.player: actor.set_physics_process(false)
	scene.set_physics_process(false) # Static render/navigation fixture only; no encounter activation.
	scene.wisp.set_physics_process(false)
	Engine.time_scale = 6.0
	var visited := 0
	for route in scene._dry_routes():
		scene.teleport(route[0])
		for goal in route.slice(1):
			var path: PackedVector2Array = scene.navigation.find_path(scene.player.position, goal)
			for target in path:
				var frames := 0
				while scene.player.position.distance_to(target) > 24 and frames < 250:
					var input: Vector2 = scene.player.position.direction_to(target).rotated(-scene.player.input_rotation)
					for action in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(action)
					if input.x < -0.2: Input.action_press("move_left", -input.x)
					if input.x > 0.2: Input.action_press("move_right", input.x)
					if input.y < -0.2: Input.action_press("move_up", -input.y)
					if input.y > 0.2: Input.action_press("move_down", input.y)
					await physics_frame
					frames += 1
				if frames >= 250:
					printerr("FAIL: movement stuck at ", scene.player.position, " toward ", target)
					quit(1)
					return
			visited += 1
			print("REACHED: ", goal)
	for action in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(action)
	Engine.time_scale = 1.0
	print("Accelerated input-route checkpoints: ", visited)
	scene.queue_free()
	for i in 3: await process_frame
	quit()
