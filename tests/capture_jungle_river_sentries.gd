extends SceneTree
## Fixed normal-speed input, native AI and render. No human fun/balance verdict.
const Fixture = preload("res://tests/jungle_river_fixture.gd")
const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "attack"]
var scene
var captures: Array = []
var trace: Array = []
var warning_seen := false
var bolts_seen := false
var zone_seen := false
var attacks_started := 0
var attacks_fired := 0
var interruptions := 0
var previous_health := 32.0
var previous_warning := 0.0
var walked := 0.0
var prior := Vector2.ZERO
var output := ""
var candidate := false
var failures: Array = []

func _initialize() -> void: call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func _input(direction: Vector2, attacking: bool) -> void:
	var rotated: Vector2 = direction.rotated(-scene.player.input_rotation)
	var strengths := [maxf(0, -rotated.x), maxf(0, rotated.x), maxf(0, -rotated.y), maxf(0, rotated.y), 1.0 if attacking else 0.0]
	for i in ACTIONS.size():
		var event := InputEventAction.new()
		event.action = ACTIONS[i]
		event.strength = strengths[i]
		event.pressed = strengths[i] > 0.0
		Input.parse_input_event(event)

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	_check(frame != null and not frame.is_empty(), "native graphical frame available")
	if frame == null or frame.is_empty(): return
	var file := label + ".png"
	_check(frame.save_png(output.path_join(file)) == OK, "capture saved")
	captures.append({"file": file, "position": [scene.player.position.x, scene.player.position.y], "warning_vertices": scene.warning_vertex_count})

func _run() -> void:
	output = OS.get_environment("JUNGLE_RIVER_OUTPUT")
	var args := OS.get_cmdline_user_args()
	candidate = args.has("--candidate")
	if output.is_empty() or not OS.get_user_data_dir().contains("LoopConquestMapTrials/"):
		printerr("FAIL: private trial project and explicit output directory required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720) if args.has("--large") else Vector2i(960, 540)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	Engine.time_scale = 1.0
	Engine.max_fps = 60
	var native := args.has("--require-mount")
	scene = load("res://game/jungle_pass.tscn").instantiate() if native else Fixture.new()
	var flag := "river_sentry_trial_enabled" if native else "fixture_trial_enabled"
	_check(scene.get(flag) != null, "requested mount present")
	if scene.get(flag) == null:
		scene.free()
		quit(1)
		return
	scene.set(flag, candidate)
	scene.profile_save_prefix = "user://river_capture_%s_%s_profile" % [candidate, root.size.x]
	scene.growth_save_prefix = "user://river_capture_%s_%s_unlocks" % [candidate, root.size.x]
	root.add_child(scene)
	current_scene = scene
	await physics_frame
	# The fixture must continue while other Mac windows gain focus. Disconnect
	# only this test window's authored focus-pause callback; production is intact.
	for connection in root.focus_exited.get_connections():
		root.focus_exited.disconnect(connection.callable)
	scene._set_paused(false)
	scene.rng.seed = 4102
	# Only the two authored entrance defenders are observed. Ambient spawns and
	# level-up modals are disabled identically. Default fresh loadout/HP/AI stay.
	scene.spawn_credit = -100000.0
	scene.growth.growth_ended = true
	scene.teleport(Vector2(2590, 1770))
	prior = scene.player.position
	var started := Time.get_ticks_usec()
	var checkpoints: Array = []
	for tick in 600:
		# Same input strengths on the same 60 Hz ticks in both variants.
		var direction := Vector2.ZERO
		if tick >= 90 and tick < 144: direction = Vector2.DOWN
		elif tick >= 144 and tick < 228: direction = Vector2.RIGHT
		elif tick >= 228 and tick < 270: direction = Vector2.UP
		elif tick >= 270 and tick < 324: direction = Vector2.LEFT
		elif tick >= 390 and tick < 438: direction = Vector2.LEFT
		elif tick >= 438 and tick < 480: direction = Vector2.UP
		elif tick >= 480 and tick < 540: direction = Vector2.LEFT
		_input(direction, tick >= 270 and tick < 390)
		await physics_frame
		var point: Vector2 = scene.player.position
		walked += point.distance_to(prior)
		prior = point
		bolts_seen = bolts_seen or not get_nodes_in_group("enemy_bolts").is_empty()
		zone_seen = zone_seen or not get_nodes_in_group("enemy_zones").is_empty()
		var role_trace := {}
		for actor in scene.actors:
			if is_instance_valid(actor) and actor is TrainingEnemy and actor.role == (TrainingEnemy.Role.LAMP if candidate else TrainingEnemy.Role.ZONE):
				attacks_started = maxi(attacks_started, actor.attacks_started)
				attacks_fired = maxi(attacks_fired, actor.attacks_fired)
				warning_seen = warning_seen or actor.warning_time > 0.0
				if previous_warning > 0.0 and actor.warning_time <= 0.0 and actor.health < previous_health: interruptions += 1
				previous_warning = actor.warning_time
				previous_health = actor.health
				role_trace = {"point": [actor.position.x, actor.position.y], "hp": actor.health, "warning": actor.warning_time, "started": actor.attacks_started, "fired": actor.attacks_fired}
		for zone in get_nodes_in_group("enemy_zones"):
			warning_seen = warning_seen or zone.warning_time > 0.0
		if tick % 30 == 0:
			trace.append({"tick": tick, "point": [point.x, point.y], "hp": scene.player.health, "role": role_trace, "warnings": scene.warning_vertex_count, "bolts": get_nodes_in_group("enemy_bolts").size(), "zones": get_nodes_in_group("enemy_zones").size(), "enemies": scene._active_enemy_count()})
		if tick in [89, 143, 227, 269, 389, 437, 479, 539, 599]:
			checkpoints.append({"tick": tick, "point": [point.x, point.y]})
		if tick == 64: await _capture("entrance-warning")
		if tick == 260: await _capture("bypass-approach")
	_input(Vector2.ZERO, false)
	await physics_frame
	var result := {
		"variant": "candidate" if candidate else "baseline", "engine": Engine.get_version_info().string,
		"native_mount": native, "resolution": [root.size.x, root.size.y], "time_scale": Engine.time_scale,
		"fixture": "10 seconds of identical 60 Hz directional and attack actions; entry teleported once; fresh default HP/loadout including automatic companion; ambient spawns and growth modal disabled equally; test-window focus auto-pause disconnected equally; actual entrance scheduling/AI/bolts/zones/warnings/camera. Not a natural full run, human fun, audio or performance acceptance.",
		"wall_seconds": (Time.get_ticks_usec() - started) / 1000000.0, "run_seconds": scene.run_time,
		"walked": walked, "checkpoints": checkpoints, "trace": trace,
		"warning_seen": warning_seen, "bolts_seen": bolts_seen, "zone_seen": zone_seen,
		"role_attacks_started": attacks_started, "role_attacks_fired": attacks_fired,
		"observed_warning_interruptions": interruptions,
		"hp": scene.player.health, "kills": scene.kills, "currency": scene.run_currency,
		"entrance": scene.gate_route_encounter, "crest_triggered": scene.gate_route_crest_triggered,
		"captures": captures, "user_data_dir": OS.get_user_data_dir(),
	}
	_check(scene.gate_route_encounter == "rocks" and not scene.gate_route_crest_triggered, "only river entrance encounter observed")
	_check(warning_seen and attacks_started > 0, "actual role attack attempt and warning observed")
	# A blocked/interrupted lamp attack is a comparison outcome, not a reason
	# to alter the fixture until it fires. Preserve its observed zero-shot count.
	_check(not zone_seen if candidate else not bolts_seen, "no unexpected attack type introduced")
	_check(walked > 600.0 and scene.player.health > 0.0 and not scene.run_ended, "fixture walks and fights without ending")
	result["failures"] = failures
	result["complete"] = failures.is_empty()
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  ") + "\n")
	file.close()
	print("Jungle river live ", result.variant, ": complete=", result.complete, ", attacks=", attacks_fired, ", walked=", walked)
	scene.queue_free()
	scene = null
	current_scene = null
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
