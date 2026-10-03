extends SceneTree
## Live 60Hz AI/input sample, separate from frozen differential visibility captures.
const Finish = preload("res://game/temple_surface_sample.gd")
const ACTIONS := ["move_left","move_right","move_up","move_down","attack"]
var scene
var errors: Array[String] = []
var records: Array = []
var output := ""
var measure := false
var started := 0
func _initialize() -> void: call_deferred("_run")
func _process(_delta: float) -> bool:
	if started > 0 and Time.get_ticks_msec()-started > 90000:
		printerr("FAIL: live fixture90-second watchdog"); quit(1)
	return false
func _input(direction: Vector2, attack: bool) -> void:
	var d: Vector2 = direction.rotated(-scene.player.input_rotation)
	var values := [maxf(0,-d.x),maxf(0,d.x),maxf(0,-d.y),maxf(0,d.y),1.0 if attack else 0.0]
	for i in ACTIONS.size():
		var event := InputEventAction.new()
		event.action = ACTIONS[i]; event.strength = values[i]; event.pressed = values[i] > 0.0
		Input.parse_input_event(event)
func _run() -> void:
	started = Time.get_ticks_msec()
	root.mode = Window.MODE_WINDOWED
	output = OS.get_environment("TEMPLE_SURFACE_OUTPUT")
	measure = OS.get_cmdline_user_args().has("--measure-only")
	if output.is_empty() or not output.is_absolute_path() or not OS.get_user_data_dir().contains("TempleSurfaceSample/"):
		printerr("FAIL: fresh output and isolated TempleSurfaceSample UUID data required")
		quit(1); return
	if DirAccess.dir_exists_absolute(output) and not DirAccess.get_files_at(output).is_empty():
		printerr("FAIL: evidence output must be fresh"); quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	Engine.time_scale = 1.0
	Engine.max_fps = 60
	for size in [Vector2i(960,540),Vector2i(1280,720)]:
		root.size = size
		root.content_scale_size = Vector2i(1280,720)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		for i in 5: await process_frame
		for sample in [{"name":"court","at":Vector2(2450,2100)},{"name":"cloister","at":Vector2(1450,1350)}]:
			scene = load("res://game/temple_circuit_run.tscn").instantiate()
			scene.profile_save_prefix = "user://combat_profile_"+sample.name+str(size.x)
			scene.growth_save_prefix = scene.profile_save_prefix+"_unlocks"
			root.add_child(scene); current_scene = scene
			for connection in root.focus_exited.get_connections(): root.focus_exited.disconnect(connection.callable)
			scene._set_paused(false)
			scene.rng.seed = 4913
			scene.spawn_credit = -100000.0
			scene.growth.growth_ended = true
			scene.wisp.set_physics_process(false)
			Finish.install(scene)
			scene.teleport(sample.at)
			for i in 60: await physics_frame
			var beast: TrainingEnemy = scene._spawn_enemy_at(sample.at+Vector2(90,-80),TrainingEnemy.Role.BEAST,80.0)
			var lamp: TrainingEnemy = scene._spawn_enemy_at(sample.at+Vector2(-75,125),TrainingEnemy.Role.LAMP,80.0)
			var warning_frames := 0
			var attack_frames := 0
			var distance := 0.0
			var captures: Array = []
			var frame_times: Array[float] = []
			var last := Time.get_ticks_usec()
			for frame in 600:
				var angle := float(frame)*TAU/300.0
				var goal: Vector2 = sample.at+Vector2(cos(angle)*65.0,sin(angle)*95.0)
				var before: Vector2 = scene.player.position
				_input(before.direction_to(goal) if before.distance_to(goal)>5.0 else Vector2.ZERO,frame>75)
				await physics_frame
				distance += before.distance_to(scene.player.position)
				var now := Time.get_ticks_usec()
				frame_times.append(float(now-last)/1000.0); last=now
				if scene.attack_mesh.get_surface_count() > 0: attack_frames += 1
				var live_enemy_warning := (is_instance_valid(beast) and beast.warning_time > 0.0) or (is_instance_valid(lamp) and lamp.warning_time > 0.0)
				if live_enemy_warning and scene.warning_mesh.get_surface_count() > 0:
					warning_frames += 1
					if not measure and captures.is_empty():
						await RenderingServer.frame_post_draw
						var filename: String = sample.name+"-live-warning-"+str(size.x)+".png"
						root.get_texture().get_image().save_png(output.path_join(filename))
						captures.append(filename)
				if scene.run_ended: errors.append("live sample ended at "+sample.name); break
			_input(Vector2.ZERO,false)
			var fired := (beast.attacks_fired if is_instance_valid(beast) else 0)+(lamp.attacks_fired if is_instance_valid(lamp) else 0)
			if distance < 500: errors.append("insufficient ordinary movement at "+sample.name)
			if warning_frames == 0 or attack_frames == 0: errors.append("missing live warning/attack at "+sample.name)
			frame_times.sort()
			records.append({"place":sample.name,"resolution":[size.x,size.y],"distance":distance,"active_seconds":scene.run_time,"warning_frames":warning_frames,"attack_frames":attack_frames,"surviving_enemies_attacks_fired":fired,"kills":scene.kills,"health":scene.player.health,"camera_size":scene.camera.size,"captures":captures,"frame_interval_median_ms":frame_times[frame_times.size()/2],"frame_interval_p95_ms":frame_times[int(frame_times.size()*0.95)]})
			scene.queue_free(); current_scene=null
			for i in 3: await process_frame
	var report := {"errors":errors,"complete":errors.is_empty(),"variant":"baseline" if OS.get_cmdline_user_args().has("--temple-surface-baseline") else "candidate","engine":Engine.get_version_info().string,"records":records,"scope":"Normal 60Hz movement/attack/AI/time. Synthetic placement and two80HP enemies per place; ambient arrivals/growth modal/wisp suppressed equally. No natural progression, human fun, sound or sustained performance verdict."}
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")+"\n"); file.close()
	print("TEMPLE_SURFACE_COMBAT: ",JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
