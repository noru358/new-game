extends "res://tests/sample_run_baseline.gd"
## Normal-speed grown fixture on the full wetland. Never forces the clock, XP, health or boss.
## Refuses any profile path except the UUID launcher copy's exact user directory.
var samples: Array = []
var ledger := {"combat": 0.0, "travel_without_visible_target": 0.0, "stationary_without_visible_target": 0.0, "destination_wait_without_target": 0.0}
var next_sample := 0
const MARKS := [180.0, 210.0, 240.0, 300.0]
var first_arrival := -1.0
var cap_enabled := false

func _capture() -> Dictionary:
	return {"active_seconds": scene.run_time, "points_earned": scene.growth.points_earned, "points_spent": scene.growth.points_spent, "choice_windows": scene.growth.choice_windows_opened, "moving_slash_enabled": scene.player.moving_slash_enabled, "combo_limit": scene.player.combo_limit(), "cards": scene.growth.selected_card_ranks.duplicate(), "kills": scene.kills, "currency": scene.run_currency, "health": scene.player.health, "position": {"x": scene.player.position.x, "y": scene.player.position.y}, "ledger": ledger.duplicate(), "diagnostics": scene.diagnostics.snapshot(scene)}

func _run() -> void:
	var expected := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--preset="): preset = argument.trim_prefix("--preset=")
		elif argument.begins_with("--seed="): seed_value = int(argument.trim_prefix("--seed="))
		elif argument.begins_with("--seconds="): limit_seconds = float(argument.trim_prefix("--seconds="))
		elif argument.begins_with("--report-path="): report_path = argument.trim_prefix("--report-path=")
		elif argument.begins_with("--expected-user-dir="): expected = argument.trim_prefix("--expected-user-dir=")
	if expected.is_empty() or OS.get_user_data_dir().simplify_path() != expected.simplify_path() or not expected.contains("/LoopConquestFlowSamples/") or not FileAccess.file_exists("user://flow-sample-owner.json"):
		printerr("FAIL: not a launcher-owned isolated profile")
		quit(1); return
	if not preset in ["fresh", "grown"] or limit_seconds <= 0 or limit_seconds > 330:
		quit(1); return
	Engine.time_scale = 1.0
	seed(seed_value)
	var profile_prefix := "user://flow_" + preset + "_profile"
	var unlock_prefix := "user://flow_" + preset + "_unlocks"
	for prefix in [profile_prefix, unlock_prefix]:
		for suffix in ["_a.json", "_b.json"]:
			if FileAccess.file_exists(prefix + suffix):
				printerr("FAIL: fresh fixture required")
				quit(1); return
	if preset == "grown":
		var profile := RunProfile.new()
		profile.save_prefix = profile_prefix
		var unlocks := UnlockProgress.new()
		unlocks.save_prefix = unlock_prefix
		for i in 6: unlocks.add_levelup()
		var prepared := profile.settle("flow-grown-temple", "SUCCESS", 200)
		prepared = profile.settle("flow-grown-jungle", "SUCCESS", 200, RunProfile.JUNGLE_REGION) and prepared
		for id in ["W_FLOW", "A_EMBER"]: prepared = profile.buy_gear(id) and profile.equip(id) and prepared
		for id in ["POWER", "POWER", "WISP", "WISP", "VITALITY"]: prepared = profile.buy_growth(id, 6) and prepared
		prepared = profile.buy_attack_branch("DIRECT") and prepared
		investment = 500 - profile.currency
		if not prepared: printerr("FAIL: grown fixture failed"); quit(1); return
	scene = load("res://game/deep_wetland_run.tscn").instantiate()
	scene.profile_save_prefix = profile_prefix
	scene.growth_save_prefix = unlock_prefix
	scene.diagnostics_enabled = true
	root.add_child(scene)
	await process_frame
	scene.rng.seed = seed_value
	scene.growth.rng.seed = seed_value + 1
	scene.growth.late_xp_slope_trial = true
	scene.growth._update_hud()
	cap_enabled = scene.growth.slash_chain_cap_trial_enabled
	previous_position = scene.player.position
	var previous_time: float = scene.run_time
	var started := Time.get_ticks_usec()
	var reason := "active_window_complete"
	while scene.run_time < limit_seconds:
		await physics_frame
		var now := Time.get_ticks_usec()
		var dt: float = scene.run_time - previous_time
		previous_time = scene.run_time
		var moved: float = previous_position.distance_to(scene.player.position)
		previous_position = scene.player.position
		var in_destination: bool = scene.temple_section.boss_area.has_point(scene.player.position) and not scene.temple_section.in_garden
		if in_destination and first_arrival < 0: first_arrival = scene.run_time
		var visible_target := false
		for enemy in get_nodes_in_group("training_enemies"):
			if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and enemy.health > 0 and enemy.position.distance_to(scene.player.position) <= 380 and scene.clear_attack(scene.player.position, enemy.position): visible_target = true; break
		var key := "combat" if visible_target else "destination_wait_without_target" if in_destination and not scene.boss_spawned else "travel_without_visible_target" if moved > 0.01 else "stationary_without_visible_target"
		ledger[key] += dt
		if next_sample < MARKS.size() and scene.run_time >= MARKS[next_sample]:
			samples.append(_capture()); next_sample += 1
		if scene.run_ended: reason = scene.end_result; break
		if scene.temple_section.retry_pending: reason = "boss_death_retry_available"; break
		if float(now - started) / 1000000.0 > limit_seconds + 180: reason = "wall_time_guard"; break
		if scene.growth.choosing:
			_release()
			if choice_started < 0: choice_started = now
			if now - choice_started >= 1500000:
				_choose_card(); choice_started = now if scene.growth.choosing else -1
			continue
		choice_started = -1
		if scene.paused: continue
		if scene.run_time >= next_control: _drive(); next_control = scene.run_time + 0.1
	_release()
	var report := {"sample": "wetland_full_run_v45_late_xp_trial", "human_playtest": false, "late_xp_slope_trial": true, "preset": preset, "seed": seed_value, "slash_chain_cap_trial": cap_enabled, "source_boss_time": scene.BOSS_TIME, "investment": investment, "samples": samples, "final": _capture(), "first_destination_arrival": first_arrival, "stop_reason": reason, "time_scale": Engine.time_scale, "notes": "Wetland70s route, inherited combat/card priority and1.5s synthetic choice dwell. No forced XP, damage, health, boss or clock writes. Combat means reachable visible target within380; it can include travel. No-target movement is a proxy, not proof of meaningless travel. Repeated fighting cannot be identified from this aggregate.210 proposal is superseded; marks180/210/240/300 remain observation only. Missing marks mean the controller died/stopped before them."}
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null: quit(1); return
	file.store_string(JSON.stringify(report, "  ") + "\n")
	print("FLOW_SAMPLE ", JSON.stringify(report))
	paused = false
	scene.queue_free()
	await process_frame
	quit()

const WETLAND_ROUTE := [Vector2(1350,2140),Vector2(2350,1510),Vector2(3260,830),Vector2(4770,1480)]
func _drive() -> void:
	_action("dash", 0.0)
	_action("moving_slash", 0.0)
	var position: Vector2 = scene.player.global_position
	var nearest: Node2D
	var distance := 700.0
	for enemy in get_nodes_in_group("training_enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.health <= 0.0: continue
		var candidate: float = position.distance_to(enemy.global_position)
		if candidate < distance and scene.clear_attack(position, enemy.global_position):
			nearest = enemy
			distance = candidate
	var goal: Vector2 = WETLAND_ROUTE[mini(3, floori(scene.run_time / 70.0))]
	if nearest != null and (distance < 380.0 or scene.temple_section.boss_active):
		var toward := position.direction_to(nearest.global_position)
		goal = nearest.global_position - toward * 75.0
		if distance < 55.0: goal = position - toward * 95.0
	var direction := Vector2.ZERO
	if position.distance_to(goal) > 18.0:
		var path: PackedVector2Array = scene.navigation.find_path(position, goal)
		if path.size() >= 2:
			var next := 1
			while next < path.size() - 1 and position.distance_to(path[next]) < 24.0: next += 1
			direction = position.direction_to(path[next])
	var input_direction: Vector2 = direction.rotated(-scene.player.input_rotation)
	_action("move_left", maxf(0.0, -input_direction.x))
	_action("move_right", maxf(0.0, input_direction.x))
	_action("move_up", maxf(0.0, -input_direction.y))
	_action("move_down", maxf(0.0, input_direction.y))
	_action("attack", 1.0 if nearest != null and distance < 190.0 else 0.0)
	if nearest != null and distance < 150.0 and scene.run_time >= next_slash:
		_action("moving_slash", 1.0)
		next_slash = scene.run_time + 1.3
	if nearest != null and distance < 70.0 and scene.run_time >= next_dash:
		_action("dash", 1.0)
		next_dash = scene.run_time + 1.8


