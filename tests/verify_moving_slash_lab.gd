extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _frames(count: int) -> void:
	for i in count: await physics_frame


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _run() -> void:
	var scene = load("res://game/moving_slash_lab.tscn").instantiate()
	scene.growth_save_prefix = "user://verify_moving_slash_lab_temp"
	root.add_child(scene)
	await _frames(3)
	var player: SandboxPlayer = scene.player
	_check(scene.practice_mode and player.moving_slash_enabled and InputMap.has_action("moving_slash"), "Q prototype is available in the lab")
	for companion in scene.growth.wisps: companion.set_physics_process(false)
	var enemies: Array = scene.actors.keys().filter(func(actor): return actor is TrainingEnemy)
	for actor in enemies:
		actor.set_physics_process(false)
		actor.position = Vector2(4800, 1700)
	var enemy: TrainingEnemy = enemies[0]
	enemy.max_health = 100.0
	enemy.health = 100.0
	scene.teleport(Vector2(3400, 1150))
	enemy.position = player.position + Vector2(95, 0)
	player.facing = Vector2.RIGHT
	var start := player.position
	var q := InputEventKey.new()
	q.physical_keycode = KEY_SPACE
	q.pressed = true
	Input.parse_input_event(q)
	var started := false
	for i in 12:
		await physics_frame
		if player.moving_slash_time > 0.0:
			started = true
			break
	q.pressed = false
	Input.parse_input_event(q)
	_check(started, "Q input starts the prototype")
	for i in 30:
		await physics_frame
		if started and player.moving_slash_time <= 0.0: break
	await _frames(1)
	_check(player.position.distance_to(start) > 170.0 and player.position.distance_to(start) < 180.0, "Q starts slash and travels its full placeholder distance on clear ground")
	_check(is_equal_approx(enemy.health, 100.0 - SandboxPlayer.MOVING_SLASH_DAMAGE), "swept slash hits each enemy once")
	_check(player.moving_slash_cooldown > 0.0 and player.moving_slash_time == 0.0, "slash finishes with cooldown (time %.3f, cooldown %.3f)" % [player.moving_slash_time, player.moving_slash_cooldown])

	# This square wall is part of the gallery's shared visible and collision data.
	scene.teleport(Vector2(3000, 1050))
	player.moving_slash_cooldown = 0.0
	player.facing = Vector2.RIGHT
	enemy.position = Vector2(3300, 1050)
	enemy.health = 100.0
	_check(not scene.clear_attack(player.position, enemy.position), "wall test is actually blocked")
	player.moving_slash_requested = true
	await _frames(16)
	_check(player.position.x < 3100.0 and player.position.x > 3000.0, "slash stops against wall without entering it")
	_check(is_equal_approx(enemy.health, 100.0), "slash does not damage behind wall")

	# Deep water uses the same layer-4 blocker as the wall.
	scene.teleport(Vector2(2500, 480))
	player.moving_slash_cooldown = 0.0
	player.facing = Vector2.UP
	enemy.position = Vector2(2500, 350)
	enemy.health = 100.0
	_check(not scene.clear_attack(player.position, enemy.position), "water test is actually blocked")
	player.moving_slash_requested = true
	await _frames(16)
	_check(player.position.y > 450.0, "slash stops before deep water")
	_check(is_equal_approx(enemy.health, 100.0), "slash does not damage across deep water")

	scene.teleport(Vector2(3400, 1150))
	player.moving_slash_cooldown = 0.0
	player.facing = Vector2.RIGHT
	player.moving_slash_requested = true
	await _frames(1)
	player.dash_charges = 1
	player.dash_requested = true
	await _frames(1)
	_check(player.dash_time > 0.0 and player.moving_slash_time == 0.0 and player.moving_slash_visual_time == 0.0, "dash cancels slash and its visual")
	player.dash_time = 0.0
	player.moving_slash_cooldown = 0.0
	player.moving_slash_requested = true
	await _frames(1)
	scene._set_paused(true)
	var paused_position := player.position
	var paused_time := player.moving_slash_time
	await _frames(4)
	_check(player.position.is_equal_approx(paused_position) and is_equal_approx(player.moving_slash_time, paused_time), "pause freezes slash travel")
	scene._set_paused(false)
	player.moving_slash_time = 0.0
	player.dash_time = 0.0
	player.moving_slash_cooldown = 0.0
	player.attack_lock = 0.0
	player.set_combo_rank(2)
	player._start_attack()
	player.attack_elapsed = player._attack_spec(1).windup + player._attack_spec(1).active + 0.005
	player.moving_slash_requested = true
	await _frames(1)
	_check(player.moving_slash_time > 0.0 and player.attack_step == 0 and player.next_combo_step == 2, "Q links after a hit and preserves the next combo step")
	player.hurt_immunity = 0.0
	var safe_health := player.health
	player.receive_hit(10.0, player.position + Vector2.LEFT)
	_check(player.health == safe_health, "the first part of Q has brief invulnerability")
	player.moving_slash_elapsed = SandboxPlayer.MOVING_SLASH_INVULNERABILITY + 0.01
	player.receive_hit(10.0, player.position + Vector2.LEFT)
	_check(player.health == safe_health - 10.0, "Q is vulnerable after its brief opening window")
	scene.queue_free()
	await _frames(2)
	var ordinary_player := load("res://game/player.tscn").instantiate() as SandboxPlayer
	_check(not ordinary_player.moving_slash_enabled, "normal player has no moving slash by default")
	ordinary_player.free()
	for suffix in ["_a.json", "_b.json"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://verify_moving_slash_lab_temp" + suffix))
	if failures == 0: print("Moving slash lab passed: distance, one hit, wall, water, dash, pause, main-run gating")
	quit(1 if failures else 0)
