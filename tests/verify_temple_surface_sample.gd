extends SceneTree
const Finish = preload("res://game/temple_surface_sample.gd")
var failures := 0
var checks := 0
var max_normal_error := 0.0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: ",message)
func _terrain_state(scene) -> String:
	return var_to_str([scene.terrain.wall_areas,scene.terrain.plateaus,scene.terrain.ramps,scene.terrain.water_areas,scene.terrain.floor_areas])
func _run() -> void:
	if not OS.get_user_data_dir().contains("TempleSurfaceSample/"):
		printerr("FAIL: isolated TempleSurfaceSample UUID userdata required")
		quit(1)
		return
	var scene = load("res://game/temple_circuit_run.tscn").instantiate()
	scene.profile_save_prefix = "user://sample_profile"
	scene.growth_save_prefix = "user://sample_unlocks"
	root.add_child(scene)
	await process_frame
	var terrain := _terrain_state(scene)
	var camera := [scene.camera.size,scene.camera_offset,scene.player.MOVE_SPEED,scene.BOSS_TIME]
	var terrain_mesh: Mesh = scene.terrain_mesh.mesh
	var actor_material: Material = scene.actors[scene.player].get_node("Body").material_override
	Finish.install(scene)
	check(scene.has_meta("temple_surface_sample"),"finish installed on current temple mainline")
	var counts: Dictionary = scene.get_meta("temple_surface_sample")
	check(counts == {"stone":4,"paving":2,"growth":3,"far_bank":2,"terrain":1},"bounded target mesh counts")
	var finished := 0
	for mesh in scene.temple_sanctuary_root.find_children("*","MeshInstance3D",true,false):
		if not mesh.has_meta("temple_surface_original_mesh"): continue
		finished += 1
		var old: ArrayMesh = mesh.get_meta("temple_surface_original_mesh")
		check(old.get_aabb() == mesh.mesh.get_aabb(),"same silhouette "+mesh.name)
		check(old.get_surface_count() == mesh.mesh.get_surface_count(),"same draw surfaces "+mesh.name)
		for surface in old.get_surface_count():
			var before: Array = old.surface_get_arrays(surface)
			var after: Array = mesh.mesh.surface_get_arrays(surface)
			for channel in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_COLOR,Mesh.ARRAY_INDEX]:
				check(before[channel] == after[channel],"preserved mesh channel "+str(channel)+" "+mesh.name)
			for index in before[Mesh.ARRAY_NORMAL].size():
				var error: float = before[Mesh.ARRAY_NORMAL][index].distance_to(after[Mesh.ARRAY_NORMAL][index])
				max_normal_error = maxf(max_normal_error,error)
				check(error < 0.001,"normal quantization below0.001 "+mesh.name)
			check(after[Mesh.ARRAY_TEX_UV].size() == after[Mesh.ARRAY_VERTEX].size(),"face UV complete "+mesh.name)
			for uv in after[Mesh.ARRAY_TEX_UV]: check(uv.x >= -0.001 and uv.y >= -0.001 and uv.x <= 1.001 and uv.y <= 1.001,"face UV bounded")
	check(finished == 11,"eleven existing meshes finished, no additional silhouettes")
	check(scene.terrain_mesh.mesh == terrain_mesh,"terrain mesh identity unchanged")
	check(_terrain_state(scene) == terrain,"all terrain/collision records unchanged")
	check(camera == [scene.camera.size,scene.camera_offset,scene.player.MOVE_SPEED,scene.BOSS_TIME],"camera/movement/boss time unchanged")
	check(actor_material == scene.actors[scene.player].get_node("Body").material_override,"player material preserved")
	var material: Material = scene.terrain_mesh.material_override
	Finish.install(scene)
	check(material == scene.terrain_mesh.material_override,"idempotent installation")
	check(scene.temple_section.layout.ENTRY_TRIGGER == Rect2(1160,730,110,110),"hidden contract preserved")
	var scope = scene.get_node("TempleSurfaceMainlineScope")
	scene.temple_section.in_garden = true
	scope._process(0.0)
	check(scene.terrain_mesh.material_override == scope.original_terrain,"original terrain material restored outside mainline")
	check(scope.environment_node.environment == scope.original_environment,"original hidden-room environment identity preserved")
	for property in scope.original_sun: check(scope.sun.get(property) == scope.original_sun[property],"original hidden-room light "+property)
	scene.temple_section.in_garden = false
	scope._process(0.0)
	check(scene.terrain_mesh.material_override == material,"mainline material restored on return")
	# The UV function maps a whole two-triangle face, not each triangle's diagonal.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in [Vector3(0,0,0),Vector3(2,0,0),Vector3(2,0,1),Vector3(0,0,0),Vector3(2,0,1),Vector3(0,0,1)]:
		st.set_normal(Vector3.UP); st.add_vertex(point)
	var mapped := Finish.face_uvs(st.commit()).surface_get_arrays(0)
	check(mapped[Mesh.ARRAY_TEX_UV] == PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]),"no internal diagonal wear boundary")
	for extent in mapped[Mesh.ARRAY_TEX_UV2]: check(extent == Vector2(2,1),"physical wear width independent of face size")
	print("Temple surface sample: ",checks," checks, ",failures," failures; maximum_normal_vector_error=",max_normal_error,"; install_ms=",scene.get_meta("temple_surface_install_ms"),". No human art/fun acceptance.")
	scene.queue_free()
	for i in 3: await process_frame
	quit(1 if failures else 0)
