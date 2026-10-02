extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var output := OS.get_environment("WETLAND_CAPTURE_DIR")
	if output.is_empty() or not "WetlandV44" in OS.get_user_data_dir():
		printerr("FAIL: isolated WetlandV44 userdata and output required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var circuit := OS.get_environment("CAPTURE_TEMPLE_CIRCUIT") == "1"
	var circuit_run := OS.get_environment("CAPTURE_CIRCUIT_RUN") == "1"
	var jungle_south := OS.get_environment("CAPTURE_JUNGLE_SOUTH") == "1"
	var scene_path := "res://game/deep_wetland_trial.tscn"
	if circuit: scene_path = "res://game/temple_circuit_trial.tscn"
	if circuit_run: scene_path = "res://game/temple_circuit_run.tscn"
	if jungle_south: scene_path = "res://game/jungle_south_circuit.tscn"
	var scene = load(scene_path).instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 5: await physics_frame
	# Static camera evidence; navigation/combat state tests are separate.
	for enemy in scene.actors:
		if enemy != scene.player: enemy.set_physics_process(false)
	var samples := [] if circuit_run or jungle_south else [{"name": "entry", "point": scene.Wetland.ENTRY}, {"name": "procession", "point": scene.Wetland.PROCESSION}, {"name": "face-bank", "point": scene.Wetland.FACE_BANK}, {"name": "court", "point": scene.Wetland.TEMPLE_COURT}, {"name": "overview", "point": scene.Wetland.FACE_BANK}]
	if circuit:
		samples = [{"name": "entry", "point": scene.Circuit.ENTRY}, {"name": "court", "point": scene.Circuit.CENTRAL_COURT}, {"name": "cloister", "point": scene.Circuit.CLOISTER}, {"name": "sanctuary", "point": scene.Circuit.SANCTUARY}, {"name": "overview", "point": scene.Circuit.CENTRAL_COURT}]
	if circuit_run:
		samples = [{"name": "entry", "point": Vector2(650, 3000)}, {"name": "court", "point": Vector2(2450, 2100)}, {"name": "cloister", "point": Vector2(1450, 1350)}, {"name": "sanctuary", "point": Vector2(2800, 900)}, {"name": "overview", "point": Vector2(2450, 2100)}]
	if jungle_south:
		samples = [{"name": "ridge", "point": Vector2(2175, 1800)}, {"name": "descent", "point": Vector2(3010, 2440)}, {"name": "landing", "point": Vector2(3540, 2660)}, {"name": "transit", "point": Vector2(2080, 2910)}, {"name": "overview", "point": Vector2(2450, 2100)}]
	scene.set_physics_process(false) # Static render/navigation fixture only; no encounter activation.
	scene.wisp.set_physics_process(false)
	for size in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = size
		root.content_scale_size = Vector2i(1280, 720)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		for sample in samples:
			scene.teleport(sample.point)
			scene.overview = sample.name == "overview"
			scene.camera.size = scene.overview_camera_size if scene.overview else scene.combat_camera_size
			for i in 30: await process_frame
			await RenderingServer.frame_post_draw
			var capture := root.get_texture().get_image()
			if capture == null or capture.is_empty():
				printerr("FAIL: rendered pixels required")
				quit(1)
				return
			var path := output.path_join("%s-%d.png" % [sample.name, size.x])
			if capture.save_png(path) != OK:
				printerr("FAIL: cannot save ", path)
				quit(1)
				return
			print("CAPTURE: ", path)
	scene.queue_free()
	for i in 3: await process_frame
	quit()
