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
	_check(scene.diamond_grid_point(1, 0) - scene.diamond_grid_point(0, 0) == Vector2(80, 40), "first diamond axis slopes down right")
	_check(scene.diamond_grid_point(0, 1) - scene.diamond_grid_point(0, 0) == Vector2(-80, 40), "second diamond axis slopes down left")
	_check(is_equal_approx(camera.zoom.x, 1.25) and is_equal_approx(player.visual_pitch, 0.55), "selected camera and actor projection stay fixed")
	_check(scene.y_sort_enabled and scene.get_node("Enemies").y_sort_enabled, "actors and props sort by foot position")
	_check(scene.view_props.size() == 9, "nine blockout props remain")
	_check(player.collision_mask == 4, "player meets blockout footprint")
	for enemy in scene.get_node("Enemies").get_children():
		_check(enemy.collision_mask == 6 and is_equal_approx(enemy.visual_pitch, 0.55), "enemies use selected projection and meet blockout footprint")
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	_check(is_equal_approx(scene.view_props[0].pitch, 0.55), "ruins keep the selected diamond projection")
	for key in [KEY_G, KEY_1, KEY_2, KEY_3]:
		var former_toggle := InputEventKey.new()
		former_toggle.keycode = key
		former_toggle.pressed = true
		scene.get_viewport().push_input(former_toggle, true)
		await process_frame
		_check(is_equal_approx(camera.zoom.x, 1.25) and is_equal_approx(player.visual_pitch, 0.55), "former comparison key cannot change selected view")
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
	var growth: RunGrowth = scene.get_node("RunGrowth")
	growth.gain_xp(8)
	_check(growth.choosing, "level-up still opens card choice")
	var choose_first := InputEventKey.new()
	choose_first.keycode = KEY_1
	choose_first.pressed = true
	scene.get_viewport().push_input(choose_first, true)
	await process_frame
	_check(not growth.choosing and player.combo_limit() == 3, "1 key still chooses the first card")
	if failed:
		printerr("1B verification failed")
		quit(1)
	else:
		print("1B verification passed: fixed 2:1 diamond, removed comparison keys, Y-sort, footprint collision")
		quit(0)


func _check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL: " + label)
