extends SceneTree
## Deterministic accelerated bot comparison. Not human difficulty or timing evidence.
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var reports := []
	for trial in [false, true]:
		var scene = load("res://game/temple_circuit_run.tscn").instantiate()
		var prefix := "user://pacing_bot_%d_%s" % [Time.get_ticks_usec(), str(trial)]
		scene.profile_save_prefix = prefix
		scene.growth_save_prefix = prefix + "_unlocks"
		var seed_profile := RunProfile.new()
		seed_profile.save_prefix = prefix
		seed_profile.settle("synthetic-setup", "SUCCESS", 2000)
		for id in ["VITALITY", "GUARD", "POWER", "SLASH_POWER"]:
			for i in 3: seed_profile.buy_growth(id)
		seed_profile.buy_gear("W_FLOW")
		seed_profile.equip("W_FLOW")
		var unlocks := UnlockProgress.new()
		unlocks.save_prefix = scene.growth_save_prefix
		for i in 6: unlocks.add_levelup()
		root.add_child(scene)
		current_scene = scene
		for i in 4: await physics_frame
		scene.rng.seed = 741
		scene.growth.rng.seed = 741
		scene.growth.late_xp_slope_trial = trial
		Engine.time_scale = 5.0
		var goals := [Vector2(2450, 2100), Vector2(1450, 1350), Vector2(2650, 1100), Vector2(3350, 1190), Vector2(3400, 2080), Vector2(2450, 2100)]
		var goal_index := 0
		var path := PackedVector2Array()
		var path_index := 0
		var frames := 0
		while scene.run_time < 240 and not scene.run_ended and frames < 24000:
			if scene.growth.choosing:
				# Same preference list, only choosing among the cards actually offered.
				var index := 0
				for wanted in ["U_EDGE", "S_WISP_COUNT", "U_TEMPO", "U_SLASH_CADENCE", "S_WISP_DAMAGE"]:
					if wanted in scene.growth.current_choices:
						index = scene.growth.current_choices.find(wanted)
						break
				scene.growth.choose_index(index)
			elif not paused:
				if scene.player.position.distance_to(goals[goal_index]) < 80:
					goal_index = (goal_index + 1) % goals.size()
					path = PackedVector2Array()
				if path.is_empty() or frames % 60 == 0:
					path = scene.navigation.find_path(scene.player.position, goals[goal_index])
					path_index = mini(1, path.size() - 1)
				if path_index >= 0 and path_index < path.size():
					while path_index < path.size() - 1 and scene.player.position.distance_to(path[path_index]) < 35: path_index += 1
					var input: Vector2 = scene.player.position.direction_to(path[path_index]).rotated(-scene.player.input_rotation)
					for a in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(a)
					if input.x < -0.2: Input.action_press("move_left", -input.x)
					if input.x > 0.2: Input.action_press("move_right", input.x)
					if input.y < -0.2: Input.action_press("move_up", -input.y)
					if input.y > 0.2: Input.action_press("move_down", input.y)
				Input.action_press("attack")
				Input.action_press("moving_slash") if frames % 120 == 0 else Input.action_release("moving_slash")
			await physics_frame
			frames += 1
		reports.append({"late_curve": trial, "simulated_seconds": scene.run_time, "ended": scene.end_result, "health": scene.player.health, "choices": scene.growth.points_spent, "kills": scene.kills, "unsettled_currency": scene.run_currency, "position": str(scene.player.position), "frames": frames})
		for a in ["move_left", "move_right", "move_up", "move_down", "attack", "moving_slash"]: Input.action_release(a)
		paused = false
		Engine.time_scale = 1.0
		scene.queue_free()
		for i in 5: await process_frame
	print("PACING_COMPARISON ", JSON.stringify(reports))
	quit()
