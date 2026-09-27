extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var player := SandboxPlayer.new()
	player.position = Vector2(1000, 1000)
	arena.add_child(player)
	player.set_physics_process(false)
	var boss: GateBoss = load("res://game/gate_boss.tscn").instantiate()
	boss.position = Vector2(1200, 1000)
	boss.target = player
	arena.add_child(boss)
	boss.set_physics_process(false)
	_check(boss.max_health == 700.0 and boss.phase == 1, "boss starts with a shorter 700 HP first phase")
	boss._beast_velocity(0.01)
	_check(boss.warning_time > 0.0 and boss.next_attack_shock, "first pattern warns before its locked charge")
	var warned: float = boss.warning_time
	boss.take_hit(10.0, Vector2.RIGHT, true)
	boss.gather_to(Vector2(1500, 1000))
	_check(boss.warning_time == warned and boss.charge_time == 0.0 and boss.global_position == Vector2(1200, 1000), "ordinary hits and third-hit pull do not cancel boss intent")
	boss._beast_velocity(0.60)
	boss._beast_velocity(0.44)
	_check(boss.charge_time == 0.0 and boss.attack_cooldown > 0.0 and boss.attack_cooldown <= 1.55, "charge finishes with the boss recovery instead of ordinary enemy recovery")
	boss.attack_cooldown = 0.0
	boss._beast_velocity(0.01)
	_check(boss.shock_warning > 0.0, "first phase alternates to a circular warning")
	player.position = boss.position + Vector2(300, 0)
	var safe_health: float = player.health
	boss._beast_velocity(0.80)
	_check(player.health == safe_health and boss.ring_warning == 0.0, "leaving the marked circle avoids first-phase damage")
	boss.take_hit(280.0, Vector2.LEFT, false)
	_check(boss.phase == 2 and boss.charge_damage == 25.0 and boss.health > 0.0, "60 percent health opens phase two without invulnerability")
	boss.attack_cooldown = 0.0
	player.position = boss.position + Vector2(320, 0)
	boss._beast_velocity(0.01)
	_check(boss.warning_time > 0.0 and boss.charge_reach() > 330.0, "second phase threatens farther away with a matching charge guide")
	boss.warning_time = 0.0
	boss.charge_time = 0.0
	boss.attack_cooldown = 0.0
	boss.next_attack_shock = true
	player.position = boss.position + Vector2(200, 0)
	boss._beast_velocity(0.01)
	boss._beast_velocity(0.80)
	_check(boss.ring_warning > 0.0 and player.health == safe_health - GateBoss.SHOCK_DAMAGE, "phase-two central pulse starts a delayed outer warning")
	player.hurt_immunity = 0.0
	player.position = boss.position + Vector2(100, 0)
	boss._beast_velocity(0.91)
	_check(player.health == safe_health - GateBoss.SHOCK_DAMAGE, "the inner pocket avoids the outer ring")
	player.hurt_immunity = 0.0
	player.position = boss.position + Vector2(250, 0)
	boss.ring_warning = GateBoss.RING_WARNING
	boss._beast_velocity(0.91)
	_check(player.health == safe_health - GateBoss.SHOCK_DAMAGE - GateBoss.RING_DAMAGE, "standing in the announced outer ring is punished once")
	arena.queue_free()
	await process_frame
	if failures == 0: print("Boss phases verification passed: persistent attacks, dodges, phase change and two-pulse shock")
	quit(1 if failures else 0)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)
