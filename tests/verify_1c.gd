extends SceneTree

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node2D = load("res://game/view_prototype.tscn").instantiate()
	root.add_child(scene)
	await _frames(3)
	var player: SandboxPlayer = scene.get_node("Player")
	var wisp: WispCompanion = scene.get_node("Wisp")
	var enemies: Node2D = scene.get_node("Enemies")
	_check(is_equal_approx(scene.camera.zoom.x, 1.25) and scene.diamond_grid_point(1, 0) - scene.diamond_grid_point(0, 0) == Vector2(80, 40), "selected 1B view retained")
	_check(wisp.process_mode == Node.PROCESS_MODE_PAUSABLE, "wisp pauses with battle")
	_check(is_equal_approx(wisp.attack_interval, 1.25), "current base fire interval")
	_check(is_equal_approx(wisp.attack_range, 520.0), "base target range")
	_check(is_equal_approx(wisp.projectile_speed, 620.0), "base projectile speed")
	_check(is_equal_approx(wisp.damage_multiplier, 1.0), "current base damage coefficient")
	player.health = 100.0
	player.hurt_immunity = 100.0
	for enemy in enemies.get_children():
		enemy.set_physics_process(false)
		enemy.global_position = Vector2(2200, 1250)
	var near_enemy: TrainingEnemy = enemies.get_node("FragmentE")
	var far_enemy: TrainingEnemy = enemies.get_node("FragmentF")
	near_enemy.global_position = Vector2(1400, 690)
	far_enemy.global_position = Vector2(1490, 705)
	wisp.global_position = player.global_position + wisp.FOLLOW_OFFSET
	await _frames(2)
	_check(wisp.find_target() == near_enemy, "nearest visible unblocked enemy selected")
	wisp.fire_cooldown = 0.0
	var before_health := near_enemy.health
	await _frames(1)
	_check(wisp.shots_fired == 1, "automatic shot fires without manual input")
	_check(wisp.muzzle_flash > 0.0, "shot creates a visible muzzle cue")
	_check(player.attack_step == 0, "automatic shot does not use manual combo")
	await _frames(27)
	_check(is_equal_approx(near_enemy.health, before_health - player.ATTACK_DAMAGE), "projectile deals current base wisp damage once")
	_check(get_nodes_in_group("wisp_flashes").size() > 0, "wisp impact creates a distinct flash")
	_check(far_enemy.health == far_enemy.max_health, "nearest target takes the shot")
	for enemy in enemies.get_children():
		enemy.global_position = Vector2(2200, 1250)
	near_enemy.global_position = Vector2(1350, 800)
	_check(wisp._blocked_by_wall(near_enemy.global_position), "ruin blocks line of sight")
	_check(wisp.find_target() == null, "wall-occluded enemy is not acquired")
	wisp.fire_cooldown = 0.0
	var shots_before := wisp.shots_fired
	await _frames(10)
	_check(wisp.shots_fired == shots_before and wisp.fire_cooldown <= 0.0, "no target keeps shot ready")
	near_enemy.global_position = Vector2(660, 700)
	var visible_rect := root.get_visible_rect()
	_check(wisp.global_position.distance_to(near_enemy.global_position) < wisp.attack_range, "offscreen target is still in range")
	_check(not visible_rect.has_point(near_enemy.get_global_transform_with_canvas().origin), "test target is offscreen")
	_check(wisp.find_target() == null, "offscreen enemy is not acquired")
	wisp.fire_cooldown = 0.7
	paused = true
	await _frames(12)
	_check(is_equal_approx(wisp.fire_cooldown, 0.7), "pause freezes auto attack cooldown")
	paused = false
	wisp.process_mode = Node.PROCESS_MODE_DISABLED
	near_enemy.global_position = Vector2(1350, 800)
	var projectile: WispProjectile = load("res://game/wisp_projectile.gd").new()
	projectile.setup(wisp.global_position.direction_to(near_enemy.global_position), 620.0, 520.0, 10.0)
	scene.add_child(projectile)
	projectile.global_position = wisp.global_position
	before_health = near_enemy.health
	await _frames(32)
	_check(not is_instance_valid(projectile), "projectile stops at ruin")
	_check(near_enemy.health == before_health, "projectile does not pass through ruin")
	scene.queue_free()
	await _frames(3)
	if failed:
		printerr("1C verification failed")
		quit(1)
	else:
		print("1C verification passed: selected view, automatic nearest shot, damage, wall and screen filtering, pause")
		quit(0)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL: ", label)
