extends SceneTree
## Geometry/route contract. Human beauty, place identity and fun remain unverified.
const Composition = preload("res://game/temple_place_composition.gd")
const Kit = preload("res://game/temple_environment_kit.gd")
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		if failures < 25: printerr("FAIL: ", message)
func _run() -> void:
	var data := OS.get_user_data_dir()
	var xdg := OS.get_environment("XDG_DATA_HOME")
	# The existing Linux aggregate runner gives every fixture a fresh XDG root.
	var isolated := "TemplePlaceV49" in data or (OS.get_name() == "Linux" and xdg.is_absolute_path() and data.begins_with(xdg.trim_suffix("/") + "/"))
	if not isolated:
		printerr("FAIL: independent TemplePlaceV49 userdata required before scene creation")
		quit(1)
		return
	var scene = load("res://game/temple_circuit_run.tscn").instantiate()
	scene.profile_save_prefix = "user://composition_fixture_profile"
	scene.growth_save_prefix = "user://composition_fixture_growth"
	root.add_child(scene)
	for i in 4: await physics_frame
	scene.set_physics_process(false)
	scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
	var places: Node3D = scene.temple_sanctuary_root.get_node("TemplePlaceComposition")
	check(places.global_transform.is_equal_approx(Transform3D.IDENTITY), "new place geometry uses unchanged map coordinates")
	check(places.get_child_count() == 3, "three batched meshes across whole route")
	var floor: MeshInstance3D = places.get_node("ProcessionalAndCloisterCourses")
	# Course joins must be a disjoint surface union, not overlapping tinted quads.
	# A positive-area overlap at the same ground lift produces native depth flicker.
	var floor_vertices: PackedVector3Array = floor.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var course_bounds: Array[Rect2] = []
	for start in range(0,floor_vertices.size(),6):
		var bounds := Rect2(Vector2(floor_vertices[start].x,floor_vertices[start].z) * 100.0,Vector2.ZERO)
		for offset in 6:
			bounds = bounds.expand(Vector2(floor_vertices[start+offset].x,floor_vertices[start+offset].z) * 100.0)
		for existing in course_bounds:
			var overlap := bounds.intersection(existing)
			check(overlap.size.x < 0.01 or overlap.size.y < 0.01, "no coplanar course overlap " + str(overlap))
		course_bounds.append(bounds)
	var triangles: Array = []
	for mesh in places.get_children():
		check(mesh.material_override.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "opaque " + mesh.name)
		check(mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "low courses do not create false obstacle shadows")
		triangles.append([mesh, mesh.mesh.generate_triangle_mesh()])
		var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			var point := Vector2(vertex.x,vertex.z) * 100.0
			if mesh == floor:
				check(is_equal_approx(vertex.y * 100.0 - scene.terrain.height_at(point), Composition.FLOOR_LIFT), "courses follow existing ground below actor/shadow")
				check(scene.navigation.is_open(point, 0), "courses do not paint over obstacles")
			else:
				var in_water := false
				for water in scene.terrain.water_areas:
					if water.grow(0.01).has_point(point): in_water = true
				check(in_water, "solid traces contained in existing nonwalkable water")
				check(vertex.y >= 0 and vertex.y <= 0.09001, "new bank silhouette stays low")
	# Paving is strictly above both current plain floors and the old raised courses.
	check(Composition.FLOOR_LIFT > 0.7 and Composition.FLOOR_LIFT > 0.65, "separated floor depth avoids coplanar surfaces")
	var shadow = scene.actors[scene.player].get_node("Shadow")
	var shadow_bottom: float = shadow.position.y - shadow.mesh.height * 0.5
	check(Composition.FLOOR_LIFT * 0.01 < shadow_bottom - 0.0005, "walkable courses stay beneath actual ground shadow")
	check(scene.BOSS_TIME == 240.0 and scene.camera.size == 9.0 and scene.camera_offset == Vector3(14,13.864,14), "boss and camera contracts")
	check(scene.CircuitLayout.ENTRY_TRIGGER == Rect2(1160,730,110,110) and scene.CircuitLayout.RETURN_POINT == Vector2(1310,920), "hidden transition/return preserved")
	check(scene.temple_section.boss_area == Rect2(2380,250,900,850) and scene.temple_section.boss_point == Vector2(2800,620), "boss boundary preserved")
	var route: Array = scene.terrain.MAIN_ROUTE.duplicate()
	route.append_array(scene.terrain.WATER_ROUTE)
	route.append_array([scene.CircuitLayout.RETURN_POINT, scene.temple_section.retry_point])
	for point in route:
		check(scene.navigation.is_open(point,30) and not scene.navigation.find_path(scene.start_point,point).is_empty(), "preserved route " + str(point))
	# Compare replaced wall visuals against their old complete masonry, rather than
	# silently classifying an existing wall occlusion as a new art regression.
	var baseline := Node3D.new()
	root.add_child(baseline)
	var builder = Kit.new()
	for surface in [builder._stone,builder._growth]: surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var index := 0
	for wall in scene.terrain.wall_areas:
		if not wall.get("circuit_masonry",false): continue
		builder._gallery_fragment(wall.area,0.0,wall.height,index)
		builder._reclaim_edges(wall.area,0.0,wall.height,index)
		index += 1
	builder._finish_batch(baseline,builder._stone,"Masonry",0,true)
	builder._finish_batch(baseline,builder._growth,"Growth",2,false)
	var old_triangles: Array = []
	for mesh in baseline.get_children(): old_triangles.append([mesh,mesh.mesh.generate_triangle_mesh()])
	for mesh in scene.temple_sanctuary_root.get_node("ReclaimedCourtMasonry").get_children():
		if mesh.name != "CourtAndStairCourses": triangles.append([mesh,mesh.mesh.generate_triangle_mesh()])
	var regressions := 0
	var rays := 0
	var old_blocked := 0
	var direction: Vector3 = scene.camera.global_basis.z * 40.0
	# Dense ring-path shoulders, not just waypoint centers; upper body and feet.
	for x in range(800,3601,65):
		for y in range(720,3001,65):
			var point := Vector2(x,y)
			if not scene.navigation.is_open(point,30): continue
			for lift in [30.0,65.0,95.0,150.0]:
				var at: Vector3 = scene.terrain.world_point(point,lift)
				var old := hit(old_triangles,at,at + direction)
				var current := hit(triangles,at,at + direction)
				rays += 1
				if old: old_blocked += 1
				if current and not old: regressions += 1
				check(not current or old, "new ring-path actor obstruction at " + str(point))
	print("Temple place composition: ",checks," checks, ",failures," failures; rays=",rays,"; old_wall_occlusion_rays=",old_blocked,"; new_obstruction_rays=",regressions,". Not aesthetic/fun acceptance.")
	baseline.queue_free()
	scene.queue_free()
	for i in 3: await process_frame
	quit(1 if failures else 0)
func hit(specs: Array, a: Vector3, b: Vector3) -> bool:
	for pair in specs:
		var mesh: MeshInstance3D = pair[0]
		var from := mesh.to_local(a)
		var to := mesh.to_local(b)
		if mesh.get_aabb().intersects_segment(from,to) != null and not pair[1].intersect_segment(from,to).is_empty(): return true
	return false
