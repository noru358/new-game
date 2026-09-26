extends SceneTree

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena = load("res://game/view_prototype.tscn").instantiate()
	root.add_child(arena)
	await _frames(3)
	var player: SandboxPlayer = arena.player
	var enemies: Node2D = arena.get_node("Enemies")
	var beast: TrainingEnemy = enemies.get_node("FragmentE")
	var lamp: TrainingEnemy = enemies.get_node("FragmentF")
	var zone_caster: TrainingEnemy = enemies.get_node("ZoneG")
	var support: TrainingEnemy = enemies.get_node("SupportH")
	var counts := [0, 0, 0, 0, 0]
	for enemy in enemies.get_children():
		counts[enemy.role] += 1
		enemy.set_physics_process(false)
		enemy.global_position = Vector2(2200, 1250)
	_check(counts == [3, 1, 2, 1, 1] and enemies.get_child_count() == 8, "practice wave mixes five roles")
	_check(beast.max_health == 45.0 and lamp.max_health == 30.0 and zone_caster.max_health == 32.0 and support.max_health == 36.0, "special roles use planned health")
	player.set_physics_process(false)
	arena.wisp.set_physics_process(false)
	player.global_position = Vector2(700, 700)
	player.health = 100.0
	player.hurt_immunity = 0.0

	beast.global_position = Vector2(900, 700)
	_check(beast.BEAST_WARNING < 0.5 and beast.BEAST_CHARGE_SPEED >= 600.0 and beast.BEAST_COOLDOWN < 3.0, "beast charge is quicker and recovers sooner")
	beast.set_physics_process(true)
	await _frames(3)
	_check(beast.warning_time > 0.0 and beast.attacks_started == 1, "beast warns before charging")
	player.global_position = Vector2(700, 825)
	await _frames(85)
	_check(beast.attacks_fired == 1 and player.health == 100.0, "locked straight charge can be dodged")
	beast.global_position = Vector2(900, 700)
	beast.warning_time = 0.0
	beast.charge_time = 0.0
	beast.attack_cooldown = 0.0
	beast.knockback = Vector2.ZERO
	player.global_position = Vector2(700, 700)
	await _frames(85)
	_check(player.health == 85.0, "undodged charge deals 15 damage once")
	beast.set_physics_process(false)
	beast.global_position = Vector2(2200, 1250)

	player.health = 100.0
	player.hurt_immunity = 0.0
	lamp.global_position = Vector2(1020, 700)
	lamp.attack_cooldown = 0.0
	lamp.set_physics_process(true)
	await _frames(3)
	_check(lamp.warning_time > 0.0 and lamp.attacks_started == 1, "lamp warns before straight shot")
	var paused_warning := lamp.warning_time
	paused = true
	await _frames(10)
	_check(is_equal_approx(lamp.warning_time, paused_warning), "level-up style pause freezes enemy warning")
	paused = false
	await _frames(145)
	_check(lamp.attacks_fired == 1 and player.health == 88.0, "lamp shot travels and deals 12 damage")
	lamp.set_physics_process(false)
	for old_bolt in get_nodes_in_group("enemy_bolts"):
		old_bolt.queue_free()
	player.global_position = Vector2(700, 700)
	player.health = 100.0
	player.hurt_immunity = 0.0
	lamp.global_position = Vector2(1020, 700)
	lamp.warning_time = 0.0
	lamp.attack_cooldown = 0.0
	await _frames(2)
	lamp.set_physics_process(true)
	await _frames(3)
	player.global_position = Vector2(700, 825)
	await _frames(145)
	_check(lamp.attacks_fired == 2 and player.health == 100.0, "warned straight shot can be dodged")

	lamp.set_physics_process(false)
	player.global_position = Vector2(1200, 755)
	player.health = 100.0
	player.hurt_immunity = 0.0
	lamp.global_position = Vector2(1340, 755)
	lamp.warning_time = 0.0
	lamp.attack_cooldown = 0.0
	var started_before := lamp.attacks_started
	await _frames(2)
	lamp.set_physics_process(true)
	await _frames(50)
	_check(lamp.attacks_started == started_before, "lamp does not begin aiming through a ruin")
	await _frames(180)
	_check(lamp.attacks_started > started_before, "lamp routes around ruin before aiming")
	lamp.set_physics_process(false)
	for old_bolt in get_nodes_in_group("enemy_bolts"):
		old_bolt.queue_free()
	player.global_position = Vector2(1400, 755)
	await _frames(2)
	player.health = 100.0
	player.hurt_immunity = 0.0
	var bolt: Node2D = load("res://game/enemy_bolt.gd").new()
	bolt.setup(Vector2.RIGHT, 240.0, 12.0)
	arena.add_child(bolt)
	bolt.global_position = Vector2(1180, 755)
	await _frames(80)
	_check(not is_instance_valid(bolt) and player.health == 100.0, "ruin stops a hostile projectile")

	player.global_position = Vector2(700, 700)
	player.health = 100.0
	player.hurt_immunity = 0.0
	zone_caster.global_position = Vector2(960, 700)
	zone_caster.attack_cooldown = 0.0
	zone_caster.set_physics_process(true)
	await _frames(3)
	var zone: EnemyZone = get_first_node_in_group("enemy_zones")
	_check(zone != null and zone.warning_time > 0.0, "zone caster marks a visible target area")
	player.global_position = Vector2(700, 850)
	await _frames(38)
	_check(player.health == 100.0 and zone.warning_time <= 0.0, "moving off the marked area avoids activation")
	player.global_position = Vector2(700, 700)
	await _frames(2)
	_check(player.health == 91.0, "active area deals nine damage when entered")
	zone_caster.set_physics_process(false)
	zone_caster.queue_free()
	await _frames(2)
	_check(get_nodes_in_group("enemy_zones").is_empty(), "defeating caster clears its area")

	var fragment: TrainingEnemy = enemies.get_node("FragmentA")
	fragment.global_position = Vector2(950, 700)
	fragment.attack_cooldown = 1.0
	support.global_position = Vector2(980, 800)
	fragment.set_physics_process(true)
	await _frames(2)
	_check(fragment.support_boost and fragment.velocity.length() > fragment.MOVE_SPEED * 1.2, "support aura speeds nearby allies")
	fragment.attack_cooldown = 1.0
	await _frames(30)
	var boosted_cooldown := fragment.attack_cooldown
	support.global_position = Vector2(2200, 1250)
	fragment.attack_cooldown = 1.0
	await _frames(30)
	_check(not fragment.support_boost and fragment.velocity.length() <= fragment.MOVE_SPEED + 1.0 and fragment.attack_cooldown > boosted_cooldown + 0.1, "leaving aura removes speed and cooldown boosts")
	fragment.set_physics_process(false)

	for enemy in enemies.get_children():
		enemy.queue_free()
	await _frames(2)
	arena.remaining_enemies = 0
	await process_frame
	await process_frame
	_check(arena.wave_hint.visible and not arena.status_label.text.contains("ARENA CLEAR"), "wave prompt stays separate from the left HUD")
	arena._next_practice_wave()
	await process_frame
	await process_frame
	_check(not arena.wave_hint.visible, "wave prompt clears for the next practice wave")
	counts = [0, 0, 0, 0, 0]
	for enemy in enemies.get_children():
		counts[enemy.role] += 1
	_check(counts == [3, 1, 2, 1, 1], "next practice wave keeps all five roles")
	arena.queue_free()
	await _frames(3)
	if failed:
		printerr("1E verification failed")
		quit(1)
	else:
		print("1E verification passed: five roles, quicker charge, ranged warning, zone, support, wall and pause")
		quit(0)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL: ", label)
