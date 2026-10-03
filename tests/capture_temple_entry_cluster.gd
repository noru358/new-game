extends "res://tests/capture_regional_landmarks.gd"
## First decision image: one960 camera reached by actual court->cloister movement.
## Frozen encounter pressure and fixed real telegraph, not live-combat evidence.
const Cluster = preload("res://game/temple_entry_cluster.gd")
var requested_size:=Vector2i(960,540)
var walking:=false
var visibility_failures:Array[String]=[]
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
	expected_screenshots=0
	var sizes:Array=[Vector2i(960,540),Vector2i(1280,720)] if OS.get_cmdline_user_args().has("--entry-all-sizes") else [Vector2i(960,540)]
	for size in sizes:
		requested_size=size
		root.size=size;root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		scene=load("res://game/temple_circuit_run.tscn").instantiate()
		scene.profile_save_prefix="user://entry_profile_"+str(size.x);scene.growth_save_prefix="user://entry_growth_"+str(size.x)
		root.add_child(scene);current_scene=scene
		for connection in root.focus_exited.get_connections():root.focus_exited.disconnect(connection.callable)
		scene._set_paused(false);scene.practice_mode=true
		scene.wisp.set_physics_process(false)
		for actor in scene.actors:
			if actor!=scene.player:actor.set_physics_process(false)
		Cluster.install(scene)
		for i in 5:await physics_frame
		for point in [Vector2(2450,2100),Vector2(1650,2275),Vector2(1590,1840)]:
			walking=true;await _walk(point);walking=false;_release()
			if not errors.is_empty():break
		var targets:Array=[{"name":"entry","at":Vector2(1450,1700)}]
		if sizes.size()>1:targets.append_array([{"name":"wall-shoulder","at":Vector2(1695,1310)},{"name":"cloister","at":Vector2(1450,1350)}])
		for target in targets:
			if not errors.is_empty():break
			walking=true;await _walk(target.at);walking=false;_release()
			if not errors.is_empty():break
			var record:Dictionary={"name":target.name,"width":size.x,"height":size.y,"target":_point(target.at),"reached":_point(scene.player.position),"approach":"normal input: court to west stairs, original northbound cloister route and right shoulder; no teleport","camera_size":scene.camera.size,"run_time_frozen":scene.run_time}
			_check_follow(target.name,record)
			if errors.is_empty() and not measure_only:
				expected_screenshots+=2
				await _capture_checkpoint(target.name,size.x,record)
				if OS.get_cmdline_user_args().has("--entry-all-sizes"):
					var remaining:Array[String]=[]
					for message in errors:
						if message.begins_with("Player scenery visibility below") or message.begins_with("Enemy Body visibility below") or message.begins_with("Enemy tell visibility below"):visibility_failures.append(message)
						else:remaining.append(message)
					errors=remaining
			records.append(record)
		await _free_scene()
		if not errors.is_empty():break
	await _finish()
func _walk(goal:Vector2) -> void:
	await super._walk(goal)
	for frame in 120:
		var expected:Vector3=scene.terrain.world_point(scene.player.position,35)+scene.camera_offset
		if scene.camera.position.distance_to(expected)<0.01:return
		await physics_frame
	errors.append("Normal camera follow failed to settle")
func _capture_checkpoint(label:String,width:int,record:Dictionary) -> void:
	for tag in scene.find_children("*","Label3D",true,false):tag.hide()
	var point:Vector2=scene.player.position+Vector2(-90,-80)
	if not scene.navigation.is_open(point,30) or not scene.clear_attack(point,scene.player.position):
		errors.append("Illegal fixed enemy fixture at "+label);return
	var enemy:TrainingEnemy=scene._spawn_enemy_at(point,TrainingEnemy.Role.BEAST,40.0)
	enemy.set_physics_process(false);enemy.warning_time=0.3;enemy.locked_direction=point.direction_to(scene.player.position)
	for i in 3:await process_frame
	scene._draw_enemy_warnings(1.0)
	record.fixed_enemy_tell={"point":_point(point),"warning_surfaces":scene.warning_mesh.get_surface_count(),"scope":"fixed actual enemy Body/tell; not live combat"}
	await super._capture_checkpoint(label,width,record)
	scene.set_process(false);scene.set_physics_process(false);scene.player.set_physics_process(false)
	var visual:Node3D=scene.actors[enemy]
	record.player_scenery_visibility=await _geometry_visibility(scene.actors[scene.player].get_node("Body"),80,label+"-hero",width)
	record.enemy_body_visibility=await _geometry_visibility(visual.get_node("Body"),80,label+"-enemy",width)
	record.enemy_tell_visibility=await _geometry_visibility(scene.warning_visual,200,label+"-tell",width,scene.terrain.world_point(enemy.position))
	if record.player_scenery_visibility.get("ratio",0.0)<0.98:errors.append("Player scenery visibility below98% at "+label)
	if record.enemy_body_visibility.get("ratio",0.0)<0.98:errors.append("Enemy Body visibility below98% at "+label)
	if record.enemy_tell_visibility.get("ratio",0.0)<0.95:errors.append("Enemy tell visibility below95% at "+label)
	scene.player.set_physics_process(true);scene.set_process(true);scene.set_physics_process(true)
	visual.queue_free();scene.actors.erase(enemy);scene.actor_motion.erase(enemy);enemy.queue_free()
	for i in 3:await process_frame
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
	errors.append("Exact native drawable failed to settle");return null
func _finish() -> void:
	if finished:return
	errors.append_array(visibility_failures)
	finished=true
	await _free_scene()
	if screenshots.size()!=expected_screenshots:errors.append("Screenshot count differs from expected")
	var report:Dictionary={"scope":"normal input court-to-cloister decision image; frozen encounter pressure and fixed real telegraph; no live-combat or human-art acceptance","engine":Engine.get_version_info().string,"normal_input":true,"teleport":false,"active_walk_seconds":active_seconds,"resolutions":[[960,540],[1280,720]] if OS.get_cmdline_user_args().has("--entry-all-sizes") else [[960,540]],"render":not measure_only and not screenshots.is_empty(),"samples":records,"screenshots":screenshots,"errors":errors}
	var file:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "));file.close()
	print("ENTRY_CLUSTER_RENDER: ",JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)

func _geometry_visibility(geometry: GeometryInstance3D, radius: int, label: String, width: int, at: Vector3 = Vector3.INF) -> Dictionary:
	var normal := await _image()
	geometry.hide()
	var normal_without := await _image()
	geometry.show()
	var hidden: Array[GeometryInstance3D] = []
	for node in scene.find_children("*","GeometryInstance3D",true,false):
		if node == scene.warning_visual or not node.visible: continue
		var actor_geometry := false
		for actor in scene.actors.values():
			if actor.is_ancestor_of(node): actor_geometry = true
		if actor_geometry: continue
		hidden.append(node)
		node.hide()
	var reference := await _image()
	geometry.hide()
	var reference_without := await _image()
	geometry.show()
	for node in hidden: node.show()
	if normal == null or normal_without == null or reference == null or reference_without == null: return {}
	expected_screenshots += 1
	_save(reference,"%s-reference-%d.png" % [label,width])
	var logical_rect: Rect2 = scene.camera.get_viewport().get_visible_rect()
	var center: Vector2 = (scene.camera.unproject_position(geometry.global_position if at == Vector3.INF else at) - logical_rect.position) * Vector2(normal.get_size()) / logical_rect.size
	var roi := Rect2i(Vector2i(center) - Vector2i(radius,radius),Vector2i(radius*2,radius*2)).intersection(Rect2i(Vector2i.ZERO,normal.get_size()))
	var potential := 0
	var visible := 0
	for y in range(roi.position.y,roi.end.y):
		for x in range(roi.position.x,roi.end.x):
			if _different(reference.get_pixel(x,y),reference_without.get_pixel(x,y)):
				potential += 1
				if _different(normal.get_pixel(x,y),normal_without.get_pixel(x,y)): visible += 1
	if potential < 50: errors.append("Unusable Body/telegraph pixel reference at " + label)
	return {"reference_pixels":potential,"normal_pixels":visible,"ratio":float(visible)/maxf(1.0,potential),"roi":[roi.position.x,roi.position.y,roi.size.x,roi.size.y],"scope":"fixed real enemy Body/telegraph differential, scenery hidden reference with same actors; bounded sample"}
