extends "res://tests/capture_hidden_flow.gd"
## Bounded fixed views of the six changed water meshes. Real portal inputs;
## legal fixed interior poses, frozen pressure, same authored camera. No fun claim.
const Sources = preload("res://game/jungle_waterfall_sources.gd")
const Hidden = preload("res://game/jungle_grotto_layout.gd")

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): output = argument.trim_prefix("--capture-dir=")
	if DisplayServer.get_name() == "headless" or not output.is_absolute_path() or not "WaterfallSourcesV50" in OS.get_user_data_dir():
		printerr("FAIL: native renderer, isolated WaterfallSourcesV50 data and absolute output required")
		quit(1)
		return
	if DirAccess.dir_exists_absolute(output) and not DirAccess.get_files_at(output).is_empty():
		printerr("FAIL: existing evidence cannot be overwritten")
		quit(1)
		return
	check(DirAccess.make_dir_recursive_absolute(output) == OK, "fresh output directory")
	region = "jungle"
	Engine.time_scale = 1.0
	Engine.max_fps = 60
	for size in [Vector2i(960,540),Vector2i(1280,720)]:
		root.size = size
		root.content_scale_size = Vector2i(1280,720)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		width = size.x
		scene = load("res://game/jungle_south_circuit.tscn").instantiate()
		scene.profile_save_prefix = "user://waterfall_capture_%d_%d" % [width,Time.get_ticks_usec()]
		scene.growth_save_prefix = scene.profile_save_prefix+"_growth"
		root.add_child(scene)
		current_scene = scene
		scene.practice_mode = true
		scene.wisp.set_physics_process(false)
		for connection in root.focus_exited.get_connections(): root.focus_exited.disconnect(connection.callable)
		scene._set_paused(false)
		scene.teleport(Hidden.RETURN_POINT)
		await _capture("main-undiscovered",size)
		await _walk_threshold(true)
		await _capture("hidden-arrival",size)
		for sample in [
			{"name":"receiving-pool","point":Hidden.FIRST_APPROACH},
			{"name":"stream-turn","point":Vector2(8190,1530)},
			{"name":"return-pool","point":Vector2(8530,740)},
		]:
			check(scene.navigation.is_open(sample.point,scene.ACTOR_CLEARANCE), "legal fixed water view "+sample.name)
			scene.teleport(sample.point)
			await _capture(sample.name,size)
		# Return to the legal arrival area and walk the real exit contract.
		scene.teleport(Hidden.FIELD_ENTRY)
		await _walk_threshold(false)
		await _capture("main-return",size)
		_release()
		scene.queue_free()
		current_scene = null
		for i in 3: await process_frame
		if failures: break
	check(captures.size() == 12, "six bounded views at each native resolution")
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"engine":Engine.get_version_info().string,"scope":"native960/1280, real entry/exit input, fixed legal interior views/frozen pressure; no natural combat or human visual acceptance"},"\t"))
	print("WATER_SOURCE_RENDER ",JSON.stringify({"checks":checks,"failures":failures,"images":captures.size()}))
	quit(1 if failures else 0)

func _capture(state: String,size: Vector2i) -> void:
	await super._capture(state,size)
	if captures.is_empty(): return
	var visible := []
	for node in scene.temple_section.find_children("*","MeshInstance3D",true,false):
		if Sources.authored(node) and node.is_visible_in_tree(): visible.append(node.get_meta("waterfall_source_id"))
	captures.back()["visible_field_water_ids"] = visible
