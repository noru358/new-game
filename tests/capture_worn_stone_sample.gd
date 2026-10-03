extends SceneTree
const Kit = preload("res://game/jungle_worn_stone_visuals.gd")
const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "attack"]
var scene
var failures: Array = []
var output := ""
var walks: Array = []
var costs: Array = []
var settled_costs: Array = []
var warnings_seen := false
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)
func _input(direction: Vector2, attacking: bool) -> void:
	var d: Vector2 = direction.rotated(-scene.player.input_rotation)
	var values := [maxf(0,-d.x),maxf(0,d.x),maxf(0,-d.y),maxf(0,d.y),1.0 if attacking else 0.0]
	for i in ACTIONS.size():
		var event := InputEventAction.new()
		event.action = ACTIONS[i]
		event.strength = values[i]
		event.pressed = values[i] > 0.0
		Input.parse_input_event(event)
func _walk(goal: Vector2) -> void:
	var ticks := 0
	var distance := 0.0
	while scene.player.position.distance_to(goal) > 7.0 and ticks < 600 and not scene.run_ended:
		var before: Vector2 = scene.player.position
		_input(before.direction_to(goal), true)
		await physics_frame
		distance += before.distance_to(scene.player.position)
		warnings_seen = warnings_seen or scene.warning_vertex_count > 0
		ticks += 1
	_input(Vector2.ZERO, false)
	check(scene.player.position.distance_to(goal) < 7, "ordinary input reaches sample goal")
	walks.append({"goal":[goal.x,goal.y],"ticks":ticks,"distance":distance,"height":scene.terrain.height_at(scene.player.position),"hp":scene.player.health})
func _capture(label: String) -> void:
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	check(frame != null and not frame.is_empty(), "native frame")
	if frame != null: check(frame.save_png(output.path_join(label+".png")) == OK, "capture saved")
	costs.append({"label":label,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"render_objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"render_primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
func _run() -> void:
	output = OS.get_environment("WORN_OUTPUT")
	if output.is_empty() or not OS.get_user_data_dir().contains("LoopConquestMapTrials/"):
		printerr("FAIL: isolated userdata and explicit output required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var large := OS.get_cmdline_user_args().has("--large")
	root.size = Vector2i(1280,720) if large else Vector2i(960,540)
	root.position = Vector2i(-1800,0)
	root.content_scale_size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	Engine.time_scale = 1.0
	Engine.max_fps = 60
	scene = load("res://game/jungle_pass.tscn").instantiate()
	scene.profile_save_prefix = "user://worn_profile"
	scene.growth_save_prefix = "user://worn_unlocks"
	var terrain_before: String = var_to_str([scene.terrain.ramps,scene.terrain.wall_areas,scene.terrain.plateaus,scene.terrain.floor_areas,scene.terrain.water_areas])
	root.add_child(scene)
	current_scene = scene
	await physics_frame
	for c in root.focus_exited.get_connections(): root.focus_exited.disconnect(c.callable)
	scene._set_paused(false)
	scene.rng.seed = 4243
	scene.spawn_credit = -100000.0
	scene.growth.growth_ended = true
	var meshes := 0
	var surfaces := 0
	var triangles := 0
	var transforms: Array = []
	for node in scene.get_children():
		if not node is MeshInstance3D: continue
		if not node.has_meta("worn_stone_kind"): continue
		meshes += 1
		surfaces += node.mesh.get_surface_count()
		triangles += node.mesh.surface_get_array_len(0) / 3 if node.mesh is ArrayMesh else 12
		transforms.append({"kind":node.get_meta("worn_stone_kind"),"transform":var_to_str(node.transform),"material":var_to_str(node.material_override.albedo_color)})
	check(meshes == 18 and surfaces == 18, "same 18 decor instances/surfaces")
	# Every replacement is contained by the old local box, preserving height.
	for seed in 10:
		var size := Vector3(0.38,0.44+float(seed%5%3)*0.17,0.52)
		var mesh := Kit.rock_mesh(size,seed)
		for v in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			check(absf(v.x) <= size.x*0.501 and absf(v.y) <= size.y*0.501 and absf(v.z) <= size.z*0.501, "rock within old box")
	for seed in 3:
		var size := Vector3(0.24,0.62,0.30)
		for v in Kit.post_mesh(size,seed).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			check(absf(v.x) <= size.x*0.501 and absf(v.y) <= size.y*0.501 and absf(v.z) <= size.z*0.501, "post within old box")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	Kit.append_treads(st,scene.terrain.ramps[3],func(p):return scene.terrain.ramp_height(scene.terrain.ramps[3],p),Color.WHITE)
	var tread_mesh := st.commit()
	for v in tread_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var p := Vector2(v.x,v.z)/Kit.SCALE
		var lift: float = v.y/Kit.SCALE-scene.terrain.ramp_height(scene.terrain.ramps[3],p)
		check(lift >= -0.001 and lift <= Kit.MAX_TREAD_LIFT+0.002, "tread follows ramp within two pixels")
	scene.set_physics_process(false)
	scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
	for point in [Vector2(3550,1160),Vector2(3410,1790)]:
		scene.teleport(point)
		for i in 30: await process_frame
		await RenderingServer.frame_post_draw
		settled_costs.append({"point":[point.x,point.y],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"render_objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"render_primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	scene.set_physics_process(true)
	scene.simulation.process_mode = Node.PROCESS_MODE_INHERIT
	scene.teleport(Vector2(3360,1160))
	scene._spawn_enemy_at(Vector2(3470,1170),TrainingEnemy.Role.FRAGMENT,80.0)
	scene._spawn_enemy_at(Vector2(3620,1240),TrainingEnemy.Role.BEAST,100.0)
	await _walk(Vector2(3550,1160))
	await _capture("stairs")
	await _walk(Vector2(3810,1160))
	# Independent representative viewpoint for existing north rock cluster.
	scene.teleport(Vector2(3230,1790))
	await _walk(Vector2(3410,1790))
	await _capture("rocks")
	await _walk(Vector2(3520,1790))
	check(terrain_before == var_to_str([scene.terrain.ramps,scene.terrain.wall_areas,scene.terrain.plateaus,scene.terrain.floor_areas,scene.terrain.water_areas]), "all terrain/collision records unchanged")
	check(scene.player.health > 0 and not scene.run_ended, "moving combat fixture survives")
	var report := {"complete":failures.is_empty(),"failures":failures,"variant":"candidate" if Kit.enabled() else "baseline","engine":Engine.get_version_info().string,"resolution":[root.size.x,root.size.y],"userdata":OS.get_user_data_dir(),"walks":walks,"warnings_seen":warnings_seen,"kills":scene.kills,"decor_meshes":meshes,"decor_surfaces":surfaces,"decor_triangles":triangles,"candidate_tread_triangles":tread_mesh.surface_get_array_len(0)/3,"terrain_vertices":scene.terrain_mesh.mesh.surface_get_array_len(0),"settled_costs":settled_costs,"transforms":transforms,"render_costs":costs,"fixture":"Normal 60Hz movement/attack; two start placements for separate approach viewpoints, natural heights/navigation/collision/AI; seeded two enemies with higher fixture HP; ambient spawn and growth modal suppressed equally. Native GL render in offscreen test window. No full run/human aesthetics or long performance verdict."}
	var f := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"  ")+"\n")
	f.close()
	print("Worn stone ",report.variant," complete=",report.complete," decor triangles=",triangles)
	scene.queue_free()
	current_scene = null
	scene = null
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
