extends SceneTree
## Isolated posed renderer fixture. Never uses the normal game save directory.

var failures: Array[String] = []
var output := ""

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		printerr("FAIL: ", message)

func _capture(scene: Node3D, label: String, center: Vector2, points: Array) -> void:
	scene.set_physics_process(false)
	scene.set_process(false)
	scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
	scene.teleport(center)
	var roles := [TrainingEnemy.Role.FRAGMENT, TrainingEnemy.Role.BEAST, TrainingEnemy.Role.LAMP, TrainingEnemy.Role.ZONE, TrainingEnemy.Role.SUPPORT]
	var actors: Array[TrainingEnemy] = []
	for i in points.size():
		var enemy: TrainingEnemy = scene._spawn_enemy_at(points[i], roles[i % roles.size()], TrainingEnemy.Definitions.ROLES[roles[i % roles.size()]].health)
		enemy.set_physics_process(false)
		actors.append(enemy)
	scene._process(0.0)
	scene.camera.position = scene.terrain.world_point(center, 35.0) + scene.camera_offset
	scene.camera.look_at(scene.terrain.world_point(center, 35.0), Vector3.UP)
	var report: Array[Dictionary] = []
	for enemy in actors:
		var body: Sprite3D = scene.actors[enemy].get_node("Body")
		var root_visual: Node3D = scene.actors[enemy]
		var ground: Vector3 = scene.terrain.world_point(enemy.position)
		var actual: Vector3 = root_visual.global_position
		var projected: Vector2 = scene.camera.unproject_position(ground)
		var body_center: Vector2 = scene.camera.unproject_position(body.global_position)
		var used := body.texture.get_image().get_used_rect()
		report.append({"role": enemy.role, "point": [enemy.position.x, enemy.position.y], "height": scene.terrain.height_at(enemy.position), "ground_y": ground.y, "visual_y": actual.y, "body_center": [body_center.x, body_center.y], "projected_ground": [projected.x, projected.y], "sprite_pixel_offset_y": body.offset.y, "sprite_used_rect": [used.position.x, used.position.y, used.size.x, used.size.y]})
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(image != null and not image.is_empty(), "native frame " + label)
	if image != null and not image.is_empty(): _check(image.save_png(output.path_join(label + ".png")) == OK, "PNG " + label)
	var file := FileAccess.open(output.path_join(label + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	scene.queue_free()
	await process_frame
	await process_frame

func _run() -> void:
	output = OS.get_environment("ACTOR_GROUNDING_OUTPUT")
	if output.is_empty() or not OS.get_user_data_dir().contains("CodexActorTerrainV43"):
		printerr("FAIL: private project and output required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for entry in [
		{"name": "jungle-stairs", "scene": "res://game/jungle_pass.tscn", "center": Vector2(3500, 1180), "points": [Vector2(3380, 1120), Vector2(3470, 1180), Vector2(3550, 1250), Vector2(3630, 1130), Vector2(3730, 1210)]},
		{"name": "jungle-rocks", "scene": "res://game/jungle_pass.tscn", "center": Vector2(3920, 1880), "points": [Vector2(3760, 1870), Vector2(3830, 1950), Vector2(3950, 1840), Vector2(4030, 1940), Vector2(4130, 1830)]},
		{"name": "temple-ramp", "scene": "res://game/hybrid_region.tscn", "center": Vector2(1000, 990), "points": [Vector2(890, 970), Vector2(940, 1030), Vector2(1000, 950), Vector2(1060, 1040), Vector2(1110, 980)]},
		{"name": "canal-bridge", "scene": "res://game/canal_city_trial.tscn", "center": Vector2(3800, 2180), "points": [Vector2(3660, 2100), Vector2(3740, 2220), Vector2(3820, 2120), Vector2(3920, 2240), Vector2(4000, 2120)]},
	]:
		var scene: Node3D = load(entry.scene).instantiate()
		if entry.name != "canal-bridge":
			scene.profile_save_prefix = "user://grounding_" + entry.name + "_profile"
			scene.growth_save_prefix = "user://grounding_" + entry.name + "_unlocks"
		root.add_child(scene)
		current_scene = scene
		await process_frame
		await _capture(scene, entry.name, entry.center, entry.points)
		current_scene = null
	print("Actor grounding capture: ", 4 - failures.size(), "/4 scenes; failures=", failures)
	quit(0 if failures.is_empty() else 1)
