extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene = load("res://game/canal_city_trial.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var output := OS.get_environment("CANAL_CAPTURE_DIR")
	if output.is_empty(): output = "user://canal_city_captures"
	DirAccess.make_dir_recursive_absolute(output)
	for name in ["01-entry", "02-market", "03-waterfront", "04-overview", "05-combat"]:
		scene.teleport(scene.CityTerrain.ENTRY if name == "01-entry" else scene.CityTerrain.MARKET if name == "02-market" else scene.CityTerrain.WATERFRONT)
		scene.overview = name == "04-overview"
		scene.camera.size = scene.overview_camera_size if scene.overview else scene.combat_camera_size
		if name == "05-combat": scene.set_combat_enabled(true)
		for i in 100: await process_frame
		await RenderingServer.frame_post_draw
		var capture := root.get_texture().get_image()
		if capture == null or capture.is_empty():
			printerr("FAIL: real rendering required; no capture available")
			quit(1)
			return
		capture.save_png(output.path_join(name + ".png"))
		print("CAPTURE: ", output.path_join(name + ".png"))
	scene.set_combat_enabled(false)
	scene.teleport(scene.CityTerrain.MARKET)
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for i in 40: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("06-market-960x540.png"))
	print("CAPTURE: ", output.path_join("06-market-960x540.png"))
	root.size = Vector2i(1280, 720)
	for sample in [{"name": "08-warehouse", "point": scene.CityTerrain.WAREHOUSE}, {"name": "09-market-street", "point": Vector2(1660, 1380)}]:
		scene.teleport(sample.point)
		for i in 40: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(sample.name + ".png"))
		print("CAPTURE: ", output.path_join(sample.name + ".png"))
	scene.teleport(scene.CityTerrain.MARKET)
	scene.set_combat_enabled(true)
	for i in 100: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("10-market-combat.png"))
	print("CAPTURE: ", output.path_join("10-market-combat.png"))
	scene.set_combat_enabled(false)
	root.size = Vector2i(960, 540)
	scene._return_to_camp()
	for i in 20: await process_frame
	current_scene.preparation.open_section(0)
	current_scene.preparation.show()
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("07-camp-960x540.png"))
	print("CAPTURE: ", output.path_join("07-camp-960x540.png"))
	quit()
