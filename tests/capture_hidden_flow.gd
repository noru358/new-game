extends "res://tests/verify_hidden_flow.gd"
## Fixed render fixture: normal input at each threshold, frozen run pressure.
## Baseline can run the same fixture. This is not a natural play/beauty verdict.
var output := ""
var captures := []
var width := 0
var region := ""

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): output = argument.trim_prefix("--capture-dir=")
	if DisplayServer.get_name() == "headless" or output.is_empty() or not output.is_absolute_path() or not "LoopConquestHiddenFlow" in OS.get_user_data_dir():
		printerr("FAIL: real renderer, private HiddenFlow userdata and fresh absolute output required")
		quit(1)
		return
	if DirAccess.dir_exists_absolute(output) and not DirAccess.get_files_at(output).is_empty():
		printerr("FAIL: existing captures are never overwritten")
		quit(1)
		return
	check(DirAccess.make_dir_recursive_absolute(output) == OK, "fresh output")
	Engine.time_scale = 1.0
	Engine.max_fps = 60
	for size in [Vector2i(960,540),Vector2i(1280,720)]:
		root.size = size
		root.content_scale_size = Vector2i(1280,720)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		width = size.x
		for name in ["temple_circuit_run","jungle_south_circuit"]:
			region = "temple" if name == "temple_circuit_run" else "jungle"
			scene = load("res://game/" + name + ".tscn").instantiate()
			scene.profile_save_prefix = "user://render_hidden_%s_%d_%d" % [region,width,Time.get_ticks_usec()]
			scene.growth_save_prefix = scene.profile_save_prefix + "_growth"
			root.add_child(scene)
			current_scene = scene
			scene.practice_mode = true
			scene.wisp.set_physics_process(false)
			await physics_frame
			# Identical fixed-fixture policy on both sources. Product pause behavior
			# and the user's other apps are untouched; this is not a focus test.
			for connection in root.focus_exited.get_connections(): root.focus_exited.disconnect(connection.callable)
			scene._set_paused(false)
			var section = scene.temple_section
			var layout = section.layout
			scene.teleport(layout.RETURN_POINT)
			await _capture("main-undiscovered",size)
			await _walk_threshold(true)
			await _capture("hidden-arrival",size)
			var inward: Vector2 = layout.EXIT_TRIGGER.get_center().direction_to(layout.FIELD_ENTRY)
			await _walk(layout.FIELD_ENTRY + inward * 340.0)
			await _capture("hidden-away",size)
			scene.overview = true
			scene.camera.size = scene.overview_camera_size
			await _capture("hidden-overview",size)
			scene.overview = false
			scene.camera.size = scene.combat_camera_size
			var edge: Vector2 = layout.FIELD_ENTRY.clamp(layout.EXIT_TRIGGER.position,layout.EXIT_TRIGGER.end)
			await _walk(edge + inward * 55.0)
			await _capture("exit-approach",size)
			await _walk_threshold(false)
			await _capture("main-return",size)
			_release()
			scene.queue_free()
			await process_frame
			if failures: break
		if failures: break
	check(captures.size() == 24, "all24 rendered states captured")
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"scope":"real native renderer, normal threshold inputs, fixed setup, frozen combat/time; no human play"},"\t"))
	print("HIDDEN_RENDER ",JSON.stringify({"checks":checks,"failures":failures,"images":captures.size()}))
	quit(1 if failures else 0)

func _step() -> void:
	await super._step()
	# Preserve real authored hidden spawns, but freeze them before any action.
	for actor in scene.actors:
		if actor != scene.player: actor.set_physics_process(false)

func _walk(goal: Vector2) -> void:
	var path: PackedVector2Array = scene.navigation.find_path(scene.player.position,goal)
	check(not path.is_empty(), "legal capture approach")
	for target in path:
		var frames := 0
		while scene.player.position.distance_to(target) > 10.0 and frames < 300:
			_press(scene.player.position.direction_to(target))
			await _step()
			frames += 1
		check(frames < 300, "capture walk finishes at normal speed")
	_release()

func _capture(state: String, size: Vector2i) -> void:
	_release()
	var section = scene.temple_section
	for frame in 80: await _step()
	section.tick(0)
	scene._update_hud()
	scene._update_run_hud()
	var hud = scene.get_node("RunFlowHudPresenter")
	hud.refresh()
	var corrected: bool = section.has_method("discovery_marker")
	var label: Label3D
	for candidate in section.find_children("*","Label3D",true,false):
		if candidate.text in ["회랑으로","정글로"]: label = candidate
	var marker := {}
	if corrected: marker = section.discovery_marker()
	elif scene.is_place_discovered("TEMPLE_GARDEN" if region == "temple" else "JUNGLE_GROTTO"):
		marker = {"point":(Vector2(8300,480) if section.in_garden else Vector2(3120,250)) if region == "temple" else (Vector2(8870,440) if section.in_garden else Vector2(1300,685))}
	var record := {"region":region,"width":width,"state":state,"point":[scene.player.position.x,scene.player.position.y],"inside":section.in_garden,"exit_visible":label.is_visible_in_tree(),"exit_raw_visible":label.visible,"hud":hud.objective.text,"boss_clock":hud.boss_clock.text,"marker":[] if marker.is_empty() else [marker.point.x,marker.point.y],"camera_size":scene.camera.size,"corrected_source":corrected}
	if corrected:
		check(label.is_visible_in_tree() == (state in ["hidden-arrival","exit-approach"]), state+" near/field/overview exit visibility")
		if not marker.is_empty(): check(marker.point == (section.layout.ALTAR if section.in_garden else section.layout.ENTRY_TRIGGER.get_center()), state+" correct map anchor")
		if state == "main-undiscovered": check(marker.is_empty(), "no undiscovered spoiler")
	if label.is_visible_in_tree():
		var screen: Vector2 = scene.camera.unproject_position(label.global_position)
		record["label_screen"]=[screen.x,screen.y]
		if corrected or state in ["hidden-arrival", "exit-approach"]:
			check(not scene.camera.is_position_behind(label.global_position) and root.get_visible_rect().has_point(screen), state+" exit anchor within actual viewport")
	if not scene.overview:
		check(scene.camera.position.distance_to(scene.terrain.world_point(scene.player.position,35)+scene.camera_offset) < 0.03, state+" normal camera settled")
	check(scene.actors[scene.player].position.distance_to(scene.terrain.world_point(scene.player.position)) < 0.03, state+" real actor visual follows physics")
	check(hud.boss_clock.visible and hud.boss_clock.text == "보스까지 04:00", state+" boss240 clock preserved")
	await process_frame
	await RenderingServer.frame_post_draw
	var bitmap := root.get_texture().get_image()
	check(bitmap.get_size() == size, state+" actual960/1280 pixels")
	var filename := "%s-%d-%s.png" % [region,width,state]
	check(bitmap.save_png(output.path_join(filename)) == OK, "write"+filename)
	record["file"] = filename
	captures.append(record)
