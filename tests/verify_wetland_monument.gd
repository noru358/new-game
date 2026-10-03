extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", note)
func _run() -> void:
	var scene = load("res://game/deep_wetland_field.tscn").instantiate()
	var waters = scene.terrain.water_areas.duplicate(true)
	var walls = scene.terrain.wall_areas.duplicate(true)
	root.add_child(scene)
	for i in 4: await physics_frame
	var monument = scene.get_node("MonumentalWetlandFace")
	check(scene.terrain.water_areas == waters and scene.terrain.wall_areas == walls, "unchanged water and collision records")
	check(scene.camera.size == 9.0, "unchanged combat camera")
	check(monument.get_child_count() == 11, "same eleven face parts")
	var top := 0.0
	for node in monument.get_children():
		check(node is MeshInstance3D, "visual mesh only")
		check(node.material_override.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "opaque monument")
		var vertices = node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			var world: Vector3 = node.to_global(vertex)
			top = maxf(top, world.y)
			var p := Vector2(world.x, world.z) * 100.0
			var wet := false
			for water in waters:
				if water.has_point(p): wet = true; break
			check(wet, "mesh vertex above blocked water: " + str(p))
	check(top > 11.0 and top < 11.5, "threefold height candidate")
	print("Wetland monument: ", checks, " checks, ", failures, " failures; height=", top)
	scene.queue_free()
	for i in 3: await process_frame
	quit(1 if failures else 0)
