extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var paths: Array[String] = []
	var before := {}
	for prefix in ["user://loop_conquest_profile", "user://loop_conquest_1d_unlocks"]:
		for suffix in ["_a.json", "_b.json"]:
			var path: String = prefix + suffix
			paths.append(path)
			before[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	var scene = load("res://game/temple_circuit_run.tscn").instantiate()
	scene.profile_save_prefix = "user://circuit_fixture_%d" % Time.get_ticks_usec()
	scene.growth_save_prefix = scene.profile_save_prefix + "_unlocks"
	root.add_child(scene)
	current_scene = scene
	for i in 5: await physics_frame
	var failures := 0
	if scene.player.arena_bounds != scene.CircuitLayout.MAIN_BOUNDS: failures += 1
	if not scene.temple_sanctuary_root.has_node("SteppedSanctuary"): failures += 1
	var court = scene.temple_sanctuary_root.get_node("ReclaimedCourtMasonry")
	if court.get_meta("collision_footprints").size() != 6 or court.get_child_count() != 3: failures += 1
	if scene.navigation.is_open(Vector2(2800, 100), 30): failures += 1
	if scene.BOSS_TIME != 240.0 or scene.profile.load_error: failures += 1
	for p in [scene.start_point, Vector2(2450, 2100), scene.CircuitLayout.RETURN_POINT, scene.temple_section.boss_point, scene.temple_section.retry_point]:
		if not scene.navigation.is_open(p, 30) or scene.navigation.find_path(scene.start_point, p).is_empty():
			printerr("FAIL: candidate run route ", p)
			failures += 1
	scene.temple_section.enter_garden()
	for i in 3: await physics_frame
	if not scene.temple_section.in_garden or scene.player.arena_bounds != scene.CircuitLayout.FIELD_BOUNDS: failures += 1
	scene.temple_section.leave_garden()
	for i in 3: await physics_frame
	if scene.temple_section.in_garden or scene.player.arena_bounds != scene.CircuitLayout.MAIN_BOUNDS: failures += 1
	scene.run_time = 240.0
	for i in 100: await physics_frame
	if not scene.boss_spawned or not is_instance_valid(scene.boss):
		printerr("FAIL: four-minute destination boss")
		failures += 1
	scene.run_currency = 50
	scene._finish_run("RETREAT")
	if scene.settlement_pending or scene.profile.currency != 40:
		printerr("FAIL: candidate retreat settlement")
		failures += 1
	var restored := RunProfile.new()
	restored.save_prefix = scene.profile_save_prefix
	restored.load_state()
	if restored.load_error or restored.currency != 40: failures += 1
	for i in 70: await physics_frame
	for path in paths:
		var after := FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
		if after != before[path]:
			printerr("FAIL: normal save modified")
			failures += 1
	paused = false
	scene.queue_free()
	for i in 3: await process_frame
	print("Temple candidate run: ", failures, " failures; normal saves unchanged")
	quit(1 if failures else 0)
