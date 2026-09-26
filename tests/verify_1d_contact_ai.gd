extends SceneTree

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena = load("res://game/view_prototype.tscn").instantiate()
	root.add_child(arena)
	await _frames(3)
	var player: SandboxPlayer = arena.player
	var wisp: WispCompanion = arena.wisp
	var enemies: Node2D = arena.get_node("Enemies")
	player.hurt_immunity = 100.0
	wisp.set_physics_process(false)
	for enemy in enemies.get_children():
		enemy.set_physics_process(false)
		enemy.global_position = Vector2(2200, 1250)

	var ruin := Vector2(1270, 755)
	var chaser: TrainingEnemy = enemies.get_node("FragmentA")
	chaser.global_position = ruin + Vector2(-56, 0)
	player.global_position = ruin + Vector2(170, 0)
	_check(chaser._chase_direction(0.016) != Vector2.ZERO, "enemy at ruin contact edge finds an escape direction")
	chaser.set_physics_process(true)
	await _frames(240)
	_check(chaser.global_position.distance_to(player.global_position) < 72.0, "enemy walks around ruin after touching it")
	chaser.set_physics_process(false)
	chaser.global_position = Vector2(2200, 1250)

	player.global_position = ruin + Vector2(57, 0)
	wisp.global_position = player.global_position + wisp.follow_offset
	var victim: TrainingEnemy = enemies.get_node("FragmentB")
	victim.global_position = ruin + Vector2(170, 0)
	wisp.fire_cooldown = 0.0
	var before := wisp.shots_fired
	wisp.set_physics_process(true)
	await _frames(3)
	_check(wisp.global_position.distance_to(ruin) >= 50.0, "wisp remains outside ruin footprint")
	_check(wisp.shots_fired > before, "wisp sees and attacks enemy after clearing ruin")

	arena.queue_free()
	await _frames(3)
	if failed:
		printerr("1D contact AI verification failed")
		quit(1)
	else:
		print("1D contact AI verification passed: ruin edge pursuit and wisp firing")
		quit(0)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL: ", label)
