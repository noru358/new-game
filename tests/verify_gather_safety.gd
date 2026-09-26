extends SceneTree

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node2D = load("res://game/main.tscn").instantiate()
	root.add_child(scene)
	await _frames(2)
	var player: SandboxPlayer = scene.get_node("Player")
	var enemy: TrainingEnemy = scene.get_node("Enemies/FragmentE")
	for other in scene.get_node("Enemies").get_children():
		if other != enemy:
			other.set_physics_process(false)
			other.global_position = Vector2(2200, 1250)
	player.global_position = Vector2(1200, 700)
	player.facing = Vector2.RIGHT
	player.health = 100.0
	player.hurt_immunity = 0.0
	player.set_combo_rank(2)
	player.next_combo_step = 3
	enemy.global_position = Vector2(1300, 700)
	Input.action_press("move_right")
	Input.action_press("attack")
	player._start_attack()
	await _frames(15)
	_check(player.health == 100.0 and enemy.health == 75.0, "moving third hit gathers without immediate contact damage")
	_check(enemy.global_position.distance_to(player.global_position) > enemy.RADIUS + 18.0, "gather destination stays beyond contact distance")
	var fourth_landed := false
	for i in 30:
		await physics_frame
		if enemy.health <= 60.0:
			fourth_landed = true
			break
	_check(fourth_landed and player.health == 100.0, "fourth hit lands before gathered enemy can deal contact damage")
	Input.action_release("attack")
	var contact_resumed := false
	for i in 30:
		await physics_frame
		if player.health < 100.0:
			contact_resumed = true
			break
	_check(contact_resumed, "ordinary contact damage resumes if player keeps moving into surviving enemy")
	Input.action_release("move_right")
	scene.queue_free()
	await _frames(2)
	if failed:
		printerr("gather safety verification failed")
		quit(1)
	else:
		print("gather safety verification passed: moving pull, fourth-hit window, ordinary later contact")
		quit(0)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL: ", label)
