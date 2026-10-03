extends SceneTree
var arena
var output := ""
var region := "temple"
var frames: Array = []
var phase := ""
var last_usec := 0
var recording := false
var report: Dictionary = {}
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--region="): region = arg.trim_prefix("--region=")
	if output.is_empty() or not OS.get_user_data_dir().get_file().begins_with("CodexV49Lag-"):
		printerr("Profiling requires an output path and an isolated CodexV49Lag UUID user directory")
		quit(2)
		return
	call_deferred("run")
func run():
	preload("res://game/field_preview_session.gd").activate(self)
	var profile=RunProfile.new()
	profile.save_prefix="user://first_region_shared_v45_profile"
	profile.load_state()
	profile.settle("synthetic-jungle-access", "SUCCESS",0,RunProfile.TEMPLE_REGION)
	var scene := "res://game/temple_circuit_run.tscn" if region == "temple" else "res://game/jungle_south_circuit.tscn"
	arena = load(scene).instantiate()
	root.add_child(arena)
	current_scene = arena
	root.size = Vector2i(1280,720)
	arena.practice_mode = true
	arena.paused = false
	paused = false
	arena.player.global_position = Vector2(2450,2100) if region == "temple" else Vector2(650,1210)
	arena.player.max_health = 1e9
	arena.player.health = 1e9
	arena.actor_motion[arena.player] = [arena.player.global_position,arena.player.global_position]
	arena.camera.position = arena.terrain.world_point(arena.player.global_position,35) + arena.camera_offset
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	RenderingServer.frame_post_draw.connect(sample_frame)
	report = {"region":region,"engine":Engine.get_version_info(),"os":OS.get_name(),"renderer":RenderingServer.get_current_rendering_method(),"window":str(root.size),"viewport":str(root.get_visible_rect()),"vsync":DisplayServer.window_get_vsync_mode(),"screen_hz":DisplayServer.screen_get_refresh_rate(),"callback":"frame_post_draw","physics_ticks":Engine.physics_ticks_per_second,"time_scale":Engine.time_scale,"fixed_fps":false,"scope":"native wall-clock paced renderer; stationary synthetic player, controlled mixed-role live enemies, huge HP to preserve counts; normal AI/physics/visuals/wisp, auto spawn/level-up disabled; not human play FPS","phases":[]}
	for count in [0,8,72]:
		for enemy in get_nodes_in_group("training_enemies"): enemy.queue_free()
		for shot in get_nodes_in_group("wisp_projectiles"): shot.queue_free()
		for shot in get_nodes_in_group("enemy_bolts"): shot.queue_free()
		await process_frame
		for i in count:
			var theta: float = TAU*float(i)/maxi(count,1)
			var point: Vector2 = arena.player.global_position + Vector2.from_angle(theta) * (175.0+float(i%3)*20.0)
			arena._spawn_enemy_at(point,i%5,1e9)
		phase = str(count)
		print("PROFILE_PHASE warmup ",phase)
		await create_timer(5.0).timeout
		frames=[]
		last_usec=Time.get_ticks_usec()
		recording=true
		print("PROFILE_PHASE sample ",phase)
		await create_timer(20.0).timeout
		recording=false
		report.phases.append({"enemies":count,"frames":frames})
		var f=FileAccess.open(output,FileAccess.WRITE)
		f.store_string(JSON.stringify(report))
		f.close()
		root.get_texture().get_image().save_png(output.trim_suffix(".json")+"-"+phase+".png")
		print("PROFILE_PHASE done ",phase," frames=",frames.size())
	quit()
func sample_frame():
	if is_instance_valid(arena) and arena.paused and not arena.run_ended:arena._set_paused(false)
	if recording:
		var now=Time.get_ticks_usec()
		frames.append([float(now-last_usec)/1000.0,Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()),RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),Performance.get_monitor(Performance.OBJECT_NODE_COUNT),Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS),Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS),Performance.get_monitor(Performance.PHYSICS_2D_ISLAND_COUNT)])
		last_usec=now
