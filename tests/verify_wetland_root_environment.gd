extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var scene = load("res://game/deep_wetland_trial.tscn").instantiate()
	root.add_child(scene)
	for i in 4: await physics_frame
	var failures := 0
	var helper = preload("res://game/wetland_root_environment.gd")
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	helper._tube(surface, Vector3.ZERO, Vector3.UP * 2, 1.0, 0.7, Color.WHITE)
	var sample_mesh: ArrayMesh = surface.commit()
	var arrays := sample_mesh.surface_get_arrays(0)
	var first_vertex: Vector3 = arrays[Mesh.ARRAY_VERTEX][0]
	var first_normal: Vector3 = arrays[Mesh.ARRAY_NORMAL][0]
	if Vector3(first_vertex.x, 0, first_vertex.z).dot(first_normal) <= 0:
		printerr("FAIL: root tube lighting normal points inward")
		failures += 1
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
