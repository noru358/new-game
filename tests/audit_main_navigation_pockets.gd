extends SceneTree
## Read-only geometry diagnostic, not an assertion that all open floor is intended content.
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var summaries := []
	for path in ["res://game/hybrid_region.tscn", "res://game/jungle_pass.tscn", "res://game/temple_circuit_run.tscn"]:
		var scene = load(path).instantiate()
		scene.profile_save_prefix = "user://pocket_audit_%d" % Time.get_ticks_usec()
		scene.growth_save_prefix = scene.profile_save_prefix + "_unlocks"
		root.add_child(scene)
		for i in 3: await physics_frame
		scene.set_physics_process(false)
		var bounds: Rect2 = scene.player.arena_bounds
		var orphans := []
		var disconnected := []
		var open := 0
		for y in range(int(bounds.position.y) + 32, int(bounds.end.y) - 32, 64):
			for x in range(int(bounds.position.x) + 32, int(bounds.end.x) - 32, 64):
				var point := Vector2(x, y)
				if not scene.navigation.is_open(point, 30): continue
				open += 1
				if scene.navigation._nearest_open(scene.navigation._cell_at(point), point).x < 0:
					orphans.append([x, y])
				elif scene.navigation.find_path(scene.start_point, point).is_empty():
					disconnected.append([x, y])
		var entry := {"scene": path, "sampled_open": open, "no_grid_attachment": orphans, "disconnected_from_start": disconnected}
		summaries.append(entry)
		print("NAVIGATION_POCKETS ", JSON.stringify(entry))
		scene.queue_free()
		for i in 3: await process_frame
	var file := FileAccess.open("/tmp/v44-navigation-pockets.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(summaries, "\t"))
	file.close()
	quit()
