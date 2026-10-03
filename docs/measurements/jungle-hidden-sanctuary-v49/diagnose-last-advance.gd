extends "res://tests/capture_jungle_hidden_sequence.gd"
## Diagnostic only: explicit setup relocation to the last native reached point.
## Reuses the unchanged capture _walk inputs and follow check for one advance.
## This does not replace normal approach or final native render evidence.
func _run() -> void:
	started = Time.get_ticks_usec()
	if not "JungleHiddenV49" in OS.get_user_data_dir():
		printerr("FAIL: private QA userdata required")
		quit(1)
		return
	Engine.time_scale = 1.0
	scene = load("res://game/jungle_south_circuit.tscn").instantiate()
	scene.profile_save_prefix = "user://advance_diagnostic_%d" % Time.get_ticks_usec()
	scene.growth_save_prefix = scene.profile_save_prefix+"_growth"
	root.add_child(scene)
	current_scene = scene
	for connection in root.focus_exited.get_connections(): root.focus_exited.disconnect(connection.callable)
	scene._set_paused(false)
	scene.practice_mode = true
	scene.wisp.set_physics_process(false)
	for actor in scene.actors:
		if actor != scene.player: actor.set_physics_process(false)
	scene.temple_section.enter_garden()
	scene.temple_section.tick(0.0)
	var from := Vector2(9739.84765625,971.149963378906)
	scene.teleport(from)
	for i in 5: await physics_frame
	print("PHASE: before _walk; source=last native reached point; initial relocation is diagnostic only")
	print("STATE: ",JSON.stringify({"position":[scene.player.position.x,scene.player.position.y],"tree_paused":paused,"arena_paused":scene.paused,"player_physics":scene.player.is_physics_processing(),"move_speed":scene.player.MOVE_SPEED,"multiplier":scene.player.move_speed_multiplier,"navigation_path":Array(scene.navigation.find_path(from,Hidden.ALTAR))}))
	await _walk(Hidden.ALTAR)
	print("PHASE: _walk completed; awaiting same 0.4s settle")
	await create_timer(0.4).timeout
	print("PHASE: settle completed; checking camera/actor follow")
	var record := {}
	_check_follow("last-shrine-lip-to-altar",record)
	var result := {"errors":errors,"initial_setup":"explicit diagnostic relocation to exact last native position; not approach/render evidence","same_capture_walk_implementation":true,"from":[from.x,from.y],"goal":[Hidden.ALTAR.x,Hidden.ALTAR.y],"reached":[scene.player.position.x,scene.player.position.y],"active_seconds":active_seconds,"wall_seconds":(Time.get_ticks_usec()-started)/1000000.0,"follow":record}
	print("DIAGNOSTIC: ",JSON.stringify(result))
	var output_path := OS.get_environment("HIDDEN_ADVANCE_OUTPUT")
	if output_path.is_absolute_path():
		var file := FileAccess.open(output_path,FileAccess.WRITE)
		file.store_string(JSON.stringify(result,"\t"))
	finished = true
	quit(0 if errors.is_empty() else 1)
