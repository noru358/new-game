extends SceneTree
## Isolated normal-speed visual walk, NOT natural combat, progression or fun evidence.
## REGION_LANDMARK=temple|jungle; REGIONAL_LANDMARK_OUTPUT=<fresh directory>.
## --measure-only explicitly permits headless walking with render=false and no PNGs.
const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "attack", "dash", "moving_slash"]
const SIZES := [Vector2i(960, 540), Vector2i(1280, 720)]
var scene
var output := ""
var region := ""
var measure_only := false
var errors: Array[String] = []
var records: Array = []
var screenshots: Array[String] = []
var active_seconds := 0.0
var started := 0
var expected_screenshots := 0
var finished := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	started = Time.get_ticks_usec()
	output = OS.get_environment("REGIONAL_LANDMARK_OUTPUT")
	region = OS.get_environment("REGION_LANDMARK")
	measure_only = OS.get_cmdline_user_args().has("--measure-only")
	# No scene (and hence no profile reader) may exist before this guard passes.
	if output.is_empty() or not output.is_absolute_path() or not ("WetlandV44" in OS.get_user_data_dir() or "RegionalLandmarkV47" in OS.get_user_data_dir()):
		printerr("FAIL: absolute output and isolated WetlandV44/RegionalLandmarkV47 userdata required")
		quit(1)
		return
	if region not in ["temple", "jungle"]:
		printerr("FAIL: REGION_LANDMARK must be temple or jungle")
		quit(1)
		return
	if DirAccess.dir_exists_absolute(output) and not DirAccess.get_files_at(output).is_empty():
		printerr("FAIL: output must be fresh; existing evidence is never overwritten")
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		printerr("FAIL: cannot create output")
		quit(1)
		return
	if not measure_only and (DisplayServer.get_name() == "headless" or RenderingServer.get_rendering_device() == null and RenderingServer.get_video_adapter_name().is_empty()):
		errors.append("Graphical capture requires a usable renderer; use --measure-only for headless checks")
		await _finish()
		return
	Engine.time_scale = 1.0
	Engine.max_fps = 60
	var samples := _samples()
	expected_screenshots = 0 if measure_only else SIZES.size() * (samples.size() * 2 + 1)
	for size in SIZES:
		root.size = size
		root.content_scale_size = Vector2i(1280, 720)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		scene = load("res://game/temple_circuit_run.tscn" if region == "temple" else "res://game/jungle_south_circuit.tscn").instantiate()
		# Unique prefixes before _ready, no shared preview-session override.
		scene.profile_save_prefix = "user://regional_landmark_%s_%d_%d_profile" % [region, size.x, Time.get_ticks_usec()]
		scene.growth_save_prefix = scene.profile_save_prefix + "_unlocks"
		root.add_child(scene)
		current_scene = scene
		scene.set_physics_process(false) # Freeze spawns, section ticks and run clock only.
		scene.wisp.set_physics_process(false)
		for actor in scene.actors:
			if actor != scene.player: actor.set_physics_process(false)
		for i in 5: await physics_frame
		for sample in samples:
			if not scene.navigation.is_open(sample.point, 30.0) or not scene.player.arena_bounds.has_point(sample.point):
				errors.append("Blocked/nonplayable requested target: " + sample.name + " " + str(sample.point))
				break
			var wall_start := Time.get_ticks_usec()
			var active_start := active_seconds
			await _walk(sample.point)
			if not errors.is_empty(): break
			await create_timer(0.8).timeout # Normal camera follow settles; no camera reset.
			var record := {"name": sample.name, "width": size.x, "height": size.y,
				"target": _point(sample.point), "reached": _point(scene.player.position),
				"active_walk_seconds": active_seconds - active_start,
				"wall_seconds": (Time.get_ticks_usec() - wall_start) / 1000000.0,
				"approach": "ordinary movement inputs via existing navigation; no teleport",
				"render": false, "camera_size": scene.camera.size, "camera_position": [scene.camera.position.x,scene.camera.position.y,scene.camera.position.z],
				"camera_rotation": [scene.camera.rotation.x,scene.camera.rotation.y,scene.camera.rotation.z], "move_speed": scene.player.MOVE_SPEED,
				"move_speed_multiplier": scene.player.move_speed_multiplier, "run_time_frozen": scene.run_time}
			if not measure_only: await _capture_checkpoint(sample.name, size.x, record)
			records.append(record)
			print("CHECKPOINT: ", JSON.stringify(record))
			if not errors.is_empty(): break
		if errors.is_empty() and not measure_only:
			# Explicit separate static overview, matching existing capture_deep_wetland.
			scene.teleport(Vector2(2450, 2100))
			scene.overview = true
			scene.camera.size = scene.overview_camera_size
			await create_timer(0.8).timeout
			var overview_image := await _image()
			_save(overview_image, "overview-static-%d.png" % size.x)
			records.append({"name": "overview-static", "width": size.x, "target": [2450,2100], "approach": "separate static overview; explicit teleport", "render": overview_image != null})
		await _free_scene()
		if not errors.is_empty(): break
	await _finish()

func _process(_delta: float) -> bool:
	if started > 0 and not finished and Time.get_ticks_usec() - started > 480000000:
		errors.append("Whole-fixture 480-second watchdog expired")
		_finish()
	return false

func _samples() -> Array:
	if region == "temple":
		return [{"name":"threshold","point":Vector2(2650,1000)}, {"name":"sanctuary","point":Vector2(2800,460)}, {"name":"bossfloor","point":Vector2(2800,620)}, {"name":"westside","point":Vector2(2270,660)}, {"name":"eastside","point":Vector2(3450,600)}, {"name":"nearapron","point":Vector2(2800,280)}]
	return [{"name":"actualstart","point":Vector2(430,1210)}, {"name":"root-offset","point":Vector2(250,850)}, {"name":"rootfront","point":Vector2(350,850)}, {"name":"rooteast","point":Vector2(820,600)}, {"name":"rootsoutheast","point":Vector2(850,700)}]

func _walk(goal: Vector2) -> void:
	if scene.player.position.distance_to(goal) <= 5.0: return
	var route: PackedVector2Array = scene.navigation.find_path(scene.player.position, goal)
	if route.is_empty():
		errors.append("No navigation route to " + str(goal))
		return
	route.append(goal) # Grid centers are not the requested final viewpoint.
	var wall_start := Time.get_ticks_usec()
	var last_motion := wall_start
	var last_position: Vector2 = scene.player.position
	for target in route:
		while scene.player.position.distance_to(target) > 5.0:
			var now := Time.get_ticks_usec()
			if now - wall_start > 180000000 or now - last_motion > 5000000:
				errors.append("Walk timeout/stall at %s toward %s (goal %s)" % [scene.player.position, target, goal])
				_release()
				return
			if scene.player.position.distance_to(last_position) > 2.0:
				last_position = scene.player.position
				last_motion = now
			var direction: Vector2 = scene.player.position.direction_to(target).rotated(-scene.player.input_rotation)
			_release()
			# Analog direction becomes full-speed normal movement via Input.get_vector.
			Input.action_press("move_left", maxf(0.0, -direction.x))
			Input.action_press("move_right", maxf(0.0, direction.x))
			Input.action_press("move_up", maxf(0.0, -direction.y))
			Input.action_press("move_down", maxf(0.0, direction.y))
			await physics_frame
			active_seconds += 1.0 / Engine.physics_ticks_per_second
	_release()

func _capture_checkpoint(label: String, width: int, record: Dictionary) -> void:
	# Freeze only for differential frames; restore normal player/camera processing.
	scene.set_process(false)
	scene.player.set_physics_process(false)
	var actor: Node3D = scene.actors[scene.player]
	var body: Node3D = actor.get_node("Body")
	var center: Vector2 = scene.camera.unproject_position(body.global_position)
	var normal := await _image()
	record["draw_calls"] = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	record["primitives"] = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	record["objects"] = Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	body.hide()
	var normal_without := await _image()
	body.show()
	var hidden: Array[GeometryInstance3D] = []
	for node in scene.find_children("*", "GeometryInstance3D", true, false):
		if not actor.is_ancestor_of(node) and node.visible:
			hidden.append(node)
			node.hide()
	var reference := await _image()
	body.hide()
	var reference_without := await _image()
	body.show()
	for node in hidden: node.show()
	scene.player.set_physics_process(true)
	scene.set_process(true)
	if normal == null or normal_without == null or reference == null or reference_without == null: return
	_save(normal, "%s-%d.png" % [label, width])
	_save(reference, "%s-reference-%d.png" % [label, width])
	# Only a bounded 160x160 box around the actor, never a full-map pixel sweep.
	var roi := Rect2i(Vector2i(center) - Vector2i(80,80), Vector2i(160,160)).intersection(Rect2i(Vector2i.ZERO, normal.get_size()))
	var potential := 0
	var visible := 0
	for y in range(roi.position.y, roi.end.y):
		for x in range(roi.position.x, roi.end.x):
			if _different(reference.get_pixel(x,y), reference_without.get_pixel(x,y)):
				potential += 1
				if _different(normal.get_pixel(x,y), normal_without.get_pixel(x,y)): visible += 1
	record["visibility"] = {"reference_actor_pixels": potential, "normal_actor_pixels": visible, "ratio": float(visible) / maxf(1.0, potential), "roi": [roi.position.x,roi.position.y,roi.size.x,roi.size.y], "scope": "bounded player Body-only differential (shadow excluded), scenery geometry hidden reference; no full-map visibility claim"}
	record["render"] = true
	if potential < 8: errors.append("No usable player pixel reference at " + label)
	if visible < 8: errors.append("Player not visibly evidenced at " + label)

func _different(a: Color, b: Color) -> bool:
	return maxf(absf(a.r-b.r), maxf(absf(a.g-b.g), absf(a.b-b.b))) > 0.035

func _image() -> Image:
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image()
	if result == null or result.is_empty():
		errors.append("Renderer produced no image")
		return null
	if result.get_size() != root.size:
		errors.append("Rendered image size differs from requested resolution")
		return null
	return result

func _save(value: Image, filename: String) -> void:
	if value == null: return
	if value.save_png(output.path_join(filename)) != OK: errors.append("Cannot save " + filename)
	else: screenshots.append(filename)

func _point(value: Vector2) -> Array:
	return [value.x, value.y]

func _release() -> void:
	for action in ACTIONS:
		if InputMap.has_action(action): Input.action_release(action)

func _free_scene() -> void:
	_release()
	if is_instance_valid(scene):
		scene.queue_free()
		for i in 3: await process_frame
	scene = null

func _finish() -> void:
	if finished: return
	finished = true
	await _free_scene()
	if screenshots.size() != expected_screenshots: errors.append("Screenshot count %d != expected %d" % [screenshots.size(), expected_screenshots])
	var report := {"scope":"isolated visual-walk fixture; frozen spawn/time pressure and enemy attacks; NOT natural combat or fun evidence", "region":region, "rejected_targets": [{"name":"eastside", "requested":[3350,500], "reason":"Inside existing wall Rect2(3310,170,80,370)", "approved_replacement":[3450,600]}] if region == "temple" else [], "engine":Engine.get_version_info().string, "render":not measure_only and not screenshots.is_empty(), "measure_only":measure_only, "time_scale":Engine.time_scale, "normal_input":true, "acceleration":false, "wall_seconds":(Time.get_ticks_usec()-started)/1000000.0, "active_walk_seconds":active_seconds, "resolutions":[[960,540],[1280,720]], "screenshots":screenshots, "expected_screenshots":expected_screenshots, "samples":records, "errors":errors}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	if file == null:
		printerr("FAIL: cannot write report")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("REGIONAL_LANDMARK_RESULT: ", JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
