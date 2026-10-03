extends SceneTree
## Matched actual-camera snapshots with the current actor and existing warnings.
## Simulation is frozen for comparison; these are not normal runs or art approval.

const Opening = preload("res://game/temple_opening_environment.gd")

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var baseline := OS.get_cmdline_user_args().has("--opening-baseline")
	var output := OS.get_environment("OPENING_CAPTURE_DIR")
	if output.is_empty(): output = "user://opening_temple_captures"
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	var scene = load("res://game/hybrid_region.tscn").instantiate()
	scene.profile_save_prefix = "user://opening_temple_capture_profile"
	scene.growth_save_prefix = "user://opening_temple_capture_unlocks"
	root.add_child(scene)
	current_scene = scene
	for i in 3: await process_frame
	scene.set_physics_process(false)
	scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
	for actor in scene.actors.keys():
		if actor != scene.player: scene.temple_section._remove_actor(actor)
	var opening: Node3D = scene.get_node_or_null("TempleOpeningEnvironment")
	if not baseline and opening == null:
		opening = Opening.build(scene)
		scene.add_child(opening)
	if opening != null: opening.visible = not baseline
	var details: Array[Dictionary] = []
	for size in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = size
		root.content_scale_size = Vector2i(1280, 720)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		for sample in [
			{"name": "01-waterfront-start", "point": Vector2(650, 1870)},
			{"name": "02-south-ramp", "point": Vector2(650, 1670)},
			{"name": "03-raised-court", "point": Vector2(650, 1410)},
			{"name": "04-first-combat", "point": Vector2(650, 1410)},
			{"name": "05-alternate-stones", "point": Vector2(935, 1760)},
			{"name": "06-court-exit", "point": Vector2(1180, 1150)},
		]:
			scene.teleport(sample.point)
			var enemy: TrainingEnemy = null
			if sample.name == "04-first-combat":
				enemy = scene._spawn_enemy_at(Vector2(775, 1325), TrainingEnemy.Role.BEAST, 100)
				enemy.set_physics_process(false)
				enemy.warning_time = 0.4
				enemy.locked_direction = enemy.position.direction_to(scene.player.position)
			for i in 15: await process_frame
			if opening != null: Opening.update_visibility(opening, scene)
			await RenderingServer.frame_post_draw
			var frame := root.get_texture().get_image()
			if frame == null or frame.is_empty():
				printerr("FAIL: real graphical rendering is required")
				quit(1)
				return
			var filename: String = "%s-%s-%dx%d.png" % ["before" if baseline else "after", sample.name, size.x, size.y]
			if frame.save_png(output.path_join(filename)) != OK:
				printerr("FAIL: screenshot save failed")
				quit(1)
				return
			details.append({"file": filename, "point": [sample.point.x, sample.point.y], "resolution": [size.x, size.y], "camera_size": scene.camera.size, "actor_ground_height": scene.terrain.height_at(sample.point), "warning_vertices": scene.warning_vertex_count})
			print("CAPTURE frozen current-actor fixture: ", filename)
			if enemy != null:
				scene.temple_section._remove_actor(enemy)
				await process_frame
	var report := {"fixture": "frozen current actor, fixed temple camera, existing beast warning; no ordinary run, human art/place/fun or GPU acceptance", "engine": Engine.get_version_info().string, "render_method": ProjectSettings.get_setting("rendering/renderer/rendering_method"), "variant": "before" if baseline else "after", "source_sha256": FileAccess.get_sha256("res://game/temple_opening_environment.gd"), "frames": details}
	var file := FileAccess.open(output.path_join("before-context.json" if baseline else "after-context.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	quit()
