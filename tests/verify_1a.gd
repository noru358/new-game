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
	var seen_steps := {}
	_send_key(KEY_J, true)
	for i in 100:
		await physics_frame
		if player.attack_step > 0:
			seen_steps[player.attack_step] = true
	_send_key(KEY_J, false)
	_check(seen_steps.has(3) and seen_steps.has(4), "hold reaches third and fourth hits")
	await _frames(30)
	var left_durable: TrainingEnemy = sandbox.get_node("Enemies/FragmentE")
	var right_durable: TrainingEnemy = sandbox.get_node("Enemies/FragmentF")
	var outside: TrainingEnemy = sandbox.get_node("Enemies/FragmentD")
	left_durable.process_mode = Node.PROCESS_MODE_INHERIT
	right_durable.process_mode = Node.PROCESS_MODE_INHERIT
	player.set_combo_rank(2)
	player.global_position = Vector2(1200, 700)
	player.facing = Vector2.RIGHT
	left_durable.global_position = Vector2(1300, 655)
	right_durable.global_position = Vector2(1300, 745)
	outside.global_position = Vector2(1200, 470)
	player.next_combo_step = 3
	player._start_attack()
	var fixed_gather_target := player.gather_target_global
	_check(player.ATTACKS[2].windup + player.ATTACKS[2].active + player.ATTACKS[2].recovery <= 0.30, "gather is as quick as earlier hits")
	player.global_position += Vector2(-20, 0)
	await _frames(20)
	_check(player.gather_target_global == fixed_gather_target, "gather target stays fixed while moving")
	_check(left_durable.global_position.distance_to(fixed_gather_target) < 23.0, "first enemy stays in small gathered cluster")
	_check(right_durable.global_position.distance_to(fixed_gather_target) < 23.0, "second enemy stays in small gathered cluster")
	_check(left_durable.global_position.distance_to(right_durable.global_position) >= 37.0, "gathered enemies have distinct silhouettes")
	_check(left_durable.health == 75.0 and right_durable.health == 75.0, "gather deals light damage once")
	_check(outside.health == 22.0, "gather excludes enemies outside forward fan")
	player._start_attack()
	_check(player.attack_step == 4, "fourth hit follows gather")
	await _frames(16)
	_check(left_durable.health == 60.0 and right_durable.health == 60.0, "wide fourth hit lands on gathered enemies")
	left_durable.global_position = Vector2(1500, 680)
	right_durable.global_position = Vector2(1500, 720)
	left_durable.knockback = Vector2.ZERO
	right_durable.knockback = Vector2.ZERO
	left_durable.stagger_time = 0.0
	right_durable.stagger_time = 0.0
	await _frames(190)
	_check(left_durable.global_position.distance_to(right_durable.global_position) >= 33.0, "ordinary chasing enemies do not overlap")
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
		print("1A verification passed: movement, dash, 0.70s hit protection, 2/3/4-hit combo, separated gather, separated chase, wide fourth hit, pause, focus loss")
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
