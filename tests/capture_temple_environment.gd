extends SceneTree
## Matched actual-engine inspection frames. Boss poses are frozen fixtures,
## not live gameplay, a normal run, or performance evidence.

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var original_baseline := OS.get_cmdline_user_args().has("--temple-baseline")
	var sanctuary_baseline := OS.get_cmdline_user_args().has("--sanctuary-baseline")
	var variant := "original" if original_baseline else "v33" if sanctuary_baseline else "sanctuary"
	var output := OS.get_environment("TEMPLE_CAPTURE_DIR")
	if output.is_empty(): output = "user://temple_environment_captures"
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	var scene = load("res://game/hybrid_region.tscn").instantiate()
	scene.profile_save_prefix = "user://temple_environment_capture_profile"
	scene.growth_save_prefix = "user://temple_environment_capture_unlocks"
	scene.temple_environment_enabled = not original_baseline
	scene.temple_sanctuary_enabled = not sanctuary_baseline
	root.add_child(scene)
	current_scene = scene
	for i in 5: await process_frame
	scene.set_physics_process(false)
	scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
	scene.rng.seed = 3701
	if not original_baseline and not sanctuary_baseline and scene.temple_sanctuary_root == null:
		printerr("FAIL: sanctuary must exist before capturing the new state")
		quit(1)
		return
	for size in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = size
		root.content_scale_size = Vector2i(1280, 720)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		for sample in [
			{"name": "01-approach", "point": Vector2(3900, 1120)},
			{"name": "02-arrival", "point": Vector2(4320, 1150)},
			{"name": "03-far-court", "point": Vector2(4750, 1370)},
			{"name": "04-boss-charge", "point": Vector2(4350, 1180)},
			{"name": "05-boss-ring", "point": Vector2(4350, 1180)},
			{"name": "06-boss-counter", "point": Vector2(4460, 1120)},
			{"name": "07-remnant-sight", "point": Vector2(4770, 960)},
		]:
			var boss_pose: bool = sample.name.contains("boss-")
			if is_instance_valid(scene.boss):
				scene.boss.warning_time = 0
				scene.boss.shock_warning = 0
				scene.boss.ring_warning = 0
				scene.boss.impact_flash = 0
				scene.boss.recovery_time = 0
				scene.boss.counter_flash = 0
				(scene.actors[scene.boss] as Node3D).visible = boss_pose
			if boss_pose and not is_instance_valid(scene.boss):
				scene.teleport(Vector2(3900, 1120))
				scene.run_time = 300
				scene.temple_section.tick(0)
				scene.temple_section.tick(1.3)
				scene.boss.set_physics_process(false)
			scene.teleport(sample.point)
			if boss_pose:
				scene.temple_section.tick(0)
				if sample.name == "04-boss-charge":
					scene.boss.warning_time = 0.45
					scene.boss.locked_direction = Vector2(0.8, 0.6)
					scene.boss.planned_charge_distance = 280
				elif sample.name == "05-boss-ring":
					scene.boss.ring_warning = 0.55
				else:
					scene.boss.recovery_time = 0.55
					scene.boss.counter_flash = 0.15
				scene._update_run_hud()
			for i in 30: await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			if image == null or image.is_empty():
				printerr("FAIL: real graphical rendering is required")
				quit(1)
				return
			var filename: String = "%s-%s-%dx%d.png" % [variant, sample.name, size.x, size.y]
			image.save_png(output.path_join(filename))
			var faded: Array[String] = []
			if is_instance_valid(scene.temple_sanctuary_root):
				for group in scene.temple_sanctuary_root.get_meta("occlusion_groups"):
					if group.material_override.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA: faded.append(group.name)
			print("CAPTURE frozen fixture: ", filename, " point=", sample.point, " camera=", scene.camera.size, " faded=", faded)
	quit()
