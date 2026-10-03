extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var output := OS.get_environment("WETLAND_CAPTURE_DIR")
	if output.is_empty() or not "WetlandV44" in OS.get_user_data_dir():
		printerr("FAIL: isolated capture required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var scene = load("res://game/deep_wetland_field.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 5: await physics_frame
	scene.set_physics_process(false)
	scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
	scene.wisp.set_physics_process(false)
	for actor in scene.actors:
		if actor != scene.player: scene.actors[actor].hide()
	var records: Array = []
	for size in [Vector2i(960,540),Vector2i(1280,720)]:
		root.size = size
		root.content_scale_size = Vector2i(1280,720)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		for sample in [{"name":"procession","point":scene.Wetland.PROCESSION},{"name":"face-bank","point":scene.Wetland.FACE_BANK},{"name":"face-approach","point":Vector2(2070,1700)},{"name":"face-side-route","point":Vector2(2070,1100)},{"name":"face-east-bank","point":Vector2(2870,1100)},{"name":"court","point":scene.Wetland.TEMPLE_COURT},{"name":"inner-court","point":scene.Field.INNER_COURT}]:
			scene.teleport(sample.point)
			for i in 45: await process_frame
			scene.set_process(false)
			for i in 5: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("%s-%d.png" % [sample.name,size.x]))
			records.append({"name":sample.name,"width":size.x,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
			scene.set_process(true)
	var file := FileAccess.open(output.path_join("costs.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"samples":records,"scope":"Static isolated same-camera render; no frame-time or human aesthetic claim"},"  "))
	file.close()
	scene.queue_free()
	for i in 3: await process_frame
	quit()
