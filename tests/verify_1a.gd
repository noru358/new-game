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
	for training_enemy in sandbox.get_node("Enemies").get_children():
		training_enemy.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(36)
	player.receive_hit(10.0)
	_check(player.health == 90.0, "0.70 second hurt protection stays active")
	await _frames(18)
	player.receive_hit(10.0)
	_check(player.health == 80.0, "hurt protection expires")

	player.global_position = Vector2(1200, 700)
	player.facing = Vector2.RIGHT
	player.health = 100.0
	player.dash_cooldown = 0.0
	player.hurt_immunity = 100.0
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
	_check(player.combo_limit() == 2, "base combo has two hits")
	_send_key(KEY_K, true)
	_send_key(KEY_K, false)
	await _frames(1)
	_check(player.combo_limit() == 3, "training toggle previews third hit")
	_send_key(KEY_K, true)
	_send_key(KEY_K, false)
	await _frames(1)
	_check(player.combo_limit() == 4, "training toggle previews fourth hit")
	var durable: TrainingEnemy = sandbox.get_node("Enemies/FragmentE")
	durable.global_position = player.global_position + Vector2(142, 0)
	player.facing = Vector2.RIGHT
	_send_key(KEY_J, true)
	await _frames(120)
	_send_key(KEY_J, false)
	_check(durable.health <= 60.0, "fourth-hit overhead slam reaches fixed forward target")
	await _frames(30)
	player.set_combo_rank(2)
	player.global_position = Vector2(1200, 700)
	player.facing = Vector2.RIGHT
	player.next_combo_step = 4
	durable.health = 80.0
	durable.global_position = Vector2(1278, 700)
	player._start_attack()
	var fixed_slam_target := player.slam_target_global
	player.global_position = Vector2(1000, 700)
	await _frames(25)
	_check(player.slam_target_global == fixed_slam_target, "slam target stays fixed while moving")
	_check(durable.health == 60.0, "fourth hit still lands after player moves")
	_send_key(KEY_K, true)
	_send_key(KEY_K, false)
	await _frames(1)
	_check(player.combo_limit() == 2, "training toggle cycles back to base combo")

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
		print("1A verification passed: movement, dash, 0.70s hit protection, 2/3/4-hit combo, hold, slam, pause, focus loss")
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
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
