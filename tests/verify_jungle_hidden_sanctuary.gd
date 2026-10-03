extends SceneTree
## Field topology, visible blockers and dense actor sight rays. Not beauty/fun.
const Layout = preload("res://game/jungle_grotto_layout.gd")
const Helper = preload("res://game/jungle_hidden_sanctuary.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		if failures < 20: printerr("FAIL: ",message)
func hit(specs: Array, a: Vector3, b: Vector3) -> bool:
	for pair in specs:
		var mesh: MeshInstance3D = pair[0]
		var from := mesh.to_local(a)
		var to := mesh.to_local(b)
		if mesh.get_aabb().intersects_segment(from,to) != null and not pair[1].intersect_segment(from,to).is_empty(): return true
	return false
func cofacial_overlaps(mesh: Mesh, verbose := false) -> int:
	# Inspect actual emitted vertical bank triangles, including shared strip/cell
	# sides. Equal planes with positive projected area are depth competitors.
	var planes := {}
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for i in range(0,vertices.size(),3):
		var tri := [vertices[i],vertices[i+1],vertices[i+2]]
		var axis := ""
		if absf(tri[0].x-tri[1].x) < 0.000001 and absf(tri[0].x-tri[2].x) < 0.000001: axis = "x"
		elif absf(tri[0].z-tri[1].z) < 0.000001 and absf(tri[0].z-tri[2].z) < 0.000001: axis = "z"
		if axis.is_empty(): continue
		var polygon := PackedVector2Array()
		for p in tri: polygon.append(Vector2(p.z if axis == "x" else p.x,p.y))
		if polygon_area(polygon) <= 0.0000001: continue
		var key := "%s:%.5f" % [axis,tri[0].x if axis == "x" else tri[0].z]
		if not planes.has(key): planes[key] = []
		planes[key].append(polygon)
	var count := 0
	for plane in planes:
		var polygons: Array = planes[plane]
		for i in polygons.size():
			for j in range(i+1,polygons.size()):
				for overlap in Geometry2D.intersect_polygons(polygons[i],polygons[j]):
					if polygon_area(overlap) > 0.000001:
						count += 1
						if verbose: print("COPLANAR: ",plane," area=",polygon_area(overlap)," a=",polygons[i]," b=",polygons[j])
	return count
func polygon_area(points: PackedVector2Array) -> float:
	var sum := 0.0
	# Translation and double products avoid large-coordinate float32 cross-product
	# cancellation falsely turning a shared edge into positive area.
	for i in points.size():
		var a: Vector2 = points[i]-points[0]
		var b: Vector2 = points[(i+1)%points.size()]-points[0]
		sum += float(a.x)*float(b.y)-float(a.y)*float(b.x)
	return absf(sum)*0.5
func _run() -> void:
	var data := OS.get_user_data_dir()
	var xdg := OS.get_environment("XDG_DATA_HOME")
	if not ("JungleHiddenV49" in data or OS.get_name() == "Linux" and xdg.is_absolute_path() and data.begins_with(xdg.trim_suffix("/")+"/")):
		printerr("FAIL: private JungleHiddenV49 userdata required before scene creation")
		quit(1)
		return
	var scene = load("res://game/jungle_south_circuit.tscn").instantiate()
	scene.profile_save_prefix = "user://hidden_sanctuary_fixture"
	scene.growth_save_prefix = "user://hidden_sanctuary_growth"
	root.add_child(scene)
	for i in 4: await physics_frame
	scene.set_physics_process(false)
	# Keep terrain bodies registered in the real physics world for collision rays.
	for actor in scene.actors: actor.set_physics_process(false)
	scene.wisp.set_physics_process(false)
	var art: Node3D = scene.temple_section.get_node_or_null("HiddenFieldVisuals/JungleHiddenSanctuary")
	check(art != null, "real section mounts final sanctuary under flow root")
	if art == null:
		quit(1)
		return
	check(Layout.ENTRY_TRIGGER == Rect2(1250,630,100,110) and Layout.RETURN_POINT == Vector2(1150,700) and Layout.FIELD_ENTRY == Vector2(6290,2630) and Layout.EXIT_TRIGGER == Rect2(6100,2510,160,220), "four parent-owned portal coordinates preserved")
	check(Layout.ALTAR == Vector2(9860,440) and Layout.FIRST_WAVE == [Vector2(7410,2330),Vector2(7960,2190),Vector2(8040,1890)] and Layout.SECOND_WAVE == [Vector2(8850,1460),Vector2(9270,1100),Vector2(9660,980)], "existing altar and six defenders preserved")
	check(scene.camera.size == 9.0 and scene.camera_offset == Vector3(14,13.864,14), "fixed camera unchanged")
	check(art.get_child_count() == 7 and art.get_meta("fixed_open_roof"), "five opaque batches plus two original water curtains; permanent open passage shape")
	var triangles: Array = []
	for mesh in art.get_children():
		if mesh.get_meta("existing_water",false):
			check(mesh.material_override.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and mesh.material_override.albedo_color == Color(0.4,0.82,0.85,0.55), "existing water material is preserved")
			continue
		check(mesh is MeshInstance3D and mesh.material_override.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "opaque static material")
		triangles.append([mesh,mesh.mesh.generate_triangle_mesh()])
	var banks: Array = art.get_meta("source_bank_areas")
	var landmarks := [Layout.CAVE_SHOULDER,Layout.SANCTUARY_BACK]
	var pieces: Array = []
	for profile in art.get_meta("bank_profiles"): pieces.append_array(profile.pieces)
	var old_overlaps := 0
	for profile in art.get_meta("bank_profiles"):
		for landmark in landmarks:
			var overlap: Rect2 = profile.source.intersection(landmark)
			if overlap.has_area(): old_overlaps += 1
		for piece in profile.pieces:
			for landmark in landmarks:
				check(not piece.intersection(landmark).has_area(),"bank does not duplicate landmark foundation surface")
		check(scene.terrain.surface_areas({"area":profile.source,"cutouts":pieces+landmarks}).is_empty(),"partitioned banks plus landmark foundations preserve full blocked footprint")
	for i in pieces.size():
		for j in range(i+1,pieces.size()):
			check(not pieces[i].intersection(pieces[j]).has_area(),"rock-bank grid and perimeter footprints never duplicate each other")
	for i in banks.size():
		for j in range(i+1,banks.size()):
			if banks[i].intersection(banks[j]).has_area(): old_overlaps += 1
	check(old_overlaps > 0,"uncut-bank negative control detects rejected foundation overlaps")
	var negative := SurfaceTool.new()
	negative.begin(Mesh.PRIMITIVE_TRIANGLES)
	for wall in scene.terrain.wall_areas:
		if wall.get("hidden_rock",false): Helper._bank(negative,wall)
	var rejected_faces := cofacial_overlaps(negative.commit())
	var actual_faces := cofacial_overlaps(art.get_node("RockBanks").mesh,true)
	check(rejected_faces > 0,"uncut exterior/shared-side negative control detects actual coplanar triangles")
	check(actual_faces == 0,"actual emitted exterior and shared bank sides have no positive coplanar triangle overlap")
	var reference := Node3D.new()
	root.add_child(reference)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var observed := 0
	for wall in scene.terrain.wall_areas:
		if not wall.get("hidden_rock",false): continue
		observed += 1
		check(wall.get("minimap_visible",false) and not wall.get("visual",true) and banks.has(wall.area), "collision/minimap/replaced visual share bank record")
		Helper._block(surface,wall.area,0,wall.height,Color.WHITE)
		check(not scene.navigation.is_open(wall.area.get_center(),0), "visible rock footprint blocks actual navigation")
	check(observed == banks.size(), "all blocked bank records rendered exactly once")
	var original := MeshInstance3D.new()
	original.mesh = surface.commit()
	reference.add_child(original)
	var old_triangles: Array = [[original,original.mesh.generate_triangle_mesh()]]
	for p in Layout.PLACE_VIEWS + Layout.FIRST_WAVE + Layout.SECOND_WAVE + [Layout.ALTAR,Layout.EXIT_TRIGGER.get_center()]:
		check(scene.navigation.is_open(p,30),"open place/defender/reward/return "+str(p))
		check(not scene.navigation.find_path(Layout.FIELD_ENTRY,p).is_empty() and not scene.navigation.find_path(p,Layout.FIELD_ENTRY).is_empty(),"round-trip field connectivity "+str(p))
		check(scene.terrain.height_at(p) == 0.0,"single ground height preserved at "+str(p))
		var shot := Node2D.new()
		scene.shot_height_data[shot] = [p,0.0,0.0,200.0]
		scene.shot_motion[shot] = [p,p]
		check(is_equal_approx(scene._shot_world_point(shot,p).y,0.55),"actual projectile visual remains above field courses "+str(p))
		scene.shot_height_data.erase(shot)
		scene.shot_motion.erase(shot)
		shot.free()
	check(scene.navigation.find_path(scene.start_point,Layout.ALTAR).is_empty(),"field remains isolated from main navigation")
	var water_ray := PhysicsRayQueryParameters2D.create(Vector2(6650,2690),Vector2(6650,2810),4)
	water_ray.hit_from_inside = true
	check(not scene.player.get_world_2d().direct_space_state.intersect_ray(water_ray).is_empty(),"inlet water blocks actual projectile/collision ray")
	check(not scene.clear_attack(Vector2(6650,2690),Vector2(6650,2810)),"same inlet water blocks actual attack sight")
	for path in Layout.PATHS:
		for i in range(path.points.size()-1):
			for step in 6:
				var p: Vector2 = path.points[i].lerp(path.points[i+1],step/5.0)
				check(scene.navigation.is_open(p,30),"fixed route center remains open "+str(p))
	var floor: MeshInstance3D = art.get_node("ThresholdAndSunlitCourses")
	var vertices: PackedVector3Array = floor.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for p in vertices:
		check(is_equal_approx(p.y,Helper.FLOOR_LIFT*0.01) and scene.navigation.is_open(Vector2(p.x,p.z)*100,0),"courses follow walkable ground below actor shadow")
	var shadow = scene.actors[scene.player].get_node("Shadow")
	check(Helper.FLOOR_LIFT*0.01 < shadow.position.y-shadow.mesh.height*0.5,"course height stays below actual shadow bottom")
	var rays := 0
	var old_blocked := 0
	var new_obstructions := 0
	var direction: Vector3 = scene.camera.global_basis.z*40.0
	for x in range(6140,10061,100):
		for y in range(240,2781,100):
			var p := Vector2(x,y)
			if not scene.navigation.is_open(p,30): continue
			for lift in [30.0,65.0,95.0,150.0]:
				var a: Vector3 = scene.terrain.world_point(p,lift)
				var before := hit(old_triangles,a,a+direction)
				var after := hit(triangles,a,a+direction)
				rays += 1
				if before: old_blocked += 1
				if after and not before: new_obstructions += 1
				check(not after or before,"new field scenery ray obstruction "+str(p)+" lift="+str(lift))
	# Reward and transport are exercised by the unchanged section fixture too.
	var section = scene.temple_section
	section.enter_garden()
	section.tick(0.0)
	scene.teleport(Layout.ALTAR)
	check(section.claim_garden_reward(),"existing reward accessible at exact altar")
	scene._close_awakening_receipt()
	section.leave_garden()
	check(scene.player.position == Layout.RETURN_POINT,"existing return endpoint")
	print("Jungle hidden sanctuary: %d checks, %d failures; sight_rays=%d; existing_bank_occlusion=%d; new_obstruction=%d; rejected_coplanar_bank_pairs=%d; final_coplanar_bank_pairs=%d. Human aesthetics/fun unverified." % [checks,failures,rays,old_blocked,new_obstructions,rejected_faces,actual_faces])
	art.queue_free()
	reference.queue_free()
	scene.queue_free()
	for i in 3: await process_frame
	quit(1 if failures else 0)
