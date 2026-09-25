extends SceneTree

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node2D = load("res://game/view_prototype.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	var player: SandboxPlayer = scene.get_node("Player")
	var camera: Camera2D = player.get_node("Camera2D")
	_check(scene.view_mode == 2, "medium oblique starts by default")
	_check(is_equal_approx(camera.zoom.x, 1.25), "default camera scale")
	_check(scene.y_sort_enabled and scene.get_node("Enemies").y_sort_enabled, "actors and props sort by foot position")
	_check(scene.view_props.size() == 9, "same nine blockout props in all candidates")
	_check(player.collision_mask == 4, "player meets blockout footprint")
	for enemy in scene.get_node("Enemies").get_children():
		_check(enemy.collision_mask == 6, "enemies separate and meet blockout footprint")
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	for mode in [1, 3, 2]:
		scene.set_view_mode(mode)
		_check(scene.view_mode == mode, "mode switch %d" % mode)
		_check(is_equal_approx(camera.zoom.x, scene.MODE_ZOOMS[mode - 1]), "camera scale %d" % mode)
		_check(is_equal_approx(player.visual_pitch, scene.MODE_PITCHES[mode - 1]), "actor projection %d" % mode)
		_check(scene.view_props.size() == 9, "layout unchanged %d" % mode)
	var obstacle: Node2D = scene.view_props[3]
	player.global_position = obstacle.global_position + Vector2(-100, 0)
	player.hurt_immunity = 100.0
	Input.action_press("move_right")
	for i in 36:
		await physics_frame
	Input.action_release("move_right")
	_check(player.global_position.x < obstacle.global_position.x - 48.0, "blockout pillar blocks movement")
	player.global_position = obstacle.global_position + Vector2(0, -70)
	for i in 20:
		await process_frame
	_check(obstacle.modulate.a < 0.65, "near foreground fades to reveal player")
	if failed:
		printerr("1B verification failed")
		quit(1)
	else:
		print("1B verification passed: medium default, three switchable views, fixed layout, Y-sort, footprint collision")
		quit(0)


func _check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL: " + label)
