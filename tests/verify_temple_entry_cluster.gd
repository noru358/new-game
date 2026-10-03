extends SceneTree
const Cluster = preload("res://game/temple_entry_cluster.gd")
var errors: Array[String]=[]
var checks := 0
func _initialize() -> void: call_deferred("_run")
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok: errors.append(message); printerr("FAIL: ",message)
func _run() -> void:
	if not OS.get_user_data_dir().contains("TempleEntryCluster/"):
		printerr("FAIL: isolated TempleEntryCluster UUID required"); quit(1); return
	var arena=load("res://game/temple_circuit_run.tscn").instantiate()
	arena.profile_save_prefix="user://entry_profile"; arena.growth_save_prefix="user://entry_growth"
	root.add_child(arena); await process_frame
	arena.practice_mode=true
	var terrain_state := var_to_str([arena.terrain.wall_areas,arena.terrain.water_areas,arena.terrain.floor_areas,arena.terrain.plateaus,arena.terrain.ramps])
	var environment_node:WorldEnvironment=arena.find_children("*","WorldEnvironment",true,false)[0]
	var environment:Environment=environment_node.environment
	var terrain_material:Material=arena.terrain_mesh.material_override
	var original_terrain_mesh:Mesh=arena.terrain_mesh.mesh
	var original_paving:Mesh=arena.temple_sanctuary_root.get_node("ReclaimedCourtMasonry/CourtAndStairCourses").mesh
	var camera_state := [arena.camera.size,arena.camera_offset,arena.player.MOVE_SPEED,arena.BOSS_TIME]
	var began := Time.get_ticks_usec()
	var cluster := Cluster.install(arena)
	var elapsed := (Time.get_ticks_usec()-began)/1000.0
	check(cluster!=null,"sample installed")
	check(cluster.get_child_count()==3,"three batched meshes")
	check(cluster.find_children("*","CollisionObject3D",true,false).is_empty(),"no new collision")
	check(terrain_state==var_to_str([arena.terrain.wall_areas,arena.terrain.water_areas,arena.terrain.floor_areas,arena.terrain.plateaus,arena.terrain.ramps]),"all terrain contracts unchanged")
	check(environment==environment_node.environment,"original lighting environment identity")
	check(terrain_material==arena.terrain_mesh.material_override,"original terrain material identity")
	check(original_terrain_mesh==arena.terrain_mesh.mesh,"actual plateau/floor mesh identity")
	check(original_paving==arena.temple_sanctuary_root.get_node("ReclaimedCourtMasonry/CourtAndStairCourses").mesh,"original court and stair paving identity")
	check(camera_state==[arena.camera.size,arena.camera_offset,arena.player.MOVE_SPEED,arena.BOSS_TIME],"camera/speed/boss-time unchanged")
	check(Cluster.install(arena)==cluster,"idempotent install")
	var report := {"checks":0,"errors":errors,"install_ms":elapsed,"resources":cluster.get_meta("vertex_counts"),"mesh_bounds":{}}
	for visual in cluster.get_children():
		var bounds:AABB=visual.global_transform*visual.mesh.get_aabb()
		report.mesh_bounds[visual.name]=[bounds.position.x,bounds.position.y,bounds.position.z,bounds.end.x,bounds.end.y,bounds.end.z]
		check(visual.mesh.get_surface_count()==1,"one surface "+visual.name)
		check(visual.material_override is StandardMaterial3D,"original native shaded material "+visual.name)
		check(visual.material_override.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED,"opaque "+visual.name)
		if visual.name=="StoneSoilContacts":
			var arrays=visual.mesh.surface_get_arrays(0)
			var maximum:=0.0; var minimum_clearance:=INF;var minimum_floor_clearance:=INF
			for point in arrays[Mesh.ARRAY_VERTEX]:
				var world:Vector3=visual.to_global(point)
				var xy:=Vector2(world.x,world.z)/Cluster.SCALE
				var lift:float=world.y/Cluster.SCALE-arena.terrain.height_at(xy)
				maximum=maxf(maximum,lift); minimum_clearance=minf(minimum_clearance,lift)
				var visible_floor:float=arena.terrain.height_at(xy)
				for floor in arena.terrain.floor_areas:
					if floor.area.has_point(xy):visible_floor=maxf(visible_floor,float(floor.get("height",0.7)))
				minimum_floor_clearance=minf(minimum_floor_clearance,world.y/Cluster.SCALE-visible_floor)
			check(maximum<=0.85,"contacts below0.85 including all overlays")
			check(minimum_clearance>=0.66,"contacts clear original ground")
			check(minimum_floor_clearance>=0.15,"contacts also clear actual plain floor top")
			var shadow:MeshInstance3D=arena.actors[arena.player].get_node("Shadow")
			var shadow_bottom:float=shadow.position.y-shadow.mesh.height*0.5
			check(maximum*Cluster.SCALE<shadow_bottom-0.0005,"contacts below actual actor shadow underside with margin")
			report.actor_shadow_bottom=shadow_bottom
			report.contact_max_lift=maximum
			report.contact_min_lift=minimum_clearance
			report.contact_min_floor_separation=minimum_floor_clearance
		else:
			check(bounds.position.x>=17.299 and bounds.end.x<=21.501 and bounds.position.z>=11.899 and bounds.end.z<=16.901,"solid/plants within existing whole hall barrier "+visual.name)
			check(bounds.end.y<=1.10,"no taller new foreground "+visual.name)
	var original_hall_vertices_remaining:=0
	for label in ["WeatheredCourtyardWalls","CourtyardEdgeGrowth"]:
		var original_batch:MeshInstance3D=arena.temple_sanctuary_root.get_node("ReclaimedCourtMasonry/"+label)
		for vertex in original_batch.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			if Cluster.SOURCE_AREA.grow(-0.5).has_point(Vector2(vertex.x,vertex.z)/Cluster.SCALE):original_hall_vertices_remaining+=1
	check(original_hall_vertices_remaining==0,"entire original hall ornament removed, no covering foreground bay retained")
	report.original_hall_vertices_remaining=original_hall_vertices_remaining
	# Short routing checks, not a many-thousand-condition art acceptance surrogate.
	var route := [Vector2(2450,2100),Vector2(1650,2275),Vector2(1590,1840),Vector2(1450,1700),Vector2(1450,1350)]
	for i in route.size():
		check(arena.navigation.is_open(route[i],30),"representative waypoint open "+str(route[i]))
		if i: check(not arena.navigation.find_path(route[i-1],route[i]).is_empty(),"existing route available")
	check(arena.temple_section.layout.ENTRY_TRIGGER==Rect2(1160,730,110,110),"hidden entry unchanged")
	report.checks=checks
	print("ENTRY_CLUSTER_CHECK: ",JSON.stringify(report))
	arena.queue_free(); for i in 3: await process_frame
	quit(0 if errors.is_empty() else 1)
