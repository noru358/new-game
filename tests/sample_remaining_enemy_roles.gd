extends "res://tests/sample_run_baseline.gd"
## Normal-speed input sample of the existing combat simulation in either region.
## Initial fixture injects the five existing roles near the start and suppresses
## later ambient spawns. No attack, AI, health, camera, or growth rules change.
## This is a presentation observation fixture, not a natural run or balance test.
## --jungle --compact --report-path=/absolute/report.json; ENEMY_ROLE_LIVE_CAPTURE_DIR

const ROLE_NAMES := ["fragment", "beast", "lamp", "zone", "support"]
var captured: Dictionary = {}
var seen: Dictionary = {}
var live_dir := ""
var failures := 0
var enemies: Array[TrainingEnemy] = []
var normal_saves: Dictionary = {}

func _save_bytes() -> Dictionary:
	var result: Dictionary = {}
	for prefix in ["user://loop_conquest_profile", "user://loop_conquest_1d_unlocks"]:
		for suffix in ["_a.json", "_b.json"]:
			var path: String = prefix + suffix
			result[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	return result

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var jungle := args.has("--jungle")
	var compact := args.has("--compact")
	var label := ("jungle" if jungle else "temple") + ("-960" if compact else "-1280")
	for argument in args:
		if argument.begins_with("--report-path="): report_path = argument.trim_prefix("--report-path=")
	live_dir = OS.get_environment("ENEMY_ROLE_LIVE_CAPTURE_DIR")
	if not live_dir.is_empty(): DirAccess.make_dir_recursive_absolute(live_dir)
	normal_saves = _save_bytes()
	root.size = Vector2i(960, 540) if compact else Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	Engine.time_scale = 1.0
	seed(4110)
	scene = load("res://game/jungle_pass.tscn" if jungle else "res://game/hybrid_region.tscn").instantiate()
	scene.profile_save_prefix = "user://remaining_role_sample_profile_" + label + str(Time.get_ticks_usec())
	scene.growth_save_prefix = "user://remaining_role_sample_unlocks_" + label + str(Time.get_ticks_usec())
	root.add_child(scene)
	current_scene = scene
	for i in 3: await process_frame
	scene.rng.seed = 4110
	scene.growth.rng.seed = 4111
	scene.spawn_credit = -1000.0
	var offsets := [Vector2(-90, 0), Vector2(120, 40), Vector2(-60, 160), Vector2(150, 150), Vector2(40, 220)]
	for role in 5:
		var enemy: TrainingEnemy = scene._spawn_enemy_at(scene.start_point + offsets[role], role, TrainingEnemy.Definitions.ROLES[role].health)
		enemies.append(enemy)
	previous_position = scene.player.global_position
	var started := Time.get_ticks_usec()
	while scene.run_time < 10.0 and not scene.run_ended:
		await physics_frame
		if float(Time.get_ticks_usec() - started) / 1000000.0 > 50.0:
			failures += 1
			break
		distance_walked += previous_position.distance_to(scene.player.global_position)
		previous_position = scene.player.global_position
		for enemy in enemies:
			if not is_instance_valid(enemy) or enemy.is_queued_for_deletion(): continue
			var role_name: String = ROLE_NAMES[enemy.role]
			if scene._on_screen(enemy): _mark(role_name + "_visible")
			if enemy.velocity.length_squared() > 25.0: _mark(role_name + "_moving")
			if enemy.hit_flash > 0.0:
				_mark(role_name + "_hit")
				await _capture_once(label, "impact")
			if not is_instance_valid(enemy) or enemy.is_queued_for_deletion(): continue
			if enemy.role == TrainingEnemy.Role.LAMP and enemy.warning_time > 0.0:
				_mark("lamp_warning")
				await _capture_once(label, "warning")
			if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and enemy.support_boost: _mark("support_boost")
		if not get_nodes_in_group("enemy_bolts").is_empty():
			_mark("lamp_bolt")
			await _capture_once(label, "projectile")
		for zone in get_nodes_in_group("enemy_zones"):
			if not is_instance_valid(zone): continue
			_mark("zone_active" if zone.warning_time <= 0.0 else "zone_warning")
		if scene.run_time >= 1.5: await _capture_once(label, "combat")
		if scene.growth.choosing:
			_release()
			_choose_card()
			continue
		if scene.paused: continue
		# Let the native lamp/zone attacks begin, then use the existing controller.
		if scene.run_time >= 1.0 and scene.run_time >= next_control:
			_drive()
			next_control = scene.run_time + 0.10
	_release()
	for required in ["lamp_visible", "zone_visible", "support_visible", "lamp_warning", "lamp_bolt", "zone_warning", "zone_active", "support_boost"]:
		if not seen.has(required):
			printerr("FAIL: live sample missing ", required)
			failures += 1
	if _save_bytes() != normal_saves:
		printerr("FAIL: ordinary save bytes changed")
		failures += 1
	var report := {
		"fixture": "five_existing_roles_in_real_region_combat", "human_playtest": false,
		"natural_run": false, "frozen_pose": false, "time_scale": Engine.time_scale,
		"region": label, "initial_existing_role_injection": true, "ambient_spawns_suppressed": true,
		"combat_stats_unchanged": true, "normal_save_bytes_preserved": _save_bytes() == normal_saves,
		"active_seconds": scene.run_time, "wall_seconds": float(Time.get_ticks_usec() - started) / 1000000.0,
		"input_events": actions_sent, "distance_travelled": distance_walked,
		"observations": seen, "captures": captured.keys(), "failures": failures,
	}
	print("REMAINING_ROLE_SAMPLE ", JSON.stringify(report))
	if not report_path.is_empty():
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report, "  ") + "\n")
		else: failures += 1
	paused = false
	scene.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)

func _mark(key: String) -> void:
	if not seen.has(key): seen[key] = scene.run_time

func _capture_once(label: String, state: String) -> void:
	if live_dir.is_empty() or captured.has(state): return
	captured[state] = scene.run_time
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(live_dir.path_join(label + "-" + state + ".png")) != OK:
		failures += 1
