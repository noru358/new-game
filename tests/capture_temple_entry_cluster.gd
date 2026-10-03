extends "res://tests/capture_temple_place_sequence.gd"
## First decision image: one960 camera reached by actual court->cloister movement.
## Frozen encounter pressure and fixed real telegraph, not live-combat evidence.
const Cluster = preload("res://game/temple_entry_cluster.gd")
var requested_size:=Vector2i(960,540)
var walking:=false
func _initialize() -> void:
	root.mode=Window.MODE_WINDOWED
	super._initialize()
func _process(delta:float) -> bool:
	if not walking: _release()
	return super._process(delta)
func _run() -> void:
	started=Time.get_ticks_usec()
	output=OS.get_environment("REGIONAL_LANDMARK_OUTPUT"); region="temple"
	measure_only=OS.get_cmdline_user_args().has("--measure-only")
	if output.is_empty() or not output.is_absolute_path() or not OS.get_user_data_dir().contains("TempleEntryCluster/"):
		printerr("FAIL: isolated TempleEntryCluster userdata and absolute output required");quit(1);return
	if DirAccess.dir_exists_absolute(output) and not DirAccess.get_files_at(output).is_empty():
		printerr("FAIL: fresh output required");quit(1);return
	DirAccess.make_dir_recursive_absolute(output)
	Engine.time_scale=1.0;Engine.max_fps=60
	expected_screenshots=0 if measure_only else 2
	root.size=requested_size;root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	scene=load("res://game/temple_circuit_run.tscn").instantiate()
	scene.profile_save_prefix="user://entry_profile";scene.growth_save_prefix="user://entry_growth"
	root.add_child(scene);current_scene=scene
	for connection in root.focus_exited.get_connections():root.focus_exited.disconnect(connection.callable)
	scene._set_paused(false);scene.practice_mode=true
	scene.wisp.set_physics_process(false)
	for actor in scene.actors:
		if actor!=scene.player:actor.set_physics_process(false)
	Cluster.install(scene)
	for i in 5:await physics_frame
	for point in [Vector2(2450,2100),Vector2(1650,2275),Vector2(1590,1840),Vector2(1450,1700)]:
		walking=true;await super._walk(point);walking=false;_release()
		if not errors.is_empty():break
	if errors.is_empty():
		var record:Dictionary={"name":"06-cloister","width":960,"height":540,"target":[1450,1700],"first_candidate_target":[1590,1840],"previous_candidate_target":[1450,1700],"reached":_point(scene.player.position),"approach":"normal input: entry to court, west stairs, past previous viewpoint, northward to actual cloister entry; no teleport","cluster_offset":[0,0,0],"replacement_scope":"entire original GALLERY_HALL wall ornament (1730,1190,420,500); plateau remains","active_walk_seconds":active_seconds,"camera_size":scene.camera.size,"camera_position":[scene.camera.position.x,scene.camera.position.y,scene.camera.position.z],"run_time_frozen":scene.run_time}
		_check_follow("entry-group",record)
		var mesh_projected:Dictionary={}
		if scene.has_node("TempleEntryCluster"):
			for visual in scene.get_node("TempleEntryCluster").get_children():
				var bounds:AABB=visual.get_aabb();var screen_bounds:=Rect2();var first:=true
				for x in [bounds.position.x,bounds.end.x]:
					for y in [bounds.position.y,bounds.end.y]:
						for z in [bounds.position.z,bounds.end.z]:
							var p:Vector2=scene.camera.unproject_position(visual.to_global(Vector3(x,y,z)))
							if first:screen_bounds=Rect2(p,Vector2.ZERO);first=false
							else:screen_bounds=screen_bounds.expand(p)
				mesh_projected[visual.name]=[screen_bounds.position.x,screen_bounds.position.y,screen_bounds.size.x,screen_bounds.size.y]
			record.cluster_projected_bounds=mesh_projected
		if errors.is_empty() and not measure_only:await _capture_checkpoint("06-cloister",960,record)
		records.append(record)
	await _finish()
func _release() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):continue
		var event:=InputEventAction.new();event.action=action;event.pressed=false;event.strength=0
		Input.parse_input_event(event);Input.action_release(action)
func _image() -> Image:
	for attempt in 30:
		root.size=requested_size
		for i in 3:await process_frame
		RenderingServer.force_draw(false)
		var frame:=root.get_texture().get_image()
		if frame!=null and not frame.is_empty() and frame.get_size()==requested_size:return frame
	errors.append("Exact960 drawable failed to settle");return null
func _finish() -> void:
	if finished:return
	finished=true
	await _free_scene()
	if screenshots.size()!=expected_screenshots:errors.append("Screenshot count differs from expected")
	var report:Dictionary={"scope":"normal input court-to-cloister decision image; frozen encounter pressure and fixed real telegraph; no live-combat or human-art acceptance","engine":Engine.get_version_info().string,"normal_input":true,"teleport":false,"active_walk_seconds":active_seconds,"resolutions":[[960,540]],"render":not measure_only and not screenshots.is_empty(),"samples":records,"screenshots":screenshots,"errors":errors}
	var file:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "));file.close()
	print("ENTRY_CLUSTER_RENDER: ",JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
