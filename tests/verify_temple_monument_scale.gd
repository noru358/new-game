extends SceneTree
const Study = preload("res://game/temple_monument_scale.gd")
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		if failures < 30: printerr("FAIL: ", note)
func _run() -> void:
	var scene = load("res://game/temple_circuit_run.tscn").instantiate()
	scene.profile_save_prefix = "user://monument_fixture"
	scene.growth_save_prefix = "user://monument_fixture_growth"
	root.add_child(scene)
	for i in 4: await physics_frame
	scene.set_physics_process(false)
	scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
	var backdrop: Node3D = scene.temple_sanctuary_root
	var envelope := AABB()
	var first := true
	var triangles := []
	var baseline_triangles := []
	var baseline := Node3D.new()
	baseline.position = Vector3(-25.2,0,-12.1)
	root.add_child(baseline)
	var builder = preload("res://game/temple_sanctuary_environment.gd").new()
	for surface in [builder._stone,builder._paving,builder._growth,builder._threshold]: surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder._shrine()
	builder._finish_batch(baseline,builder._stone,"Stone",0,true)
	builder._finish_batch(baseline,builder._growth,"Moss",2,false)
	for mesh in baseline.get_children(): baseline_triangles.append([mesh,mesh.mesh.generate_triangle_mesh()])
	for label in ["SteppedSanctuary", "AttachedMoss", "SanctuaryEntranceApron/LowApronAndEntrance"]:
		var mesh: MeshInstance3D = backdrop.get_node(label)
		check(mesh.material_override.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "opaque " + label)
		triangles.append([mesh, mesh.mesh.generate_triangle_mesh()])
		var arrays: Array = mesh.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in range(0, vertices.size(), 3):
			var cross := (vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i])
			check(cross.length() > 0.0000001, "nondegenerate transformed triangle")
			check(normals[i].is_finite() and normals[i].dot(cross.normalized()) > 0.999, "recomputed geometric normal")
		for vertex in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var world := mesh.to_global(vertex)
			if first: envelope = AABB(world, Vector3.ZERO); first = false
			else: envelope = envelope.expand(world)
			var point := Vector2(world.x, world.z) * 100.0
			var blocked := point.y < 0.0
			for wall in scene.terrain.wall_areas:
				if wall.area.grow(0.1).has_point(point): blocked = true; break
			check(blocked, "vertex inside wall union or off-map " + str(point))
	check(absf(envelope.size.x * 100 - 775.2) < 0.1, "actual width")
	check(absf(envelope.end.y * 100 - Study.HEIGHT) < 0.1, "actual height")
	check(absf(envelope.end.z * 100 - 240.0) < 0.1, "apron front remains 240")
	# Collider interiors have actual mass;14-unit inset excludes authored chamfer corners.
	for area in [Study.FOOTPRINT, Study.NORTH_FOOTPRINT]:
		for x in range(ceili(area.position.x + 14), floori(area.end.x - 13), 20):
			for y in range(ceili(area.position.y + 14), floori(area.end.y - 13), 10):
				check(ray_hit(triangles,Vector3(x*0.01,-0.1,y*0.01),Vector3(x*0.01,8,y*0.01)), "physical mass covers barrier interior " + str(Vector2(x,y)))
	var reference_court = preload("res://game/temple_circuit_environment.gd")._build_court(scene)
	for mesh in reference_court.get_children():
		var actual: MeshInstance3D = backdrop.get_node("ReclaimedCourtMasonry").get_node(NodePath(mesh.name))
		check(actual.mesh.surface_get_arrays(0) == mesh.mesh.surface_get_arrays(0), "court geometry not modified")
	reference_court.free()
	for label in ["ReclaimedCourtMasonry", "FarBankGroves"]:
		var node: Node3D = backdrop.get_node(label)
		check(node.global_transform.is_equal_approx(Transform3D.IDENTITY), "no scale/placement leak " + label)
	check(scene.camera.size == 9.0 and scene.camera_offset == Vector3(14,13.864,14), "camera unchanged")
	var routes: Array = scene.terrain.MAIN_ROUTE.duplicate()
	routes.append_array(scene.terrain.WATER_ROUTE)
	routes.append_array([scene.temple_section.boss_point, scene.temple_section.retry_point, scene.CircuitLayout.RETURN_POINT])
	for point in routes:
		check(scene.navigation.is_open(point, 30), "route open " + str(point))
		check(not scene.navigation.find_path(scene.start_point, point).is_empty(), "route reachable " + str(point))
	# Sample every 10 map units on north shoulders and boss floor, at actor body heights.
	# Include unchanged court geometry in both sets; do not count its existing occlusion as new.
	for mesh in backdrop.get_node("ReclaimedCourtMasonry").get_children():
		var pair := [mesh,mesh.mesh.generate_triangle_mesh()]
		triangles.append(pair)
		baseline_triangles.append(pair)
	var ray_count := 0
	var baseline_blocked := 0
	var regressions := 0
	var blocked_rays := 0
	var reachable := 0
	var direction: Vector3 = scene.camera.global_basis.z * 40.0
	for x in range(2000, 3561, 10):
		for y in range(30, 1101, 10):
			var point := Vector2(x,y)
			if not scene.navigation.is_open(point, 30): continue
			reachable += 1
			check(not Rect2(2572,0,456,240).grow(29.99).has_point(point), "no newly opened rear pocket")
			for height in [5.0, 30.0, 65.0, 95.0, 150.0, 250.0]:
				var target: Vector3 = scene.terrain.world_point(point, height)
				ray_count += 1
				var hit := ray_hit(triangles,target,target+direction)
				var old_hit := ray_hit(baseline_triangles,target,target+direction)
				if hit: blocked_rays += 1
				if old_hit: baseline_blocked += 1
				if hit and not old_hit: regressions += 1
				check(not hit or old_hit, "new north/boss actor obstruction " + str(point) + " h=" + str(height))
	print("Temple monument: ", checks, " checks, ", failures, " failures; bounds=", envelope, "; reachable=", reachable, "; rays=", ray_count, "; blocked=", blocked_rays, "; baseline_blocked=",baseline_blocked,"; regressions=",regressions)
	# Use exact authored doorway vertices transformed by the candidate mesh.

	for resolution in [Vector2i(1280,720), Vector2i(960,540)]:
		root.size = resolution
		for i in 3: await process_frame
		for sample in [["arrival",Vector2(2800,900)],["sanctuary",Vector2(2800,460)],["boss",Vector2(2800,620)],["threshold",Vector2(2650,1000)],["west-side",Vector2(2270,660)]]:
			scene.teleport(sample[1])
			var screen_points := []
			var visible := 0
			for source in [Vector3(5175,220,1390),Vector3(5280,220,1390),Vector3(5175,400,1390),Vector3(5280,400,1390)]:
				var pixel: Vector2 = scene.camera.unproject_position(backdrop.to_global(Study.transformed(source * 0.01))) * Vector2(resolution) / root.get_visible_rect().size
				screen_points.append(pixel)
				if Rect2(Vector2.ZERO,Vector2(resolution)).has_point(pixel): visible += 1
			print("PROJECTION ",resolution," ",sample[0]," rear_doorway=",screen_points," visible_corners=",visible)
			var entrance := []
			for point in [Vector3(2755,55,240.06),Vector3(2845,55,240.06),Vector3(2755,218,240.06),Vector3(2845,218,240.06),Vector3(2572,55,240),Vector3(3028,55,240)]:
				entrance.append(scene.camera.unproject_position(point*0.01) * Vector2(resolution) / root.get_visible_rect().size)
			print("PROJECTION ",resolution," ",sample[0]," entrance4_apron2=",entrance)
	baseline.queue_free()
	scene.queue_free()
	for i in 3: await process_frame
	quit(1 if failures else 0)

func ray_hit(triangles: Array, a: Vector3, b: Vector3) -> bool:
	for spec in triangles:
		var mesh: MeshInstance3D = spec[0]
		var local_a := mesh.to_local(a)
		var local_b := mesh.to_local(b)
		if mesh.get_aabb().intersects_segment(local_a,local_b) == null: continue
		if not spec[1].intersect_segment(local_a,local_b).is_empty(): return true
	return false
