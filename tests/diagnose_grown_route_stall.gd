extends "res://tests/sample_run_baseline.gd"
## Diagnostic only: synthetic third-run gear/unlocks; no human balance claim.
func _run() -> void:
	seed(250)
	var prefix := "user://grown_route_diagnosis_%d" % Time.get_ticks_usec()
	var profile := RunProfile.new()
	profile.save_prefix = prefix
	profile.settle("fixture-clear", "SUCCESS", 2000)
	profile.buy_growth("VITALITY")
	profile.buy_gear("W_FLOW")
	profile.equip("W_FLOW")
	profile.buy_gear("A_EMBER")
	profile.equip("A_EMBER")
	var unlocks := UnlockProgress.new()
	unlocks.save_prefix = prefix + "_unlocks"
	for i in 55: unlocks.add_levelup()
	scene = load("res://game/hybrid_region.tscn").instantiate()
	scene.profile_save_prefix = prefix
	scene.growth_save_prefix = unlocks.save_prefix
	root.add_child(scene)
	current_scene = scene
	for i in 4: await physics_frame
	scene.rng.seed = 250
	scene.growth.rng.seed = 251
	var next_report := 0.0
	var observations := []
	while scene.run_time < 120 and not scene.run_ended:
		await process_frame
		if scene.growth.choosing:
			_release()
			if choice_started < 0: choice_started = Time.get_ticks_usec()
			if Time.get_ticks_usec() - choice_started > 1500000:
				_choose_card()
				choice_started = -1
			continue
		if scene.run_time >= next_control:
			_drive()
			next_control = scene.run_time + 0.1
		if scene.run_time >= next_report:
			var goal: Vector2 = ROUTE[mini(3, floori(scene.run_time / 70))]
			var entry := {"active": scene.run_time, "position": [scene.player.position.x, scene.player.position.y], "open": scene.navigation.is_open(scene.player.position, scene.ACTOR_CLEARANCE), "goal_path_size": scene.navigation.find_path(scene.player.position, goal).size(), "kills": scene.kills, "actors": scene._active_enemy_count(), "in_garden": scene.temple_section.in_garden, "spawn_credit": scene.spawn_credit, "pending_spawns": scene.pending_spawns.size(), "health": scene.player.health, "actions": held.duplicate()}
			observations.append(entry)
			print("GROWN_ROUTE ", JSON.stringify(entry))
			next_report = scene.run_time + 5.0
	_release()
	if not scene.run_ended: scene._finish_run("RETREAT")
	var file := FileAccess.open("/tmp/v44-grown-route-diagnosis.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"synthetic_setup": true, "human_playtest": false, "observations": observations}, "\t"))
	file.close()
	paused = false
	scene.queue_free()
	for i in 3: await process_frame
	quit()
