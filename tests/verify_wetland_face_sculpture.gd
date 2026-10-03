extends SceneTree
const Sculpture = preload("res://game/wetland_face_sculpture.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",note)
func bounds(node: Node3D) -> AABB:
	var lo := Vector3(INF,INF,INF)
	var hi := -lo
	for child in node.get_children():
		for vertex in child.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var p: Vector3 = child.transform * vertex
			lo = lo.min(p)
			hi = hi.max(p)
	return AABB(lo,hi-lo)
func _run() -> void:
	var terrain_hash := FileAccess.get_sha256("res://game/deep_wetland_terrain.gd")
	var field_hash := FileAccess.get_sha256("res://game/deep_wetland_field_terrain.gd")
	var scene = load("res://game/deep_wetland_field.tscn").instantiate()
	var waters = scene.terrain.water_areas.duplicate(true)
	var walls = scene.terrain.wall_areas.duplicate(true)
	root.add_child(scene)
	for i in 4: await physics_frame
	var old: Node3D = scene.get_node("MonumentalWetlandFace")
	var old_bounds := bounds(old) if old.get_child_count()==11 else AABB(Vector3(-1.059208,0,-1.241853),Vector3(2.189135,3.8,2.534797))
	var old_transform := old.transform
	var sculpture := Sculpture.build(scene)
	scene.remove_child(old)
	old.free()
	scene.add_child(sculpture)
	sculpture.transform = old_transform
	var envelope := bounds(sculpture)
	check(old_bounds.grow(0.00001).encloses(envelope),"inside measured original vertex envelope")
	check(is_equal_approx(envelope.position.y,0.0) and is_equal_approx(envelope.end.y,3.8),"exact original local height 3.8")
	check(sculpture.get_child_count()==2,"two draw surfaces instead of eleven")
	check(scene.camera.size==9.0,"unchanged camera")
	check(scene.terrain.water_areas==waters and scene.terrain.wall_areas==walls,"unchanged terrain records")
	check(terrain_hash==FileAccess.get_sha256("res://game/deep_wetland_terrain.gd") and field_hash==FileAccess.get_sha256("res://game/deep_wetland_field_terrain.gd"),"terrain source hashes unchanged")
	var triangles := 0
	for node in sculpture.get_children():
		check(node is MeshInstance3D and node.get_child_count()==0,"visual mesh leaves only")
		check(node.mesh.get_surface_count()==1,"one surface per batch")
		check(node.material_override.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED,"opaque")
		check(not node.material_override.emission_enabled,"no glow")
		var arrays = node.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		triangles += vertices.size()/3
		for i in vertices.size():
			check(vertices[i].is_finite(),"finite vertex")
			check(normals[i].is_finite() and absf(normals[i].length()-1.0)<0.001,"unit lighting normal")
			check(is_equal_approx(arrays[Mesh.ARRAY_COLOR][i].a,1.0),"opaque vertex color")
			var world: Vector3 = node.to_global(vertices[i])
			var wet := false
			for water in waters:
				if water.has_point(Vector2(world.x,world.z)*100.0): wet=true; break
			check(wet,"every mounted vertex above blocked water")
		for i in range(0,vertices.size(),3):
			var cross := (vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i])
			check(cross.length()>0.0000001,"nondegenerate triangle")
			check(cross.normalized().dot(normals[i]) < -0.999,"clockwise winding agrees with outward normal")
			check(normals[i].is_equal_approx(normals[i+1]) and normals[i].is_equal_approx(normals[i+2]),"flat triangle normals")
	var repeat := Sculpture.build(scene)
	for i in 2:
		check(repeat.get_child(i).mesh.surface_get_arrays(0)==sculpture.get_child(i).mesh.surface_get_arrays(0),"deterministic rebuild")
	repeat.free()
	print("Wetland sculpture: ",checks," checks, ",failures," failures; triangles=",triangles,"; old=",old_bounds,"; new=",envelope)
	scene.queue_free()
	for i in 4: await process_frame
	quit(1 if failures else 0)
