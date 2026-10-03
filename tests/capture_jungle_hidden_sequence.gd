extends "res://tests/capture_regional_landmarks.gd"
## Pinned v48/candidate normal-speed input, actual section transport, same
## actor/tell/water conditions. Pressure frozen. No natural-play/fun claim.
const Hidden = preload("res://game/jungle_grotto_layout.gd")

func _run() -> void:
	started = Time.get_ticks_usec()
	output = OS.get_environment("REGIONAL_LANDMARK_OUTPUT")
	region = "jungle"
	measure_only = OS.get_cmdline_user_args().has("--measure-only")
	if not output.is_absolute_path() or not "JungleHiddenV49" in OS.get_user_data_dir():
		printerr("FAIL: private JungleHiddenV49 userdata and absolute evidence path required")
		quit(1)
		return
	if DirAccess.dir_exists_absolute(output) and not DirAccess.get_files_at(output).is_empty():
		printerr("FAIL: fresh evidence path required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	if not measure_only and (DisplayServer.get_name() == "headless" or RenderingServer.get_video_adapter_name().is_empty()):
		errors.append("Real renderer required for PNG evidence")
		await _finish()
		return
	Engine.time_scale = 1.0
	Engine.max_fps = 60
	var samples := _samples()
	expected_screenshots = 0 if measure_only else SIZES.size()*samples.size()*2
	for size in SIZES:
		root.mode = Window.MODE_WINDOWED
		root.size = size
		root.content_scale_size = Vector2i(1280,720)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		for i in 5: await process_frame
		scene = load("res://game/jungle_south_circuit.tscn").instantiate()
		scene.profile_save_prefix = "user://hidden_walk_%d_%d" % [size.x,Time.get_ticks_usec()]
		scene.growth_save_prefix = scene.profile_save_prefix+"_growth"
		root.add_child(scene)
		current_scene = scene
		# Identical frozen-pressure fixture policy in both variants. Product pause
		# code, OS focus and the user's app are untouched; this is not focus testing.
		for connection in root.focus_exited.get_connections(): root.focus_exited.disconnect(connection.callable)
		scene._set_paused(false)
		scene.practice_mode = true
		scene.wisp.set_physics_process(false)
		for actor in scene.actors:
			if actor != scene.player: actor.set_physics_process(false)
		for i in 5: await physics_frame
		for sample in samples:
			var section = scene.temple_section
			if sample.get("transition","") == "enter":
				if not Hidden.ENTRY_TRIGGER.has_point(scene.player.position): errors.append("Normal input did not reach real entrance trigger")
				section.tick(0.0)
				if not section.in_garden: errors.append("Real section entrance failed")
			elif sample.get("transition","") == "leave":
				if not Hidden.EXIT_TRIGGER.has_point(scene.player.position): errors.append("Normal input did not reach real exit trigger")
				section.tick(1.0) # elapsed normal walk exceeds the existing 0.8s cooldown
				if section.in_garden: errors.append("Real section return failed")
			if not errors.is_empty(): break
			if not scene.navigation.is_open(sample.point,30) or not scene.player.arena_bounds.has_point(sample.point):
				errors.append("Blocked requested viewpoint "+sample.name+" "+str(sample.point))
				break
			var active_start := active_seconds
			await _walk(sample.point)
			await create_timer(0.4).timeout
			var record := {"name":sample.name,"width":size.x,"height":size.y,"target":_point(sample.point),"reached":_point(scene.player.position),"active_walk_seconds":active_seconds-active_start,"render":false,"approach":"normal movement inputs; actual entrance/return transport only","focus_policy":"fixture focus-exit pause disconnected equally; no product/focus validation","camera_size":scene.camera.size,"camera_offset":[scene.camera_offset.x,scene.camera_offset.y,scene.camera_offset.z],"move_speed":scene.player.MOVE_SPEED,"move_speed_multiplier":scene.player.move_speed_multiplier,"run_time_frozen":scene.run_time,"in_hidden":section.in_garden}
			_check_follow(sample.name,record)
			if errors.is_empty() and not measure_only: await _capture_checkpoint(sample.name,size.x,record)
			records.append(record)
			print("CHECKPOINT: ",JSON.stringify(record))
			if not errors.is_empty(): break
		await _free_scene()
		if not errors.is_empty(): break
	await _finish()

func _image() -> Image:
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image()
	if result == null or result.is_empty():
		errors.append("Renderer produced no image")
		return null
	if result.get_size() != root.size:
		errors.append("Rendered image size %s != test window %s; mode=%s; screen=%s" % [result.get_size(),root.size,root.mode,root.current_screen])
		return null
	return result

func _samples() -> Array:
	return [
		{"name":"01-main-waterfall","point":Hidden.RETURN_POINT},
		{"name":"02-real-entrance","point":Hidden.ENTRY_TRIGGER.get_center()},
		{"name":"03-hidden-arrival","point":Hidden.FIELD_ENTRY,"transition":"enter"},
		{"name":"04-cave-threshold","point":Vector2(6700,2630)},
		{"name":"05-first-opening","point":Vector2(7140,2520)},
		{"name":"06-receiving-clearing","point":Hidden.FIRST_APPROACH},
		{"name":"07-pool-bypass","point":Vector2(7490,1430)},
		{"name":"08-stream-turn","point":Vector2(8190,1530)},
		{"name":"09-inner-approach","point":Hidden.SECOND_APPROACH},
		{"name":"10-shrine-lip","point":Vector2(9740,970)},
		{"name":"11-root-sanctuary","point":Hidden.ALTAR},
		{"name":"12-west-return","point":Vector2(8950,440)},
		{"name":"13-return-pool","point":Vector2(8530,740)},
		{"name":"14-root-passage","point":Vector2(7630,740)},
		{"name":"15-return-turn","point":Vector2(6790,1100)},
		{"name":"16-same-mouth","point":Vector2(6500,1920)},
		{"name":"17-real-exit","point":Hidden.EXIT_TRIGGER.get_center()},
		{"name":"18-main-return","point":Hidden.RETURN_POINT,"transition":"leave"},
	]

func _capture_checkpoint(label: String,width: int,record: Dictionary) -> void:
	for tag in scene.find_children("*","Label3D",true,false): tag.hide()
	var enemy: TrainingEnemy
	if label in ["06-receiving-clearing","10-shrine-lip"]:
		var point: Vector2 = Hidden.FIRST_WAVE[0] if label == "06-receiving-clearing" else Hidden.SECOND_WAVE[2]
		enemy = scene._spawn_enemy_at(point,TrainingEnemy.Role.BEAST,40.0)
		enemy.set_physics_process(false)
		enemy.warning_time = 0.3
		enemy.locked_direction = point.direction_to(scene.player.position)
		for i in 3: await process_frame
		scene._draw_enemy_warnings(1.0)
		record["fixed_enemy_tell"] = {"point":_point(point),"warning_surfaces":scene.warning_mesh.get_surface_count(),"scope":"same fixed actor/attack tell in both variants; no combat AI or difficulty claim"}
		if scene.warning_mesh.get_surface_count() == 0: errors.append("Actual attack tell missing at "+label)
	# Raw Body differential retains FX overlap. The second measure leaves the same
	# actors/tells in its reference, isolating scenery without dismissing raw data.
	await super._capture_checkpoint(label,width,record)
	if is_instance_valid(enemy):
		scene.set_process(false)
		scene.set_physics_process(false)
		scene.player.set_physics_process(false)
		record["player_same_fx_visibility"] = await _geometry_visibility(scene.actors[scene.player].get_node("Body"),80,label+"-same-fx-player",width)
		record["enemy_body_visibility"] = await _geometry_visibility(scene.actors[enemy].get_node("Body"),80,label+"-enemy",width)
		record["tell_visibility"] = await _geometry_visibility(scene.warning_visual,180,label+"-tell",width,scene.terrain.world_point(enemy.position))
		scene.player.set_physics_process(true)
		scene.set_process(true)
		scene.set_physics_process(true)
		scene.actors[enemy].queue_free()
		scene.actors.erase(enemy)
		scene.actor_motion.erase(enemy)
		enemy.queue_free()
		for i in 3: await process_frame

func _walk(goal: Vector2) -> void:
	await super._walk(goal)
	# Native shader/window startup can consume the fixed wall-time wait before
	# enough physics follow steps have run. Let the normal follow settle itself;
	# never set camera transforms or teleport to make a capture assertion pass.
	for frame in 120:
		var expected: Vector3 = scene.terrain.world_point(scene.player.position,35) + scene.camera_offset
		if scene.camera.position.distance_to(expected) < 0.01: return
		await physics_frame
	errors.append("Normal camera follow did not settle within120 physics frames")


func _geometry_visibility(geometry: GeometryInstance3D, radius: int, label: String, width: int, at: Vector3 = Vector3.INF) -> Dictionary:
	var normal := await _image()
	geometry.hide()
	var normal_without := await _image()
	geometry.show()
	var hidden: Array[GeometryInstance3D] = []
	for node in scene.find_children("*","GeometryInstance3D",true,false):
		if node == scene.warning_visual or not node.visible: continue
		var actor_geometry := false
		for actor in scene.actors.values():
			if actor.is_ancestor_of(node): actor_geometry = true
		if actor_geometry: continue
		hidden.append(node)
		node.hide()
	var reference := await _image()
	geometry.hide()
	var reference_without := await _image()
	geometry.show()
	for node in hidden: node.show()
	if normal == null or normal_without == null or reference == null or reference_without == null: return {}
	expected_screenshots += 1
	_save(reference,"%s-reference-%d.png" % [label,width])
	var logical_rect: Rect2 = scene.camera.get_viewport().get_visible_rect()
	var center: Vector2 = (scene.camera.unproject_position(geometry.global_position if at == Vector3.INF else at) - logical_rect.position) * Vector2(normal.get_size()) / logical_rect.size
	var roi := Rect2i(Vector2i(center) - Vector2i(radius,radius),Vector2i(radius*2,radius*2)).intersection(Rect2i(Vector2i.ZERO,normal.get_size()))
	var potential := 0
	var visible := 0
	for y in range(roi.position.y,roi.end.y):
		for x in range(roi.position.x,roi.end.x):
			if _different(reference.get_pixel(x,y),reference_without.get_pixel(x,y)):
				potential += 1
				if _different(normal.get_pixel(x,y),normal_without.get_pixel(x,y)): visible += 1
	if potential < 50: errors.append("Unusable Body/telegraph pixel reference at " + label)
	return {"reference_pixels":potential,"normal_pixels":visible,"ratio":float(visible)/maxf(1.0,potential),"roi":[roi.position.x,roi.position.y,roi.size.x,roi.size.y],"scope":"fixed real enemy Body/telegraph differential, scenery hidden reference with same actors; bounded sample"}
