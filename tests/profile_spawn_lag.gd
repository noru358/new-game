extends SceneTree
var arena
var frames: Array=[]
var last_usec:=0
var recording:=false
var output:=""
var region:="temple"
var report:Dictionary={}
var route: Array=[]
var route_index:=0
var waypoint:=0
var path:=PackedVector2Array()
var walk_enabled:=false
var attacks:=false
var focus_resumes:=0
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--region="): region=arg.trim_prefix("--region=")
		if arg=="--walk": walk_enabled=true
		if arg=="--combat": attacks=true
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
	arena=load("res://game/temple_circuit_run.tscn" if region=="temple" else "res://game/jungle_south_circuit.tscn").instantiate()
	root.add_child(arena)
	current_scene=arena
	root.size=Vector2i(1280,720)
	arena.rng.seed=481
	arena.player.health=1e9
	arena.player.max_health=1e9
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	RenderingServer.frame_post_draw.connect(sample_frame)
	if walk_enabled:
		route=[Vector2(1350,2800),Vector2(1650,2275),Vector2(2450,2100),Vector2(1450,1900),Vector2(1450,1350),Vector2(1650,910),Vector2(2650,1000)] if region=="temple" else [Vector2(720,1210),Vector2(1410,1180),Vector2(2175,1180),Vector2(2850,1140),Vector2(3010,2050),Vector2(3010,2440)]
		path=arena.navigation.find_path(arena.player.position,route[0])
	physics_frame.connect(steer)
	await create_timer(5.0).timeout
	last_usec=Time.get_ticks_usec()
	recording=true
	print("PROFILE_SAMPLE natural spawn ",region)
	await create_timer(60.0).timeout
	recording=false
	report={"region":region,"scope":"native real-time source scene, normal ambient spawns/AI, optional Input movement/combat, synthetic high-HP player; level choices auto-dismissed; not human play FPS","frames":frames,"walk":walk_enabled,"combat":attacks,"position":str(arena.player.position),"route_index":route_index,"focus_resumes":focus_resumes,"active_seconds":arena.run_time}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report))
	root.get_texture().get_image().save_png(output.trim_suffix(".json")+".png")
	quit()
func sample_frame():
	if is_instance_valid(arena) and arena.paused and not arena.run_ended:
		FocusResume()
	if is_instance_valid(arena) and arena.growth.choosing:
		arena.growth.choose_index(0)
	if recording:
		var now=Time.get_ticks_usec()
		frames.append([float(now-last_usec)/1000.0,arena._active_enemy_count(),Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()),Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
		last_usec=now

func FocusResume():
	arena._set_paused(false)
	focus_resumes+=1
func steer():
	if not is_instance_valid(arena): return
	for action in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)
	if not walk_enabled or route_index>=route.size():return
	if path.is_empty():
		print("NO_PATH ",route[route_index]);route_index+=1
		if route_index<route.size():path=arena.navigation.find_path(arena.player.position,route[route_index])
		waypoint=0
		return
	while waypoint<path.size() and arena.player.position.distance_to(path[waypoint])<24:waypoint+=1
	if waypoint>=path.size():
		route_index+=1;waypoint=0
		if route_index<route.size():path=arena.navigation.find_path(arena.player.position,route[route_index])
		return
	var input:Vector2=arena.player.position.direction_to(path[waypoint]).rotated(-arena.player.input_rotation)
	if input.x < -0.2: Input.action_press("move_left",-input.x)
	if input.x > 0.2: Input.action_press("move_right",input.x)
	if input.y < -0.2: Input.action_press("move_up",-input.y)
	if input.y > 0.2: Input.action_press("move_down",input.y)
	if attacks:
		if int(Time.get_ticks_msec()/500)%2==0:Input.action_press("attack")
		else:Input.action_release("attack")
