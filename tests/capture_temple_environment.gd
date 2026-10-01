extends SceneTree
## Matched actual-engine inspection frames, not human gameplay/performance proof.

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var baseline := OS.get_cmdline_user_args().has("--temple-baseline")
	var variant := "before" if baseline else "after"
	var output := OS.get_environment("TEMPLE_CAPTURE_DIR")
	if output.is_empty(): output = "user://temple_environment_captures"
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	var scene = load("res://game/hybrid_region.tscn").instantiate()
	scene.profile_save_prefix = "user://temple_environment_capture_profile"
	scene.growth_save_prefix = "user://temple_environment_capture_unlocks"
	if scene.get("temple_environment_enabled") != null: scene.temple_environment_enabled = not baseline
	root.add_child(scene)
	current_scene = scene
	for i in 5: await process_frame
	scene.set_physics_process(false)
	scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
	scene.rng.seed = 3301
	if not baseline and scene.get("temple_environment_root") == null:
		printerr("FAIL: environment kit must exist before capturing the after state")
		quit(1)
		return
	for sample in [
		{"name": "01-corridor", "point": Vector2(3410, 900)},
		{"name": "02-approach", "point": Vector2(3900, 1120)},
		{"name": "02b-threshold-sight", "point": Vector2(3980, 850)},
		{"name": "02c-threshold-threat", "point": Vector2(3900, 1120)},
		{"name": "03-sanctuary", "point": Vector2(4320, 1150)}
	]:
		if sample.name == "03-sanctuary":
			# Let the normal waiting-boss logic choose its default point while
			# the hero is still outside, then inspect the same warning pose.
			scene.teleport(Vector2(3900, 1120))
			scene.run_time = 300.0
			scene.temple_section.tick(0.0)
			scene.temple_section.tick(1.3)
			scene.teleport(sample.point)
			scene.temple_section.tick(0.0)
			scene.boss.set_physics_process(false)
			scene.boss.shock_warning = 0.75
			scene._update_run_hud()
		else:
			scene.teleport(sample.point)
		var inspection_enemy: TrainingEnemy
		if sample.name == "02c-threshold-threat":
			inspection_enemy = scene._spawn_enemy_at(Vector2(3980, 850), TrainingEnemy.Role.BEAST, 100.0)
			inspection_enemy.warning_time = 0.55
			inspection_enemy.locked_direction = inspection_enemy.position.direction_to(scene.player.position)
		for i in 35: await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		if image == null or image.is_empty():
			printerr("FAIL: real graphical rendering is required")
			quit(1)
			return
		image.save_png(output.path_join(variant + "-" + sample.name + ".png"))
		print("CAPTURE: ", variant, " ", sample.name, " point=", sample.point, " camera=", scene.camera.size)
		if is_instance_valid(inspection_enemy):
			scene.temple_section._remove_actor(inspection_enemy)
			await process_frame
			await process_frame
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for i in 25: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(variant + "-04-sanctuary-960.png"))
	print("CAPTURE: ", variant, " sanctuary960")
	quit()
