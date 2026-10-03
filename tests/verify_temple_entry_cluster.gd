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
	check(camera_state==[arena.camera.size,arena.camera_offset,arena.player.MOVE_SPEED,arena.BOSS_TIME],"camera/speed/boss-time unchanged")
	check(Cluster.install(arena)==cluster,"idempotent install")
	var report := {"checks":0,"errors":errors,"install_ms":elapsed,"resources":cluster.get_meta("vertex_counts"),"mesh_bounds":{}}
	for visual in cluster.get_children():
		var bounds:AABB=visual.mesh.get_aabb()
		report.mesh_bounds[visual.name]=[bounds.position.x,bounds.position.y,bounds.position.z,bounds.end.x,bounds.end.y,bounds.end.z]
		check(visual.mesh.get_surface_count()==1,"one surface "+visual.name)
		check(visual.material_override is StandardMaterial3D,"original native shaded material "+visual.name)
		check(visual.material_override.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED,"opaque "+visual.name)
		if visual.name=="StoneSoilContacts":
			var arrays=visual.mesh.surface_get_arrays(0)
			var maximum:=0.0; var minimum_clearance:=INF
			for point in arrays[Mesh.ARRAY_VERTEX]:
				var xy:=Vector2(point.x,point.z)/Cluster.SCALE
				var lift:float=point.y/Cluster.SCALE-arena.terrain.height_at(xy)
				maximum=maxf(maximum,lift); minimum_clearance=minf(minimum_clearance,lift)
			check(maximum<=0.85,"contacts below0.85 including all overlays")
			check(minimum_clearance>=0.78,"contacts clear original ground")
			check(maximum<1.2,"contacts below original actor shadow base1.2")
			report.contact_max_lift=maximum
			report.contact_min_lift=minimum_clearance
		else:
			check(bounds.position.x>=17.299 and bounds.end.x<=21.501 and bounds.position.z>=14.899 and bounds.end.z<=16.901,"solid/plants within existing barrier "+visual.name)
			check(bounds.end.y<=1.10,"no taller new foreground "+visual.name)
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
