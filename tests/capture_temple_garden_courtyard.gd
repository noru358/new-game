extends "res://tests/capture_regional_landmarks.gd"
## Existing fixed-input/render fixture adapted for the complete hidden round trip.
## Only initial main return placement is injected. Both portal crossings use normal
## input and the real section tick. Guardian delay/time pressure is frozen.
const Courtyard = preload("res://game/temple_garden_courtyard_data.gd")
var capture_frozen := false
var visibility_failures: Array[String] = []
func _run() -> void:
	started = Time.get_ticks_usec()
	output = OS.get_environment("GARDEN_RENDER_OUTPUT")
	region = "temple-garden"
	measure_only = OS.get_cmdline_user_args().has("--measure-only")
	if output.is_empty() or not output.is_absolute_path() or not "TempleGardenV50" in OS.get_user_data_dir():
		printerr("FAIL: absolute output and isolated TempleGardenV50 userdata required before profiles")
		quit(1);return
	if DirAccess.dir_exists_absolute(output) and not DirAccess.get_files_at(output).is_empty():
		printerr("FAIL: fresh output required");quit(1);return
	DirAccess.make_dir_recursive_absolute(output)
	if not measure_only and DisplayServer.get_name()=="headless":
		printerr("FAIL: real renderer required");quit(1);return
	Engine.time_scale=1.0
	Engine.max_fps=60
	expected_screenshots=0
	for size in SIZES:
		root.size=size
		root.content_scale_size=Vector2i(1280,720)
		root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		scene=load("res://game/temple_circuit_run.tscn").instantiate()
		scene.profile_save_prefix="user://garden_walk_%d_%d_profile"%[size.x,Time.get_ticks_usec()]
		scene.growth_save_prefix=scene.profile_save_prefix+"_growth"
		root.add_child(scene)
		current_scene=scene
		scene.practice_mode=true
		scene.wisp.set_physics_process(false)
		for actor in scene.actors:
			if actor!=scene.player:actor.set_physics_process(false)
		# Explicit starting fixture; all subsequent travel uses unaccelerated input.
		scene.teleport(scene.temple_section.layout.RETURN_POINT)
		for i in 5:await physics_frame
		await _record("00-main-cloister",scene.temple_section.layout.RETURN_POINT,size.x,active_seconds)
		var before_enter:=active_seconds
		await _walk(scene.temple_section.layout.ENTRY_TRIGGER.get_center())
		if not scene.temple_section.in_garden:errors.append("Normal entrance input did not enter garden")
		await _record("01-threshold",Courtyard.Garden.FIELD_ENTRY,size.x,before_enter)
		for sample in Courtyard.WALK_POINTS:
			if sample.name=="threshold":continue
			if not scene.navigation.is_open(sample.point,30):
				errors.append("Blocked sample "+sample.name);break
			var before:=active_seconds
			await _walk(sample.point)
			await _record(sample.name,sample.point,size.x,before)
			if not errors.is_empty():break
		if not measure_only:
			# Separately labeled static overview, unchanged game overview camera.
			scene.overview=true
			scene.camera.size=scene.overview_camera_size
			await create_timer(1.0).timeout
			_save(await _image(),"overview-static-%d.png"%size.x)
			expected_screenshots+=1
			scene.overview=false
			scene.camera.size=scene.combat_camera_size
		var before_exit:=active_seconds
		await _walk(scene.temple_section.layout.EXIT_TRIGGER.get_center())
		if scene.temple_section.in_garden:errors.append("Normal exit input did not return")
		await _record("12-main-return",scene.temple_section.layout.RETURN_POINT,size.x,before_exit)
		await _free_scene()
		if not errors.is_empty():break
	errors.append_array(visibility_failures)
	await _finish()

func _record(label: String, target: Vector2, width: int, before: float) -> void:
	await create_timer(0.8).timeout
	# Let normal camera follow settle; never reset transforms for a successful check.
	for frame in 120:
		var expected: Vector3=scene.terrain.world_point(scene.player.position,35)+scene.camera_offset
		if scene.camera.position.distance_to(expected)<0.01:break
		await physics_frame
	var record: Dictionary={"name":label,"width":width,"target":_point(target),"reached":_point(scene.player.position),"active_walk_seconds":active_seconds-before,"render":false,"camera_size":scene.camera.size,"move_speed":scene.player.MOVE_SPEED,"move_speed_multiplier":scene.player.move_speed_multiplier,"run_time_frozen":scene.run_time,"in_garden":scene.temple_section.in_garden,"scope":"normal movement and real portals; initialized main-return placement, guardian delays/time frozen"}
	_check_follow(label,record)
	if not measure_only and errors.is_empty():
		expected_screenshots+=2
		capture_frozen=true
		await _capture_checkpoint(label,width,record)
		capture_frozen=false
	records.append(record)
	print("GARDEN_CHECKPOINT: ",JSON.stringify(record))

func _walk(goal: Vector2) -> void:
	var initial_field: bool=scene.temple_section.in_garden
	if scene.player.position.distance_to(goal)<=5:return
	var route: PackedVector2Array=scene.navigation.find_path(scene.player.position,goal)
	if route.is_empty():errors.append("No navigation route to "+str(goal));return
	route.append(goal)
	var wall_start:=Time.get_ticks_usec()
	var last_motion:=wall_start
	var last_position:Vector2=scene.player.position
	for target in route:
		while scene.player.position.distance_to(target)>5:
			if scene.temple_section.in_garden!=initial_field:_release();return
			var now:=Time.get_ticks_usec()
			if now-wall_start>180000000 or now-last_motion>5000000:
				errors.append("Walk stall at "+str(scene.player.position)+" goal "+str(goal));_release();return
			if scene.player.position.distance_to(last_position)>2:
				last_position=scene.player.position;last_motion=now
			var direction:Vector2=scene.player.position.direction_to(target).rotated(-scene.player.input_rotation)
			_release()
			Input.action_press("move_left",maxf(0.0,-direction.x))
			Input.action_press("move_right",maxf(0.0,direction.x))
			Input.action_press("move_up",maxf(0.0,-direction.y))
			Input.action_press("move_down",maxf(0.0,direction.y))
			await physics_frame
			active_seconds+=1.0/Engine.physics_ticks_per_second
	_release()

func _process(delta: float) -> bool:
	if is_instance_valid(scene) and not capture_frozen:
		for warning in scene.temple_section.guard_warnings:
			warning.delay=100000.0
			warning.marker.hide()
		scene.temple_section.tick(delta)
	return super._process(delta)

func _capture_checkpoint(label: String,width: int,record: Dictionary) -> void:
	for tag in scene.find_children("*","Label3D",true,false):tag.hide()
	var enemy:TrainingEnemy
	if label in ["west_pond","rooted_bank","east_pond"]:
		var point:Vector2=scene.player.position+Vector2(110,-100)
		if not scene.navigation.is_open(point,30) or not scene.clear_attack(point,scene.player.position):
			errors.append("Fixed tell point not legal at "+label);return
		enemy=scene._spawn_enemy_at(point,TrainingEnemy.Role.LAMP if label=="east_pond" else TrainingEnemy.Role.BEAST,40.0)
		enemy.set_physics_process(false)
		enemy.warning_time=0.3
		enemy.locked_direction=point.direction_to(scene.player.position)
		for i in 3:await process_frame
		scene._draw_enemy_warnings(1.0)
		record["fixed_enemy_tell"]={"role":enemy.role,"point":_point(point),"warning_surfaces":scene.warning_mesh.get_surface_count(),"scope":"frozen real enemy/tell, no difficulty claim"}
	# Direct base method avoids the old main-map tell labels.
	await super._capture_checkpoint(label,width,record)
	if is_instance_valid(enemy):
		scene.set_process(false);scene.set_physics_process(false);scene.player.set_physics_process(false)
		record["player_scenery_visibility"]=await _geometry_visibility(scene.actors[scene.player].get_node("Body"),80,label+"-hero",width)
		record["enemy_body_visibility"]=await _geometry_visibility(scene.actors[enemy].get_node("Body"),80,label+"-enemy",width)
		record["enemy_tell_visibility"]=await _geometry_visibility(scene.warning_visual,200,label+"-tell",width,scene.terrain.world_point(enemy.position))
		for key in ["player_scenery_visibility","enemy_body_visibility"]:
			if record[key].get("ratio",0.0)<0.98:visibility_failures.append("Body scenery visibility below98% at "+label+" "+key)
		if record.enemy_tell_visibility.get("ratio",0.0)<0.95:visibility_failures.append("Tell visibility below95% at "+label)
		scene.set_process(true);scene.set_physics_process(true);scene.player.set_physics_process(true)
		scene.actors[enemy].queue_free();scene.actors.erase(enemy);scene.actor_motion.erase(enemy);enemy.queue_free()
		for i in 3:await process_frame
	elif record.has("visibility") and record.visibility.ratio<0.98:visibility_failures.append("Body visibility below98% at "+label)

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
