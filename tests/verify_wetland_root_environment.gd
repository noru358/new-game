extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var scene = load("res://game/deep_wetland_trial.tscn").instantiate()
	root.add_child(scene)
	for i in 4: await physics_frame
	var failures := 0
	var helper = preload("res://game/wetland_root_environment.gd")
	for point in helper.CLUSTERS:
		for i in 16:
			var angle := float(i) * TAU / 16.0
			var sample: Vector2 = point + Vector2(cos(angle), sin(angle)) * helper.ROOT_RADIUS
			var in_water := false
			for water in scene.terrain.water_areas:
				if water.has_point(sample): in_water = true
			if not in_water:
				printerr("FAIL: root extends onto dry movement bank ", sample)
				failures += 1
	var visual = scene.get_node("SubmergedRootGroves")
	if visual.get_child_count() != 2: failures += 1
	for mesh in visual.get_children():
		if mesh.mesh.get_surface_count() != 1: failures += 1
	print("Wetland root groves: ", failures, " failures; two visual batches; submerged footprint only")
	scene.queue_free()
	for i in 3: await process_frame
	quit(1 if failures else 0)
