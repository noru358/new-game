extends SceneTree
## Manual diagnostic sample, deliberately excluded from verify_*.gd CI runs.
## Real input actions at normal speed; this controller is not a human playtest.
## godot --headless --path . --script res://tests/sample_run_baseline.gd -- --preset=fresh --seconds=330 --seed=250
## Repeat with --preset=grown; optionally supply --report-path=/absolute/output.json.

const ROUTE := [Vector2(660, 1120), Vector2(1950, 900), Vector2(3410, 900), Vector2(4750, 1100)]
const PRIORITY := ["U_EDGE", "U_TEMPO", "S_WISP_COUNT", "S_WISP_DAMAGE", "U_REACH", "S_WISP_CADENCE", "S_WISP_FOLLOWUP", "U_SLASH_SWEEP", "U_SLASH_CADENCE", "S_WISP_SWEEP", "S_WISP_REPLY"]
const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "attack", "dash", "moving_slash"]
var preset := "fresh"
var seed_value := 250
var limit_seconds := 330.0
var report_path := ""
var held: Dictionary = {}
var scene
var choice_started := -1
var next_control := 0.0
var next_dash := 0.0
var next_slash := 0.0
var actions_sent := 0
var distance_walked := 0.0
var previous_position := Vector2.ZERO
var investment := 0


func _initialize() -> void: call_deferred("_run")


func _action(action: String, strength: float) -> void:
	strength = clampf(strength, 0.0, 1.0)
	if is_equal_approx(float(held.get(action, 0.0)), strength): return
	held[action] = strength
	var event := InputEventAction.new()
	event.action = action
	event.pressed = strength > 0.0
	event.strength = strength
	Input.parse_input_event(event)
	actions_sent += 1


func _release() -> void:
	for action in ACTIONS: _action(action, 0.0)


func _choose_card() -> void:
	var index := 0
	for id in PRIORITY:
		if scene.growth.current_choices.has(id):
			index = scene.growth.current_choices.find(id)
			break
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_1 + index
		event.pressed = pressed
		root.push_input(event, true)
		actions_sent += 1


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
	var goal: Vector2 = ROUTE[mini(3, floori(scene.run_time / 70.0))]
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


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--preset="): preset = argument.trim_prefix("--preset=")
		elif argument.begins_with("--seed="): seed_value = int(argument.trim_prefix("--seed="))
		elif argument.begins_with("--seconds="): limit_seconds = float(argument.trim_prefix("--seconds="))
		elif argument.begins_with("--report-path="): report_path = argument.trim_prefix("--report-path=")
	if not preset in ["fresh", "grown"] or limit_seconds <= 0.0:
		printerr("Use --preset=fresh|grown and a positive --seconds value")
		quit(1)
		return
	Engine.time_scale = 1.0
	seed(seed_value)
	# Fixed fixture-only names cannot resolve to the real campaign profile.
	var profile_prefix := "user://sample_run_baseline_" + preset + "_profile"
	var unlock_prefix := "user://sample_run_baseline_" + preset + "_unlocks"
	for prefix in [profile_prefix, unlock_prefix]:
		for suffix in ["_a.json", "_b.json"]:
			var path := ProjectSettings.globalize_path(prefix + suffix)
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	if preset == "grown":
		var profile := RunProfile.new()
		profile.save_prefix = profile_prefix
		var unlocks := UnlockProgress.new()
		unlocks.save_prefix = unlock_prefix
		for i in 6: unlocks.add_levelup()
		# 200 prior earnings + the existing first-clear 50 bonus fund this fixture.
		var prepared := profile.settle("synthetic-baseline-fixture", "SUCCESS", 200)
		for id in ["W_FLOW", "A_EMBER"]: prepared = profile.buy_gear(id) and profile.equip(id) and prepared
		for id in ["POWER", "POWER", "WISP", "WISP", "VITALITY"]: prepared = profile.buy_growth(id, 6) and prepared
		prepared = profile.buy_attack_branch("DIRECT") and prepared
		investment = 250 - profile.currency
		if not prepared:
			printerr("Could not prepare the isolated grown fixture")
			quit(1)
			return
	scene = load("res://game/hybrid_region.tscn").instantiate()
	scene.profile_save_prefix = profile_prefix
	scene.growth_save_prefix = unlock_prefix
	scene.diagnostics_enabled = true
	root.add_child(scene)
	await process_frame
	scene.rng.seed = seed_value
	scene.growth.rng.seed = seed_value + 1
	previous_position = scene.player.global_position
	var started := Time.get_ticks_usec()
	var reason := "active_window_complete"
	while scene.run_time < limit_seconds:
		await physics_frame
		var now := Time.get_ticks_usec()
		distance_walked += previous_position.distance_to(scene.player.global_position)
		previous_position = scene.player.global_position
		if scene.run_ended:
			reason = scene.end_result
			break
		if scene.temple_section.retry_pending:
			reason = "boss_death_retry_available"
			break
		if float(now - started) / 1000000.0 > limit_seconds + 180.0:
			reason = "wall_time_guard"
			break
		if scene.growth.choosing:
			_release()
			if choice_started < 0: choice_started = now
			if now - choice_started >= 1500000:
				_choose_card()
				choice_started = now if scene.growth.choosing else -1
			continue
		choice_started = -1
		if scene.paused: continue
		if scene.run_time >= next_control:
			_drive()
			next_control = scene.run_time + 0.10
	_release()
	var report := {
		"sample": "synthetic_input_controller_v1", "human_playtest": false,
		"preset": preset, "seed": seed_value, "permanent_investment": investment,
		"active_window_limit": limit_seconds, "stop_reason": reason,
		"choice_dwell_seconds": 1.5, "controller_hz": 10,
		"controller": "fixed route every 70s; pursue visible nearby enemies; hold basic attack; periodic close-range slash/dash; fixed card priority; first life only",
		"input_events": actions_sent, "distance_travelled": distance_walked,
		"diagnostics": scene.diagnostics.snapshot(scene),
	}
	var encoded := JSON.stringify(report, "  ")
	print("RUN_BASELINE ", JSON.stringify(report))
	if not report_path.is_empty():
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file == null:
			printerr("Could not write requested report path")
			quit(1)
			return
		file.store_string(encoded + "\n")
	paused = false
	scene.queue_free()
	await process_frame
	quit(0)
