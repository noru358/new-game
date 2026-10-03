extends SceneTree
## Local camera-ray regression against the exact production scenery in this scene.
## Actor shoulders near the changed barrier, not a whole-map aesthetic acceptance.
const Cluster=preload("res://game/temple_entry_cluster.gd")
var errors:Array[String]=[]
func _initialize() -> void:call_deferred("_run")
func _world_geometry(arena) -> Array:
	var result:Array=[]
	var visuals:Array=[arena.terrain_mesh]
	visuals.append_array(arena.temple_sanctuary_root.find_children("*","MeshInstance3D",true,false))
	if arena.has_node("TempleEntryCluster"):visuals.append_array(arena.get_node("TempleEntryCluster").get_children())
	for visual in visuals:
		if visual.mesh==null:continue
		# Store the transform and triangle resource, not a mutable mesh-instance pointer.
		result.append([visual.global_transform.affine_inverse(),visual.mesh.generate_triangle_mesh()])
	return result
func _hit(geometry:Array,from:Vector3,to:Vector3) -> bool:
	for pair in geometry:
		if not pair[1].intersect_segment(pair[0]*from,pair[0]*to).is_empty():return true
	return false
func _run() -> void:
	if not OS.get_user_data_dir().contains("TempleEntryCluster/"):
		printerr("FAIL: isolated TempleEntryCluster UUID required");quit(1);return
	var arena=load("res://game/temple_circuit_run.tscn").instantiate()
	arena.profile_save_prefix="user://impact_profile";arena.growth_save_prefix="user://impact_growth"
	root.add_child(arena)
	await process_frame
	arena.practice_mode=true;arena.set_physics_process(false)
	var before:=_world_geometry(arena)
	Cluster.install(arena)
	var after:=_world_geometry(arena)
	var rays:=0;var old_blocked:=0;var new_blocked:=0;var regressions:Array=[]
	for x in [1450,1600,1695]:
		for y in [1190,1250,1310,1370,1430,1490,1550,1610,1670,1730,1790]:
			var point:=Vector2(x,y)
			if not arena.navigation.is_open(point,30):continue
			for lift in [20,45,70,95]:
				var at:Vector3=arena.terrain.world_point(point,lift)
				var camera_point:Vector3=arena.terrain.world_point(point,35)+arena.camera_offset
				var old:=_hit(before,at,camera_point);var current:=_hit(after,at,camera_point)
				rays+=1
				if old:old_blocked+=1
				if current:new_blocked+=1
				if current and not old:regressions.append({"point":[x,y],"lift":lift})
	if not regressions.is_empty():errors.append("New local player-height ray obstructions")
	var report:Dictionary={"rays":rays,"old_blocked":old_blocked,"candidate_blocked":new_blocked,"regressions":regressions,"errors":errors,"scope":"production-vs-kit static geometry rays on 3 cloister route shoulders and 4 actor heights, not full-map pixels or human art/fun","camera_offset":[arena.camera_offset.x,arena.camera_offset.y,arena.camera_offset.z]}
	print("ENTRY_CLUSTER_IMPACT: ",JSON.stringify(report))
	for message in errors:printerr("FAIL: ",message)
	arena.queue_free();for i in 3:await process_frame
	quit(0 if errors.is_empty() else 1)
