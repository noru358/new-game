extends SceneTree

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sandbox: Node2D = load("res://game/main.tscn").instantiate()
	root.add_child(sandbox)
	await _frames(2)
	var player: SandboxPlayer = sandbox.get_node("Player")
	for enemy in sandbox.get_node("Enemies").get_children():
		enemy.set_physics_process(false)
	player._start_attack()
	Input.action_press("move_up")
	await _frames(1)
	_check(player.attack_direction.is_equal_approx(Vector2.UP), "current attack follows a changed movement direction")
	Input.action_release("move_up")
	player.queued_attack = true
	player.attack_buffer_time = player.ATTACK_BUFFER_TIME
	await _frames(13)
	_check(not player.queued_attack, "early press expires instead of launching a stale attack")
	await _frames(20)
	_check(player.attack_step == 0, "expired input does not start the next swing")
	player.set_dash_upgrade(2)
	_check(player.dash_max_charges == 2 and player.dash_charges == 2, "second dash rank grants two ready charges")
	player._start_dash(Vector2.RIGHT)
	player._start_dash(Vector2.RIGHT)
	_check(player.dash_charges == 0 and player.dash_cooldown > 0.0, "two dashes consume both charges")
	player.dash_requested = true
	await _frames(1)
	_check(player.dash_charges == 0, "dash cannot start with no charge")
	for i in 150:
		if player.dash_charges == 2:
			break
		await physics_frame
	_check(player.dash_charges == 2, "both dash charges recharge over time")
	player.set_dash_upgrade(3)
	_check(is_equal_approx(player.dash_recharge_duration(), 0.84), "third dash rank shortens recharge to 0.84 seconds")
	sandbox.queue_free()
	await _frames(2)

	var scene: Node2D = load("res://game/view_prototype.tscn").instantiate()
	root.add_child(scene)
	await _frames(3)
	var growth: RunGrowth = scene.get_node("RunGrowth")
	var wisp: WispCompanion = scene.get_node("Wisp")
	var enemies: Node2D = scene.get_node("Enemies")
	for enemy in enemies.get_children():
		enemy.set_physics_process(false)
		enemy.global_position = Vector2(2200, 1250)
	var normal: TrainingEnemy = enemies.get_node("FragmentA")
	normal.global_position = Vector2(1400, 690)
	normal.health = 20.0
	wisp.fire_cooldown = 0.0
	await _frames(160)
	_check(not is_instance_valid(normal) and wisp.shots_fired >= 2, "starting wisp defeats a normal enemy without manual attacks")
	_check(growth.xp == 2 and growth.next_xp() == 8, "automatic kill awards two XP and retains the first threshold")
	var near: TrainingEnemy = enemies.get_node("FragmentE")
	var far: TrainingEnemy = enemies.get_node("FragmentF")
	near.global_position = Vector2(1400, 690)
	far.global_position = Vector2(1490, 705)
	near.health = 10.0
	growth.unlocks.lifetime_levelups = 2
	growth.apply_card("S_WISP_COUNT")
	for companion in growth.wisps:
		companion.set_physics_process(false)
	wisp.global_position = scene.get_node("Player").global_position + wisp.FOLLOW_OFFSET
	wisp._fire(near)
	_check(growth.wisps[1].find_target() == far, "second wisp chooses another enemy when the first shot already covers a kill")
	growth.level = 6
	_check(growth.next_xp() == 18, "later levels grow by two XP per level")
	scene.queue_free()
	await _frames(2)
	if failed:
		printerr("1D play feedback verification failed")
		quit(1)
	else:
		print("1D play feedback verification passed: steering, input buffer, dash charges, automatic kill, target distribution, XP")
		quit(0)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL: ", label)
