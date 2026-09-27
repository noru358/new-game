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
	var scene = load("res://game/hybrid_region.tscn").instantiate()
	scene.practice_mode = true
	scene.growth_save_prefix = "user://verify_1g_combat_feel_temp"
	root.add_child(scene)
	await _frames(3)
	for companion in scene.growth.wisps: companion.set_physics_process(false)
	for actor in scene.actors:
		if actor is TrainingEnemy: actor.set_physics_process(false)
	scene.teleport(Vector2(3400, 1150))
	var enemy: TrainingEnemy = scene.actors.keys().filter(func(actor): return actor is TrainingEnemy)[0]
	enemy.position = scene.player.position + Vector2(80, 0)
	enemy.health = 100.0
	var player: SandboxPlayer = scene.player
	player.facing = Vector2.RIGHT
	player._start_attack()
	player.attack_elapsed = player._attack_spec(1).windup + 0.005
	var before_camera: Vector3 = scene.camera.position
	player._hit_enemies(player._attack_spec(1))
	_check(player.attack_hitstop_remaining >= 0.024 and scene.camera.position.distance_to(before_camera) > 0.04, "first hit briefly holds the blade and nudges the camera")
	var frozen_elapsed: float = player.attack_elapsed
	var before_move: Vector2 = player.position
	Input.action_press("move_right")
	await _frames(1)
	Input.action_release("move_right")
	_check(player.position.distance_to(before_move) > 3.0 and is_equal_approx(player.attack_elapsed, frozen_elapsed), "movement remains responsive while the blade holds on contact")
	player.dash_requested = true
	await _frames(1)
	_check(player.dash_time > 0.0 and player.attack_step == 0 and player.attack_hitstop_remaining == 0.0, "dash cancels hitstop immediately")
	player.dash_time = 0.0
	player.dash_charges = 1
	player.attack_lock = 0.0
	player.facing = Vector2.RIGHT
	enemy.position = player.position + Vector2(80, 0)
	player.next_combo_step = 2
	player._start_attack()
	player.attack_elapsed = player._attack_spec(2).windup + 0.005
	player._hit_enemies(player._attack_spec(2))
	_check(player.attack_hitstop_remaining >= 0.039 and player.attack_hitstop_remaining > 0.025, "second hit has the stronger contact accent")
	player._start_attack()
	enemy.position = Vector2(4900, 1700)
	player._hit_enemies(player._attack_spec(player.attack_step))
	_check(player.attack_hitstop_remaining == 0.0, "an empty swing does not acquire extra recovery")
	scene.queue_free()
	await _frames(2)
	for suffix in ["_a.json", "_b.json"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://verify_1g_combat_feel_temp" + suffix))
	if failures == 0: print("1G combat feel verification passed: contact hold, live movement, dash cancel, stronger second hit, empty swing")
	quit(1 if failures else 0)
