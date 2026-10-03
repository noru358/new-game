extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var scene = load("res://game/temple_circuit_trial.tscn").instantiate()
	root.add_child(scene)
	for i in 4: await physics_frame
	var failures := 0
	for route in [scene.Circuit.MAIN_ROUTE, scene.Circuit.WATER_ROUTE]:
		for p in route:
			if not scene.navigation.is_open(p, 30) or scene.navigation.find_path(scene.Circuit.ENTRY, p).is_empty():
				printerr("FAIL: disconnected circuit point ", p)
				failures += 1
	if not scene.growth.growth_ended: failures += 1
	if scene.camera.size != 9.0 or scene.show_practice_controls: failures += 1
	if not scene.player.moving_slash_enabled: failures += 1
	if scene.growth.unlocks.save_prefix == "user://loop_conquest_1d_unlocks": failures += 1
	scene.queue_free()
	for i in 3: await process_frame
	print("Temple circuit: ", failures, " failures; topology candidate only")
	quit(1 if failures else 0)
