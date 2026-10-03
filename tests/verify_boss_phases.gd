extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)
func _run() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var player := SandboxPlayer.new()
	arena.add_child(player)
	player.set_physics_process(false)
	var boss: GateBoss = load("res://game/gate_boss.tscn").instantiate()
	boss.position = Vector2(1000, 700)
	boss.target = player
	arena.add_child(boss)
	boss.set_physics_process(false)
	player.position = boss.position + Vector2(560, 0)
	boss._beast_velocity(0.01)
	check(boss.max_health == 1800 and boss.warning_time > 0 and boss.charge_reach() >= 560, "trial health, charge threatens beyond old chase-only range")
	var direction := boss.locked_direction
	var warning := boss.warning_time
	player.position += Vector2(0, 150)
	boss.take_hit(10, Vector2.LEFT, true)
	boss.gather_to(Vector2.ZERO)
	check(boss.locked_direction == direction and boss.warning_time == warning, "telegraph locks direction and hits cannot cancel intent")
	boss._beast_velocity(0.61)
	boss._beast_velocity(0.7)
	boss._beast_velocity(0.01)
	check(boss.recovery_time >= boss._attack_delay(), "single opening attack ends in a full combo counter window")
	check(boss._beast_velocity(0.2) == Vector2.ZERO, "boss stays still during recovery")
	boss._beast_velocity(2.0)
	player.position = boss.position + Vector2(60, 0)
	boss._beast_velocity(0.01)
	check(boss.shock_warning > 0, "close target gets a warned pulse")
	var hp := player.health
	boss._beast_velocity(0.56)
	check(player.health == hp - GateBoss.SHOCK_DAMAGE, "standing in melee through pulse is punished")
	boss.recovery_time = 0
	boss.next_attack_shock = true
	boss._beast_velocity(0.01)
	player.position = boss.position + Vector2(250, 0)
	player.hurt_immunity = 0
	hp = player.health
	boss._beast_velocity(0.56)
	check(player.health == hp, "walking outside the warned pulse avoids damage")
	boss.take_hit(boss.max_health * 0.45, Vector2.RIGHT, false)
	boss.recovery_time = 0
	boss.next_attack_shock = false
	player.position = boss.position + Vector2(300, 0)
	boss._beast_velocity(0.01)
	boss._beast_velocity(0.53)
	boss._beast_velocity(0.5)
	player.position = boss.position + Vector2(0, 200)
	boss._beast_velocity(0.01)
	check(boss.phase == 2 and boss.warning_time > 0 and boss.locked_direction == Vector2.DOWN and boss.recovery_time == 0, "phase two separately warns and retargets a second charge")
	boss._beast_velocity(0.53)
	boss._beast_velocity(0.5)
	boss._beast_velocity(0.01)
	check(boss.recovery_time >= boss._attack_delay(), "second charge ends combo with a longer counter window")
	boss.recovery_time = 0
	boss.next_attack_shock = true
	player.position = boss.position + Vector2(250, 0)
	boss._beast_velocity(0.01)
	boss._beast_velocity(0.56)
	check(boss.ring_warning > 0, "late pulse asks for outside then inside movement")
	player.position = boss.position + Vector2(90, 0)
	boss._beast_velocity(0.76)
	check(player.health == hp, "returning inside avoids follow-up ring")
	boss.suspend_encounter()
	check(boss.recovery_time == 0 and boss.charge_followups == 0 and not boss.charge_pending, "leaving arena clears unfinished combos")
	arena.queue_free()
	await process_frame
	print("Temple boss rhythm: ", failures, " failures")
	quit(1 if failures else 0)
