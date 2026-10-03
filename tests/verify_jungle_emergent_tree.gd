extends SceneTree
const TreeAsset = preload("res://game/jungle_emergent_tree.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		if failures < 30: printerr("FAIL: ",note)
func _run() -> void:
	var scene = load("res://game/jungle_south_circuit.tscn").instantiate()
	scene.profile_save_prefix = "user://emergent_tree_profile"
	scene.growth_save_prefix = "user://emergent_tree_growth"
	root.add_child(scene)
	for i in 4: await physics_frame
	scene.set_physics_process(false)
	scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
	var asset: Node3D = scene.get_node("JungleEmergentTree")
	check(asset.get_child_count()==3,"three opaque batches")
	check(scene.camera.size==9.0 and scene.camera_offset==Vector3(14,13.864,14),"unchanged camera")
	for point in TreeAsset.REPLACED_TREES:
		check(not scene.canopy_visuals.has(point),"old tree visuals skipped through candidate-only canopy list")
	check(scene.canopy_visuals.size()==14,"all other inherited trees remain")
	var actual_areas: Array = []
	for wall in scene.terrain.wall_areas:
		if wall.get("emergent_tree_pocket",false): actual_areas.append(wall.area)
	check(actual_areas==TreeAsset.POCKET,"exact physical rectangle union")
	var triangles: Array = []
	var lo := Vector3(INF,INF,INF)
	var hi := -lo
	for mesh in asset.get_children():
		check(mesh.mesh.get_surface_count()==1,"one surface per batch")
		check(mesh.material_override.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and not mesh.material_override.emission_enabled,"opaque, no emission")
		var arrays = mesh.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in vertices.size():
			var v: Vector3 = vertices[i]
			lo=lo.min(v); hi=hi.max(v)
			check(v.is_finite() and normals[i].is_finite() and absf(normals[i].length()-1.0)<0.001,"finite geometry/unit normals")
			check(TreeAsset.contains_ground(Vector2(v.x,v.z)*100),"every elevated vertex projects to physical pocket")
			check(is_equal_approx(arrays[Mesh.ARRAY_COLOR][i].a,1.0),"opaque color")
		for i in range(0,vertices.size(),3):
			var a := vertices[i]
			var b := vertices[i+1]
			var c := vertices[i+2]
			var normal := (b-a).cross(c-a)
			check(normal.length()>0.0000001 and normal.normalized().dot(normals[i]) < -0.999,"nondegenerate clockwise winding")
			triangles.append([a,b,c])
	check(absf(hi.y-9.0)<0.001,"nine-world-unit height")
	# Ground coverage uses actual mesh triangles, not just the authored polygon.
	var ledge: PackedVector3Array = asset.get_child(0).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var covered := 0
	for x in range(5,800,10):
		for y in range(5,820,10):
			var point := Vector2(x,y)
			var hit := false
			for i in range(0,18,3): # first six exact contour top triangles
				var a := Vector2(ledge[i].x,ledge[i].z)*100
				var b := Vector2(ledge[i+1].x,ledge[i+1].z)*100
				var c := Vector2(ledge[i+2].x,ledge[i+2].z)*100
				if Geometry2D.point_is_inside_triangle(point,a,b,c): hit=true; break
			check(hit==TreeAsset.contains_ground(point,0),"rock top exactly covers blocker, never adjacent walking ground")
			if hit: covered+=1
	# Dense actual orthographic camera rays to feet/chest/head outside pocket.
	var rays := 0
	for x in range(10,1451,30):
		for y in range(10,1451,30):
			var point := Vector2(x,y)
			if not scene.navigation.is_open(point,0): continue
			for lift in [0.08,0.4,0.75]:
				var target: Vector3 = scene.terrain.world_point(point)+Vector3.UP*lift
				var origin: Vector3 = target+scene.camera_offset
				var hit := false
				for triangle in triangles:
					if Geometry3D.segment_intersects_triangle(origin,target,triangle[0],triangle[1],triangle[2]) != null: hit=true; break
				check(not hit,"dense actor camera ray outside blocked pocket")
				rays+=1
	for point in [Vector2(250,850),Vector2(350,850),Vector2(820,600),Vector2(850,700),Vector2(430,1210),Vector2(970,820),Vector2(1150,700),Vector2(1300,680)]:
		check(scene.navigation.is_open(point,24) and not scene.navigation.find_path(scene.start_point,point).is_empty(),"capture/spawn/hidden approach preserved "+str(point))
	for route in [scene.SouthTerrain.SOUTH_ROUTE,scene.SouthTerrain.RIDGE_RETURN]:
		for point in route: check(not scene.navigation.find_path(scene.start_point,point).is_empty(),"southern routes preserved")
	var original = preload("res://game/jungle_pass_terrain.gd").new()
	var route = preload("res://game/jungle_route_terrain.gd").new()
	check(original.CANOPY_POINTS.size()==16 and route.route_canopy_points.size()==16,"original pass/route trees untouched")
	check(scene.BOSS_TIME==240 and scene.temple_section.boss_point==Vector2(4750,850),"boss timing and destination untouched")
	# Reconstruct the exact inherited pre-pocket barriers for path-cost comparison.
	var baseline = preload("res://game/jungle_south_circuit_terrain.gd").new()
	for i in range(baseline.wall_areas.size()-1,-1,-1):
		if baseline.wall_areas[i].get("emergent_tree_pocket",false): baseline.wall_areas.remove_at(i)
	for wall in route.wall_areas:
		if wall.area == TreeAsset.OLD_ROCK or wall.area == Rect2(Vector2(327,447),Vector2(46,46)) or wall.area == Rect2(Vector2(627,337),Vector2(46,46)):
			baseline.wall_areas.append(wall.duplicate(true))
	check(baseline.water_areas==scene.terrain.water_areas and baseline.ramps==scene.terrain.ramps and baseline.plateaus==scene.terrain.plateaus,"water, elevations and route surfaces unchanged")
	var baseline_nav := ArenaNavigation.new()
	baseline_nav.agent_radius = scene.ACTOR_CLEARANCE
	baseline_nav.strict_contact_escape = true
	var blocks: Array = []
	for area in baseline.barriers():
		var block := TempleBlock.new()
		block.setup(area,baseline.water_areas.has(area))
		root.add_child(block)
		blocks.append(block)
	baseline_nav.setup(blocks,baseline.map_size)
	var route_counts: Array = []
	for point in [Vector2(1700,1150),Vector2(2150,250),Vector2(1300,680),Vector2(1150,700),Vector2(2900,1800),Vector2(3400,1850),Vector2(4750,850),Vector2(2080,2910)]:
		var before: PackedVector2Array = baseline_nav.find_path(scene.start_point,point)
		var after: PackedVector2Array = scene.navigation.find_path(scene.start_point,point)
		check(not after.is_empty() and before.size()==after.size(),"baseline/candidate A* node count preserved "+str(point))
		route_counts.append([point,before.size(),after.size()])
	for block in blocks: block.free()
	print("Baseline/candidate route counts: ",route_counts)
	var repeat := TreeAsset.build()
	for i in 3: check(repeat.get_child(i).mesh.surface_get_arrays(0)==asset.get_child(i).mesh.surface_get_arrays(0),"deterministic")
	repeat.free()
	print("Jungle emergent tree: checks=",checks," failures=",failures," triangles=",triangles.size()," dense_camera_rays=",rays," covered_10px_cells=",covered," bounds=",AABB(lo,hi-lo))
	scene.queue_free()
	for i in 3: await process_frame
	quit(1 if failures else 0)
