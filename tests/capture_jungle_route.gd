extends SceneTree
## Normal-speed input on the actual Mac-rendered scene; no human fun verdict.
const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "attack"]
var scene
var output := ""
var walks: Array = []
var captures: Array = []
var failures: Array = []
var warnings_seen := false
var zones_seen := false
var walked := 0.0
var min_height := INF
var max_height := -INF

func _initialize() -> void: call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func _input(direction: Vector2, attacking := true) -> void:
	var rotated: Vector2 = direction.rotated(-scene.player.input_rotation)
	var strengths := [maxf(0, -rotated.x), maxf(0, rotated.x), maxf(0, -rotated.y), maxf(0, rotated.y), 1.0 if attacking else 0.0]
	for i in ACTIONS.size():
		var event := InputEventAction.new()
		event.action = ACTIONS[i]
		event.strength = strengths[i]
		event.pressed = strengths[i] > 0.0
		Input.parse_input_event(event)

func _walk(goal: Vector2, label: String) -> void:
	var started := Time.get_ticks_usec()
	var distance_before := walked
	var ticks := 0
	while scene.player.position.distance_to(goal) > 7.0 and ticks < 1200 and not scene.run_ended:
		var point: Vector2 = scene.player.position
		var path: PackedVector2Array = scene.navigation.find_path(point, goal)
		var direction := Vector2.ZERO
		if path.size() >= 2:
			var index := 1
			while index < path.size() - 1 and point.distance_to(path[index]) < 15: index += 1
			direction = point.direction_to(path[index])
		elif scene.clear_attack(point, goal): direction = point.direction_to(goal)
		_input(direction)
		await physics_frame
		ticks += 1
		walked += point.distance_to(scene.player.position)
		var height: float = scene.terrain.height_at(scene.player.position)
		min_height = minf(min_height, height)
		max_height = maxf(max_height, height)
		warnings_seen = warnings_seen or scene.warning_vertex_count > 0
		zones_seen = zones_seen or not get_nodes_in_group("enemy_zones").is_empty()
	_input(Vector2.ZERO, false)
	await physics_frame
	var remaining: float = scene.player.position.distance_to(goal)
	_check(remaining <= 7.0, "ordinary input reaches " + label + ": " + str(remaining))
	walks.append({"label": label, "goal": [goal.x, goal.y], "point": [scene.player.position.x, scene.player.position.y], "remaining": remaining, "walked": walked - distance_before, "physics_seconds": ticks / 60.0, "wall_seconds": (Time.get_ticks_usec() - started) / 1000000.0, "height": scene.terrain.height_at(scene.player.position), "hp": scene.player.health})

func _capture(label: String) -> void:
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	_check(frame != null and not frame.is_empty(), "native graphical frame available")
	if frame == null or frame.is_empty(): return
	var filename := label + ".png"
	_check(frame.save_png(output.path_join(filename)) == OK, "capture saved")
	captures.append({"file": filename, "point": [scene.player.position.x, scene.player.position.y], "height": scene.terrain.height_at(scene.player.position)})

func _run() -> void:
	output = OS.get_environment("ROUTE_OUTPUT")
	var args := OS.get_cmdline_user_args()
	var baseline := args.has("--jungle-route-baseline")
	if output.is_empty() or not OS.get_user_data_dir().contains("LoopConquestMapTrials/"):
		printerr("FAIL: explicit output and private project required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720) if args.has("--large") else Vector2i(960, 540)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	Engine.time_scale = 1.0
	Engine.max_fps = 60
	scene = load("res://game/jungle_pass.tscn").instantiate()
	scene.profile_save_prefix = "user://route_%s_%s_profile" % [baseline, root.size.x]
	scene.growth_save_prefix = "user://route_%s_%s_unlocks" % [baseline, root.size.x]
	root.add_child(scene)
	current_scene = scene
	await physics_frame
	for connection in root.focus_exited.get_connections(): root.focus_exited.disconnect(connection.callable)
	scene._set_paused(false)
	scene.rng.seed = 4102
	scene.spawn_credit = -100000.0
	scene.growth.growth_ended = true
	scene.teleport(Vector2(2400, 1770)) # One fixture start; all route checkpoints walked.
	await _capture("01-ridge-entry")
	await _walk(Vector2(2590, 1770), "narrow-descent")
	for i in 60: await physics_frame # Authored entrance scheduling/AI stay active.
	await _walk(Vector2(2910, 1930), "open-riverbank")
	await _capture("02-open-riverbank")
	await _walk(Vector2(3080, 2160), "water-edge")
	await _capture("03-water-and-remnant")
	await _walk(Vector2(3310, 2080), "south-bypass")
	await _walk(Vector2(3410, 1790), "broken-bridge-rise")
	await _walk(Vector2(3240, 1740), "north-bypass")
	await _capture("05-north-remnant")
	await _walk(Vector2(3010, 1760), "short-return-loop")
	await _walk(Vector2(3310, 2080), "river-return")
	await _walk(Vector2(3750, 1770), "gate-ascent")
	await _walk(Vector2(4180, 1770), "destination-sight")
	await _capture("04-gate-destination")
	await _walk(Vector2(4520, 1160), "gate-interior")
	_check(scene.gate_route_encounter == "rocks" and scene.gate_route_crest_triggered, "original river entrance and crest reached by walking")
	_check(scene.player.health > 0 and not scene.run_ended, "route does not end fixture run")
	_check(min_height <= 82 and max_height >= 478, "actual existing 80 -> 480 elevation traversed")
	var report := {"variant": "baseline" if baseline else "candidate", "engine": Engine.get_version_info().string, "resolution": [root.size.x, root.size.y], "time_scale": Engine.time_scale, "walks": walks, "walked": walked, "height_range": [min_height, max_height], "warnings_seen": warnings_seen, "zones_seen": zones_seen, "kills": scene.kills, "currency": scene.run_currency, "hp": scene.player.health, "captures": captures, "failures": failures, "complete": failures.is_empty(), "fixture": "One start placement; all 11 checkpoints via ordinary 60Hz directional and attack input, actual navigation/collision/elevation/entry/crest/native defenders/camera. Fresh HP/loadout and automatic companion. Ambient spawns and growth modal disabled equally, test window focus auto-pause disconnected equally. No dash or waypoint teleport. No natural full run, human fun, volume acceptance, audio or performance verdict.", "user_data_dir": OS.get_user_data_dir()}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("Route native walk ", report.variant, ": complete=", report.complete, ", walked=", walked)
	scene.queue_free()
	scene = null
	current_scene = null
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
