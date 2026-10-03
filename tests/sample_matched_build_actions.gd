extends "res://tests/sample_build_actions.gd"
## Three bounded scripted episodes with the same 294 investment and nine
## offered triples. Synthetic XP/offers/targets/time, never a natural run.
const OFFERS := [
	["U_TEMPO", "U_SLASH_CADENCE", "S_WISP_COUNT"],
	["U_REACH", "U_SLASH_SWEEP", "S_WISP_CADENCE"],
	["U_EDGE", "S_WISP_REPLY", "S_WISP_DAMAGE"],
	["U_TEMPO", "U_SLASH_CADENCE", "S_WISP_COUNT"],
	["U_REACH", "U_SLASH_SWEEP", "S_WISP_CADENCE"],
	["U_EDGE", "S_WISP_REPLY", "S_WISP_DAMAGE"],
	["U_TEMPO", "S_WISP_FOLLOWUP", "S_WISP_CHAIN"],
	["U_REACH", "S_WISP_SWEEP", "S_WISP_CADENCE"],
	["U_EDGE", "S_WISP_FOLLOWUP", "S_WISP_DAMAGE"],
]
var episode_frames := 0
var trace: Array = []

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--build="): build = argument.trim_prefix("--build=")
		elif argument.begins_with("--report-path="): report_path = argument.trim_prefix("--report-path=")
	if not BUILD_PRIORITIES.has(build) or not _isolated() or not _prepare_fixture():
		printerr("FAIL: matched episode requires a legal build and fresh private fixture")
		quit(1)
		return
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	scene = load("res://game/hybrid_region.tscn").instantiate()
	scene.diagnostics_enabled = true
	root.add_child(scene)
	await process_frame
	# Disable regional clock/spawner only; player/enemy/wisp physics remain live.
	scene.set_physics_process(false)
	scene.temple_section.set_physics_process(false)
	for enemy in get_nodes_in_group("training_enemies"): enemy.queue_free()
	await process_frame
	scene.player.attack_landed.connect(_on_basic_hit)
	scene.player.moving_slash_landed.connect(_on_slash_hit)
	_sync_wisp_observers()
	_checkpoint("initial")
	for offered in OFFERS:
		scene.growth.gain_xp(scene.growth.next_xp() - scene.growth.xp)
		scene.growth.current_choices.assign(offered)
		for id in offered:
			if int(scene.growth.card_ranks.get(id, 0)) >= scene.growth.card_max_rank(id): fatal_error = "offered card exceeds live cap"
		_choose_card()
	if not fatal_error.is_empty():
		printerr("FAIL: ", fatal_error)
		quit(1)
		return
	# Card confirmation intentionally requires an attack release. Give the
	# live player two physics frames to observe that release before the episode.
	_release()
	await physics_frame
	await physics_frame
	if scene.player.attack_blocked_until_release:
		printerr("FAIL: episode started before the modal attack-release guard cleared")
		quit(1)
		return
	scene.teleport(Vector2(2500, 1050))
	for point in [Vector2(2600, 1050), Vector2(2620, 1080), Vector2(2485, 1115)]:
		var enemy: TrainingEnemy = load("res://game/enemy.tscn").instantiate()
		enemy.max_health = 160.0
		enemy.position = point
		enemy.target = scene.player
		enemy.arena_bounds = scene.player.arena_bounds
		scene.simulation.add_child(enemy)
	scene.player.facing = Vector2.RIGHT
	previous_position = scene.player.position
	if build == "gather":
		_action("attack", 1.0)
		await _episode(132)
	elif build == "movement":
		_action("moving_slash", 1.0)
		await _episode(1)
		_action("moving_slash", 0.0)
		await _episode(14)
		_action("attack", 1.0)
		await _episode(1)
		_action("attack", 0.0)
		await _episode(20)
		_action("move_left", 1.0)
		await _episode(7)
		_action("move_left", 0.0)
		_action("attack", 1.0)
		await _episode(30)
		_action("attack", 0.0)
		_action("move_left", 1.0)
		await _episode(18)
		_action("move_left", 0.0)
		await _episode(41)
	else:
		_action("attack", 1.0)
		await _episode(6)
		_action("attack", 0.0)
		await _episode(5)
		_action("move_left", 1.0)
		await _episode(36)
		_action("move_left", 0.0)
		await _episode(85)
	_release()
	_checkpoint("episode_final")
	if build == "gather" and (metrics.third_attacks_hitting == 0 or metrics.fourth_attacks_hitting == 0) or build == "companion" and focused_shots == 0:
		printerr("FAIL: intended existing build action was not exercised")
		quit(1)
		return
	var report := {"sample": "matched_build_actions_v48", "human_playtest": false, "natural_run": false, "rendered": false,
		"engine": Engine.get_version_info().string, "build": build, "fixture": initial_fixture, "offered_triples": OFFERS,
		"synthetic": ["prior history", "XP", "nine common offered triples", "three160HP targets", "regional clock disabled", "episode clock"],
		"episode_seconds": float(episode_frames) / 60.0, "choices": choices, "trace": trace, "checkpoints": checkpoints,
		"notes": "Different input sequences demonstrate existing build actions. This is not a DPS, survival, boss-arrival or preference ranking; natural first-life records are separate."}
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	scene.queue_free()
	await process_frame
	quit(0)

func _episode(count: int) -> void:
	for i in count:
		await physics_frame
		episode_frames += 1
		scene.run_time = float(episode_frames) / 60.0
		distance_walked += previous_position.distance_to(scene.player.position)
		previous_position = scene.player.position
		_observe_actions()
		var p: SandboxPlayer = scene.player
		trace.append({"frame": episode_frames, "position": [p.position.x, p.position.y], "step": p.attack_step, "next": p.next_combo_step,
			"prepared": p.flow_weave_ready, "empowered": p.flow_weave_attack, "slash": p.moving_slash_time > 0.0,
			"focus": p.has_meta(&"companion_focus_target"), "health": p.health})
