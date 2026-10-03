extends "res://tests/sample_run_baseline.gd"
## A normal-speed fresh camp departure using the existing v25 input controller.
## No spawned-enemy injection, clock jump, stat boost, or disabled simulation.
## Optional --report-path=/absolute/report.json and ENEMY_ROLE_LIVE_CAPTURE_DIR.

var isolated_profile := ""
var isolated_unlocks := ""
var observations: Dictionary = {}
var capture_pending: Array[String] = []
var live_capture_dir := ""
var seen_enemy_ids: Dictionary = {}
var opening_nonfragment := false

func _isolate_region(node: Node) -> void:
	if node.get_script() == load("res://game/hybrid_region.gd"):
		node.profile_save_prefix = isolated_profile
		node.growth_save_prefix = isolated_unlocks

func _run() -> void:
	seed_value = 3901
	limit_seconds = 75.0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report-path="): report_path = argument.trim_prefix("--report-path=")
	live_capture_dir = OS.get_environment("ENEMY_ROLE_LIVE_CAPTURE_DIR")
	if not live_capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(live_capture_dir)
	Engine.time_scale = 1.0
	seed(seed_value)
	isolated_profile = "user://sample_enemy_roles_profile_" + str(Time.get_ticks_usec())
	isolated_unlocks = "user://sample_enemy_roles_unlocks_" + str(Time.get_ticks_usec())
	node_added.connect(_isolate_region)
	var camp = load("res://game/travel_camp.tscn").instantiate()
	camp.profile_save_prefix = isolated_profile
	camp.growth_save_prefix = isolated_unlocks
	root.add_child(camp)
	current_scene = camp
	await process_frame
	# Invoke the same ordinary departure action as the camp's existing button.
	camp.preparation._depart()
	while current_scene == camp or current_scene == null: await process_frame
	scene = current_scene
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
		_observe()
		if scene.run_ended:
			reason = scene.end_result
			break
		if float(now - started) / 1000000.0 > limit_seconds + 90.0:
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
		if not live_capture_dir.is_empty() and not capture_pending.is_empty():
			var label: String = capture_pending.pop_front()
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			if image != null and not image.is_empty(): image.save_png(live_capture_dir.path_join(label + ".png"))
		if scene.run_time >= 60.0 and observations.has("beast_charge") and observations.has("beast_hit"):
			reason = "first_beast_encounter_observed"
			break
	_release()
	var valid: bool = observations.get("fragment_visible", 999.0) <= 30.0 and observations.get("beast_spawn", 0.0) >= 45.0 and observations.has("beast_warning") and observations.has("beast_charge") and observations.has("fragment_hit") and not opening_nonfragment
	var report := {
		"sample": "fresh_ordinary_enemy_encounter", "human_playtest": false,
		"frozen_pose": false, "camp_departure": true, "time_scale": Engine.time_scale,
		"seed": seed_value, "active_seconds": scene.run_time,
		"wall_seconds": float(Time.get_ticks_usec() - started) / 1000000.0,
		"input_controller": "existing sample_run_baseline controller and real card-choice input",
		"input_events": actions_sent, "distance_travelled": distance_walked,
		"observations": observations, "opening_nonfragment": opening_nonfragment,
		"stop_reason": reason, "checks_passed": valid, "player_health": scene.player.health,
		"profile_prefix": isolated_profile, "unlocks_prefix": isolated_unlocks,
	}
	print("ENEMY_ROLE_ENCOUNTER ", JSON.stringify(report))
	if not report_path.is_empty():
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file == null:
			printerr("Cannot write encounter report")
			quit(1)
			return
		file.store_string(JSON.stringify(report, "  ") + "\n")
	paused = false
	scene.queue_free()
	await process_frame
	quit(0 if valid else 1)

func _observe() -> void:
	for enemy in get_nodes_in_group("training_enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or not scene.actors.has(enemy): continue
		var id: int = enemy.get_instance_id()
		var role: String = "fragment" if enemy.role == TrainingEnemy.Role.FRAGMENT else "beast" if enemy.role == TrainingEnemy.Role.BEAST else "other"
		if not seen_enemy_ids.has(id):
			seen_enemy_ids[id] = true
			if scene.run_time < 45.0 and enemy.role != TrainingEnemy.Role.FRAGMENT: opening_nonfragment = true
			_mark(role + "_spawn")
		if not scene._on_screen(enemy): continue
		var body: Sprite3D = scene.actors[enemy].get_node("Body")
		if role in ["fragment", "beast"] and body.has_meta("enemy_role_body"):
			_mark(role + "_visible")
			if enemy.hit_flash > 0.0: _mark(role + "_hit")
			if enemy.warning_time > 0.0: _mark(role + "_warning")
			if enemy.charge_time > 0.0: _mark(role + "_charge")

func _mark(label: String) -> void:
	if observations.has(label): return
	observations[label] = scene.run_time
	print("OBSERVED ", label, " at ", snappedf(scene.run_time, 0.001))
	if label.ends_with("_visible") or label.ends_with("_warning") or label.ends_with("_charge") or label.ends_with("_hit"):
		capture_pending.append(label)
