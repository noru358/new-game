extends SceneTree
## Normal-speed navigation-input travel sample. Not combat, fun or human exploration time.
var reports := []
var failed := false
func _initialize() -> void: call_deferred("_run")
func release_actions() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(action)
func _run() -> void:
	for candidate in [false, true]:
		var scene = load("res://game/jungle_south_circuit.tscn" if candidate else "res://game/jungle_pass.tscn").instantiate()
		scene.profile_save_prefix = "user://south_route_measure_%d" % Time.get_ticks_usec()
		scene.growth_save_prefix = scene.profile_save_prefix + "_unlocks"
		var profile := RunProfile.new()
		profile.save_prefix = scene.profile_save_prefix
		profile.settle("isolated-measurement-access", "SUCCESS", 0, RunProfile.TEMPLE_REGION)
		root.add_child(scene)
		for i in 4: await physics_frame
		scene.set_physics_process(false)
		scene.wisp.set_physics_process(false)
		for actor in scene.actors:
			if actor != scene.player: actor.set_physics_process(false)
		var route: Array = preload("res://game/jungle_south_circuit_terrain.gd").SOUTH_ROUTE if candidate else [Vector2(3010, 2130), Vector2(1250, 2050)]
		scene.teleport(route[0])
		Engine.time_scale = 1.0
		var started := Time.get_ticks_usec()
		var frames := 0
		var distance := 0.0
		var checkpoints := []
		for goal in route.slice(1):
			var path: PackedVector2Array = scene.navigation.find_path(scene.player.position, goal)
			if path.is_empty():
				printerr("FAIL: missing south route path ", goal)
				failed = true
				break
			for target in path:
				var budget := 0
				while scene.player.position.distance_to(target) > 22 and budget < 400:
					var before: Vector2 = scene.player.position
					var direction: Vector2 = before.direction_to(target).rotated(-scene.player.input_rotation)
					release_actions()
					if direction.x < -0.2: Input.action_press("move_left", -direction.x)
					if direction.x > 0.2: Input.action_press("move_right", direction.x)
					if direction.y < -0.2: Input.action_press("move_up", -direction.y)
					if direction.y > 0.2: Input.action_press("move_down", direction.y)
					await physics_frame
					distance += before.distance_to(scene.player.position)
					frames += 1
					budget += 1
				if budget >= 400:
					printerr("FAIL: south movement stuck ", scene.player.position, " toward ", target)
					failed = true
					break
			if failed: break
			checkpoints.append({"goal": [goal.x, goal.y], "position": [scene.player.position.x, scene.player.position.y], "nominal_physics_seconds": frames / 60.0})
		release_actions()
		reports.append({"candidate": candidate, "time_scale": Engine.time_scale, "combat_disabled": true, "human_playtest": false, "distance": distance, "nominal_physics_seconds": frames / 60.0, "wall_seconds": (Time.get_ticks_usec() - started) / 1000000.0, "checkpoints": checkpoints, "failed": failed})
		scene.queue_free()
		for i in 3: await process_frame
		if failed: break
	var file := FileAccess.open("/tmp/v44-jungle-south-travel.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(reports, "\t"))
	file.close()
	print("SOUTH_ROUTE_TRAVEL ", JSON.stringify(reports))
	quit(1 if failed else 0)
