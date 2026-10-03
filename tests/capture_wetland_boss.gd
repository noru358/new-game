extends SceneTree
var output := ""
var reports: Array = []
func _initialize() -> void: call_deferred("_run")
func _release() -> void:
	for action in ["move_left","move_right","move_up","move_down","attack","moving_slash"]: Input.action_release(action)
func _run() -> void:
	output=OS.get_environment("WETLAND_CAPTURE_DIR")
	if output.is_empty() or not "WetlandV44" in OS.get_user_data_dir():
		printerr("FAIL: isolated rendered combat fixture required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	for size in [Vector2i(960,540),Vector2i(1280,720)]:
		root.size=size
		root.content_scale_size=Vector2i(1280,720)
		root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		var scene=load("res://game/wetland_boss_trial.tscn").instantiate()
		root.add_child(scene)
		current_scene=scene
		for i in 5: await physics_frame
		scene.teleport(Vector2(4750,1450))
		scene._physics_process(0.0)
		# Explicit phase-two fixture after encounter entry; not a natural phase transition.
		await physics_frame
		if size.x==1280: scene.trial_boss.take_hit(900,Vector2.ZERO,false)
		var route := [Vector2(5250,1450),Vector2(5250,800),Vector2(4770,800),Vector2(4750,1450)]
		var target_index := 0
		var captured_warning := false
		var captured_active := false
		var started := Time.get_ticks_msec()
		var frames := 0
		while Time.get_ticks_msec()-started<12000 and not scene.trial_finished:
			if scene.player.position.distance_to(route[target_index])<40: target_index=(target_index+1)%route.size()
			var direction: Vector2=scene.player.position.direction_to(route[target_index]).rotated(-scene.player.input_rotation)
			_release()
			if direction.x< -0.2: Input.action_press("move_left",-direction.x)
			if direction.x>0.2: Input.action_press("move_right",direction.x)
			if direction.y< -0.2: Input.action_press("move_up",-direction.y)
			if direction.y>0.2: Input.action_press("move_down",direction.y)
			Input.action_press("attack")
			if frames%100==0: Input.action_press("moving_slash")
			await physics_frame
			frames+=1
			var name := ""
			for zone in get_nodes_in_group("enemy_zones"):
				if zone.warning_time>0 and not captured_warning and Time.get_ticks_msec()-started>500:
					name="warning";captured_warning=true;break
				if zone.warning_time<=0 and not captured_active:
					name="active";captured_active=true;break
			if not name.is_empty():
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output.path_join("%s-%d.png"%[name,size.x]))
		_release()
		reports.append({"width":size.x,"phase_two_forced":size.x==1280,"wall_ms":Time.get_ticks_msec()-started,"frames":frames,"health":scene.player.health,"attacks_started":scene.trial_boss.attacks_started,"attacks_fired":scene.trial_boss.attacks_fired,"warning_capture":captured_warning,"active_capture":captured_active})
		if not captured_warning or not captured_active or scene.trial_boss.attacks_fired<2:
			printerr("FAIL: boss warning/activation not observed")
			quit(1)
			return
		scene.queue_free()
		for i in 4: await process_frame
	var file:=FileAccess.open(output.path_join("combat.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(reports,"  "))
	file.close()
	print("Wetland boss rendered input samples: ",JSON.stringify(reports))
	quit()
