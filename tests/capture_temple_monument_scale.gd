extends SceneTree
## Static comparison fixtures only. Requires real graphics and isolated userdata.
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var output := OS.get_environment("TEMPLE_MONUMENT_CAPTURE_DIR")
	if output.is_empty() or OS.get_environment("XDG_DATA_HOME").is_empty() or not "WetlandV44" in OS.get_user_data_dir() or DisplayServer.get_name() == "headless":
		printerr("FAIL: explicit output and isolated XDG_DATA_HOME required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var scene = load("res://game/temple_circuit_run.tscn").instantiate()
	scene.profile_save_prefix = "user://temple_scale_capture"
	scene.growth_save_prefix = "user://temple_scale_capture_growth"
	root.add_child(scene)
	current_scene = scene
	for i in 5: await physics_frame
	scene.set_physics_process(false)
	scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
	for size in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = size
		root.content_scale_size = Vector2i(1280,720)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		for sample in [["threshold",Vector2(2650,1000)],["arrival",Vector2(2800,900)],["sanctuary",Vector2(2800,460)],["west-side",Vector2(2270,660)],["northwest-shoulder",Vector2(2340,80)],["northeast-shoulder",Vector2(3270,80)],["boss-ring",Vector2(2800,850)],["overview",Vector2(2450,2100)]]:
			scene.teleport(sample[1])
			scene.overview = sample[0] == "overview"
			scene.camera.size = scene.overview_camera_size if scene.overview else scene.combat_camera_size
			if is_instance_valid(scene.boss): scene.boss.ring_warning = 0.0
			if sample[0] == "boss-ring":
				scene.run_time = scene.BOSS_TIME
				scene.temple_section.tick(0)
				scene.temple_section.tick(1.3)
				if not is_instance_valid(scene.boss):
					printerr("FAIL: boss ring fixture did not create a boss")
					quit(1)
					return
				scene.boss.ring_warning = 0.55
			if is_instance_valid(scene.boss): scene.actors[scene.boss].visible = sample[0] == "boss-ring"
			for i in 30: await process_frame
			await RenderingServer.frame_post_draw
			var capture := root.get_texture().get_image()
			if capture == null or capture.is_empty():
				printerr("FAIL: real rendering required")
				quit(1)
				return
			var path := output.path_join("%s-%d.png" % [sample[0],size.x])
			if capture.save_png(path) != OK: quit(1); return
			print("CAPTURE static fixture: ",path)
	scene.queue_free()
	for i in 3: await process_frame
	quit()
