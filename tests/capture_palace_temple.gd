extends SceneTree
## Bounded real-input walk. Captures are development evidence, not human play.
const Terrain = preload("res://game/palace_temple_terrain.gd")
var report := {"route":[],"captures":[],"failures":[],"engine":Engine.get_version_info().string}
var output := OS.get_environment("PALACE_CAPTURE_DIR")
var scene
var capture := false

func _initialize() -> void: call_deferred("_run")

func _inputs(direction: Vector2) -> void:
	for action in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)
	if direction.x < -0.02: Input.action_press("move_left",-direction.x)
	if direction.x > 0.02: Input.action_press("move_right",direction.x)
	if direction.y < -0.02: Input.action_press("move_up",-direction.y)
	if direction.y > 0.02: Input.action_press("move_down",direction.y)

func _save_frame(title: String) -> void:
	if not capture: return
	for i in 8: await process_frame
	RenderingServer.force_draw(false)
	var pixels := root.get_texture().get_image()
	if pixels == null or pixels.is_empty() or pixels.get_size() != Vector2i(960,540):
		report.failures.append("Missing or wrong-size native frame: "+title)
		return
	var path := output.path_join(title+".png")
	var result := pixels.save_png(path)
	if result != OK or FileAccess.get_file_as_bytes(path).size() < 3000: report.failures.append("Invalid PNG: "+title)
	report.captures.append({"file":title+".png","point":[scene.player.position.x,scene.player.position.y],"camera_size":scene.camera.size,"bytes":FileAccess.get_file_as_bytes(path).size()})

func _run() -> void:
	if output.is_empty(): output = "user://palace-capture"
	DirAccess.make_dir_recursive_absolute(output)
	capture = not OS.get_cmdline_user_args().has("--palace-headless-check")
	root.size = Vector2i(960,540)
	root.content_scale_size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	scene = load("res://game/palace_temple_preview.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 5: await physics_frame
	# Test script owns this window; focus never changes user's apps.
	scene._set_paused(false)
	scene.get_window().focus_exited.disconnect(scene.get_window().focus_exited.get_connections()[0].callable)
	var elapsed := 0.0
	for index in range(1,Terrain.WAYPOINTS.size()):
		var target: Vector2 = Terrain.WAYPOINTS[index]
		var frames := 0
		var begin: Vector2 = scene.player.position
		while scene.player.position.distance_to(target) > 14.0 and frames < 720:
			_inputs((target-scene.player.position).normalized().rotated(-scene.player.input_rotation))
			await physics_frame
			frames += 1
		_inputs(Vector2.ZERO)
		elapsed += float(frames)/Engine.physics_ticks_per_second
		var reached: Vector2 = scene.player.position
		if reached.distance_to(target)>14: report.failures.append("Walk did not reach "+str(index))
		report.route.append({"index":index,"from":[begin.x,begin.y],"target":[target.x,target.y],"actual":[reached.x,reached.y],"active_seconds":float(frames)/Engine.physics_ticks_per_second})
		if index == 2: await _save_frame("01-gate-960")
		if index == 3: await _save_frame("02-court-960")
		if index == 5: await _save_frame("03-cloister-960")
	report["walk_active_seconds"] = elapsed
	report["camera_offset"] = [scene.camera_offset.x,scene.camera_offset.y,scene.camera_offset.z]
	report["landmark_vertices"] = scene.palace_root.get_meta("vertices")
	report["profile_nodes"] = get_nodes_in_group("run_profile").size()
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if report.failures.is_empty() else 1)
