extends SceneTree
## Authored garden structure and regression contract, not human art/fun acceptance.
const Data = preload("res://game/temple_garden_courtyard_data.gd")
var checks := 0
var failures: Array[String] = []
var records: Array = []
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		if failures.size() < 20: printerr("FAIL: ",message)
func _run() -> void:
	var user_data := OS.get_user_data_dir()
	var xdg := OS.get_environment("XDG_DATA_HOME")
	if not ("TempleGardenV50" in user_data or (OS.get_name()=="Linux" and xdg.is_absolute_path() and user_data.begins_with(xdg.trim_suffix("/")+"/"))):
		printerr("FAIL: isolated TempleGardenV50 userdata required before any profile access")
		quit(1)
		return
	var field_floors: Array = []
	var field_walls: Array = []
	for name in ["hybrid_region","temple_circuit_run"]:
		var scene = load("res://game/"+name+".tscn").instantiate()
		scene.profile_save_prefix = "user://courtyard_"+name+"_profile"
		scene.growth_save_prefix = scene.profile_save_prefix+"_growth"
		root.add_child(scene)
		for i in 3: await physics_frame
		scene.set_physics_process(false)
		scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
		var section = scene.temple_section
		var layout = section.layout
		check(scene.BOSS_TIME==240.0 and scene.combat_camera_size==9.0 and scene.camera_offset==Vector3(14,13.864,14),name+" clock/camera")
		check(layout.FIELD_BOUNDS==Rect2(5600,80,3000,2000) and layout.FIELD_ENTRY==Vector2(5840,1770) and layout.EXIT_TRIGGER==Rect2(5660,1690,100,160),name+" field/portal")
		check(layout.ALTAR==Vector2(8300,480) and layout.GUARDS==[Vector2(6350,1510),Vector2(7130,520),Vector2(8030,1370)],name+" existing altar/guard3")
		var floors: Array = scene.terrain.floor_areas.filter(func(r):return layout.FIELD_BOUNDS.encloses(r.area))
		var walls: Array = scene.terrain.wall_areas.filter(func(r):return r.get("garden_courtyard",false))
		if name=="hybrid_region": field_floors=floors;field_walls=walls
		else: check(floors==field_floors and walls==field_walls,"Original and circuit mount identical field records")
		var visual: Node3D = section.get_node_or_null("HiddenFieldVisuals/TempleGardenCourtyard")
		check(visual != null, name + " real section mounts courtyard under hidden root")
		if visual == null:
			scene.queue_free()
			await process_frame
			continue
		check(visual.get_child_count()==3,name+" bounded three opaque batches")
		var triangles: Array = []
		for mesh in visual.get_children():
			check(mesh.material_override.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED,name+" opaque "+mesh.name)
			triangles.append([mesh,mesh.mesh.generate_triangle_mesh()])
			for vertex in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				check(layout.FIELD_BOUNDS.grow(0.01).has_point(Vector2(vertex.x,vertex.z)*100),name+" geometry within field")
		var shadow = scene.actors[scene.player].get_node("Shadow")
		check(visual.get_meta("floor_lift_max")*0.01<shadow.position.y-shadow.mesh.height*0.5-0.0005,name+" paving below real ground shadow")
		# Positive area floor overlap is removed before rendering, including the pond.
		var surfaces: Array[Rect2] = []
		for floor in floors:
			for area in scene.terrain.surface_areas(floor):
				check(not area.intersects(layout.POND),name+" floor does not cover water")
				for old in surfaces: check(not area.intersects(old),name+" no overlapping floor surfaces")
				surfaces.append(area)
		for wall in walls:
			check(wall.height>scene.terrain.height_at(wall.area.get_center())+20,name+" >20 blocker contract")
			check(not scene.navigation.is_open(wall.area.get_center(),0.0),name+" visible garden bed blocks its footprint")
		for sample in Data.WALK_POINTS:
			check(scene.navigation.is_open(sample.point,30),name+" open checkpoint "+sample.name)
			check(not scene.navigation.find_path(layout.FIELD_ENTRY,sample.point).is_empty(),name+" connected checkpoint "+sample.name)
		for point in layout.GUARDS:
			check(scene.navigation.is_open(point,30) and not scene.navigation.find_path(layout.FIELD_ENTRY,point).is_empty(),name+" legal fixed guardian "+str(point))
		check(not scene.navigation.find_path(layout.FIELD_ENTRY,layout.EXIT_TRIGGER.get_center()).is_empty(),name+" return threshold reachable")
		check(scene.navigation.find_path(scene.start_point,layout.ALTAR).is_empty(),name+" hidden field isolated from main")
		var rays := 0
		var obstructed := 0
		# Every legal coarse-grid position, plus route shoulders, at feet/body/head.
		var direction: Vector3 = scene.camera.global_basis.z*40.0
		for x in range(5670,8550,90):
			for y in range(155,2030,90):
				var point := Vector2(x,y)
				if not scene.navigation.is_open(point,30): continue
				for lift in [30.0,65.0,95.0,150.0]:
					var at: Vector3 = scene.terrain.world_point(point,lift)
					var blocked := hit(triangles,at,at+direction)
					rays += 1
					if blocked: obstructed+=1
					check(not blocked,name+" actor ray blocked "+str(point)+" lift "+str(lift))
		records.append({"scene":name,"mesh_counts":visual.get_meta("resource_counts"),"legal_actor_rays":rays,"obstructed_rays":obstructed,"floor_pieces":surfaces.size()})
		scene.queue_free()
		for i in 3: await process_frame
	var output := OS.get_environment("GARDEN_CHECK_OUTPUT")
	if not output.is_empty():
		var f := FileAccess.open(output,FileAccess.WRITE)
		if f!=null: f.store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records,"engine":Engine.get_version_info().string,"scope":"structure + coarse legal actor rays; no rendered pixels, natural combat or human place/fun acceptance"},"  "))
	print("Temple garden courtyard: ",checks," checks; ",failures.size()," failures; ",JSON.stringify(records))
	quit(0 if failures.is_empty() else 1)
func hit(specs: Array, a: Vector3, b: Vector3) -> bool:
	for pair in specs:
		var mesh: MeshInstance3D = pair[0]
		var from := mesh.to_local(a)
		var to := mesh.to_local(b)
		if mesh.get_aabb().intersects_segment(from,to)!=null and not pair[1].intersect_segment(from,to).is_empty(): return true
	return false
