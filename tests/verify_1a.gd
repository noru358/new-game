extends SceneTree

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://game/main.tscn")
	var sandbox := scene.instantiate()
	root.add_child(sandbox)
	await _frames(2)
	var player: SandboxPlayer = sandbox.get_node("Player")
	var enemy: TrainingEnemy = sandbox.get_node("Enemies/FragmentA")

	var start: Vector2 = player.global_position
	Input.action_press("move_right")
	await _frames(30)
	Input.action_release("move_right")
	_check(absf(player.global_position.x - start.x - 150.0) < 8.0, "move speed")
	_check(absf(player.global_position.y - start.y) < 1.0, "move direction")

	start = player.global_position
	_send_key(KEY_SPACE, true)
	await _frames(1)
	_send_key(KEY_SPACE, false)
	await _frames(9)
	_check(player.global_position.distance_to(start) > 115.0, "dash distance")
	_check(player.global_position.distance_to(start) < 145.0, "dash upper bound")
	_check(player.dash_cooldown > 0.0, "dash cooldown")

	player.health = 100.0
	player.hurt_immunity = 0.0
	player.dash_time = 0.05
	player.dash_elapsed = 0.05
	player.receive_hit(10.0)
	_check(player.health == 100.0, "dash invulnerability")
	player.dash_time = 0.0
	player.receive_hit(10.0)
	player.receive_hit(10.0)
	_check(player.health == 90.0, "hurt invulnerability")
	_check(player.hurt_recoil.length() > 0.0, "hurt recoil")
	_check(sandbox.hurt_feedback_time > 0.0, "visible hurt feedback")
	_check(Engine.time_scale < 1.0, "brief hitstop on hurt")

	player.global_position = Vector2(1200, 700)
	player.facing = Vector2.RIGHT
	player.dash_cooldown = 0.0
	player.hurt_immunity = 100.0
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.global_position = player.global_position + Vector2(70, 0)
	_send_key(KEY_J, true)
	await _frames(2)
	_send_key(KEY_J, false)
	await _frames(20)
	_check(enemy.health == 12.0, "one press hits once")
	_check(player.next_combo_step == 2, "combo advances")
	_send_key(KEY_J, true)
	await _frames(50)
	_send_key(KEY_J, false)
	_check(not is_instance_valid(enemy) or enemy.is_queued_for_deletion(), "hold repeats combo")

	start = player.global_position
	sandbox._pause("TEST", "paused")
	Input.action_press("move_right")
	await _frames(20)
	_check(player.global_position == start, "pause stops movement")
	sandbox._resume()
	Input.action_release("move_right")
	_check(not paused, "manual resume")
	sandbox.get_window().focus_exited.emit()
	_check(paused, "focus loss pauses")
	sandbox._resume()
	player.attack_audio.stop()
	player.impact_audio.stop()
	sandbox.queue_free()
	for i in 10:
		await process_frame

	if failed:
		printerr("1A verification failed")
		quit(1)
	else:
		print("1A verification passed: movement, dash, hit protection, combo, hold, pause, focus loss")
		quit(0)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		printerr("FAIL: ", label)


func _send_key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
