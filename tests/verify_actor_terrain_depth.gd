extends SceneTree
## Measures visible body pixels with the real opaque terrain on/off at fixed poses.
## This fixture runs only in an isolated project userdata directory.

var output := ""
var failures: Array[String] = []
var cases: Array[Dictionary] = []

func _initialize() -> void: call_deferred("_run")

func _image() -> Image:
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func _difference(first: Image, second: Image) -> int:
	var count := 0
	for y in first.get_height():
		for x in first.get_width():
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.04: count += 1
	return count

func _measure(entry: Dictionary) -> void:
	var scene: Node3D = load(entry.scene).instantiate()
	if entry.name != "canal-bridge":
		scene.profile_save_prefix = "user://depth_" + entry.name + "_profile"
		scene.growth_save_prefix = "user://depth_" + entry.name + "_unlocks"
	root.add_child(scene)
	current_scene = scene
	await process_frame
	if entry.name == "jungle-stair-high":
		var moved := Vector2(4250, 1390)
		var old := Vector2(4060, 1390)
		if not scene.canopy_visuals.has(moved) or scene.canopy_visuals.has(old): failures.append("opaque gate canopy was not relocated")
		if scene.navigation.is_open(moved, scene.ACTOR_CLEARANCE) or not scene.navigation.is_open(old, scene.ACTOR_CLEARANCE): failures.append("gate canopy visual and 2D blocker disagree")
	scene.set_physics_process(false)
	scene.set_process(false)
	scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
	for actor in scene.actors: scene.actors[actor].visible = false
	var enemy: TrainingEnemy = scene._spawn_enemy_at(entry.point, TrainingEnemy.Role.BEAST, 45.0)
	enemy.set_physics_process(false)
	var visual: Node3D = scene.actors[enemy]
	visual.get_node("Shadow").hide()
	visual.get_node("HealthBar").hide()
	scene._process(0)
	scene.camera.position = scene.terrain.world_point(entry.point, 35.0) + scene.camera_offset
	scene.camera.look_at(scene.terrain.world_point(entry.point, 35.0), Vector3.UP)
	var body: Sprite3D = visual.get_node("Body")
	var images: Dictionary = {}
	for terrain_visible in [true, false]:
		scene.terrain_mesh.visible = terrain_visible
		for body_visible in [false, true]:
			body.visible = body_visible
			var key := ("terrain" if terrain_visible else "bare") + ("-body" if body_visible else "-empty")
			images[key] = await _image()
			if body_visible: (images[key] as Image).save_png(output.path_join(entry.name + "-" + key + ".png"))
	var opaque_count: int = _difference(images["terrain-body"], images["terrain-empty"])
	var bare_count: int = _difference(images["bare-body"], images["bare-empty"])
	var ratio := float(opaque_count) / maxf(float(bare_count), 1.0)
	var result := {"name": entry.name, "point": [entry.point.x, entry.point.y], "height": scene.terrain.height_at(entry.point), "visible_body_pixels_with_terrain": opaque_count, "visible_body_pixels_bare": bare_count, "visible_ratio": ratio, "body_position": [body.position.x, body.position.y, body.position.z], "sprite_offset_y": body.offset.y}
	cases.append(result)
	print("DEPTH ", JSON.stringify(result))
	if bare_count < 700: failures.append("opaque scenery buries most of actor: " + entry.name)
	if ratio < 0.98: failures.append("terrain clips actor feet: " + entry.name)
	scene.queue_free()
	await process_frame
	await process_frame
	current_scene = null

func _run() -> void:
	output = OS.get_environment("ACTOR_DEPTH_OUTPUT")
	if output.is_empty() or not OS.get_user_data_dir().contains("CodexActorTerrainV43"):
		printerr("FAIL: private project and output required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720) if OS.get_cmdline_user_args().has("--large") else Vector2i(960, 540)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for entry in [
		{"name": "jungle-stair-low", "scene": "res://game/jungle_pass.tscn", "point": Vector2(3230, 1180)},
		{"name": "jungle-stair-mid", "scene": "res://game/jungle_pass.tscn", "point": Vector2(3500, 1180)},
		{"name": "jungle-stair-high", "scene": "res://game/jungle_pass.tscn", "point": Vector2(3780, 1180)},
		{"name": "jungle-stair-crest", "scene": "res://game/jungle_pass.tscn", "point": Vector2(3850, 1320)},
		{"name": "jungle-rock-path", "scene": "res://game/jungle_pass.tscn", "point": Vector2(3880, 1880)},
		{"name": "jungle-plateau", "scene": "res://game/jungle_pass.tscn", "point": Vector2(4450, 1100)},
		{"name": "temple-terrace-ramp", "scene": "res://game/hybrid_region.tscn", "point": Vector2(700, 1120)},
		{"name": "temple-south-stones", "scene": "res://game/hybrid_region.tscn", "point": Vector2(940, 1645)},
		{"name": "canal-bridge", "scene": "res://game/canal_city_trial.tscn", "point": Vector2(3800, 2180)},
	]: await _measure(entry)
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine": Engine.get_version_info().string, "cases": cases, "failures": failures, "user_data_dir": OS.get_user_data_dir()}, "  ") + "\n")
	file.close()
	print("Actor terrain depth: ", cases.size(), " cases; failures=", failures)
	quit(0 if failures.is_empty() else 1)
