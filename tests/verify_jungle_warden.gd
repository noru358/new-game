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
	var boss: JungleWarden = load("res://game/jungle_warden.tscn").instantiate()
	boss.position = Vector2(1000, 700)
	boss.target = player
	arena.add_child(boss)
	boss.set_physics_process(false)
	player.position = boss.position + Vector2(20, 0)
	boss._beast_velocity(0.01)
	check(boss.max_health == 2000 and boss.sweep_warning > 0, "trial health and visible close-range sweep")
	var hp := player.health
	boss._beast_velocity(0.71)
	check(player.health == hp - JungleWarden.SWEEP_DAMAGE, "point blank no longer bypasses the sweep")
	check(boss.recovery_time >= boss._attack_delay() and boss._beast_velocity(0.2) == Vector2.ZERO, "early attack gives stationary counter time")
	boss.recovery_time = 0
	boss.next_attack_gust = false
	player.hurt_immunity = 0
	player.position = boss.position + Vector2(100, 0)
	boss._beast_velocity(0.01)
	player.position = boss.position - Vector2(100, 0)
	hp = player.health
	boss._beast_velocity(0.71)
	check(player.health == hp, "moving behind committed sweep avoids damage")
	boss.recovery_time = 0
	boss.next_attack_gust = true
	player.position = boss.position + Vector2(450, 0)
	boss._beast_velocity(0.01)
	check(boss.gust_warning > 0, "gust threatens farther targets")
	player.position = boss.position + Vector2(100, 0)
	boss._beast_velocity(0.96)
	check(player.health == hp, "approaching the inner calm avoids outer wind")
	boss.take_hit(boss.max_health * 0.45, Vector2.RIGHT, false)
	boss.recovery_time = 0
	boss.next_attack_gust = false
	player.position = boss.position + Vector2(100, 0)
	var before := boss.attacks_fired
	boss._beast_velocity(0.01)
	for i in 3:
		boss._beast_velocity(0.96)
		if i < 2:
			check(boss.combo_gap > 0 and boss.recovery_time == 0, "late sequence continues before recovery")
			player.position = boss.position + Vector2(0, 100) if i == 0 else boss.position - Vector2(100, 0)
			boss._beast_velocity(0.19)
	check(boss.attacks_fired == before + 3 and boss.recovery_time >= boss._attack_delay(), "late sweep/gust/sweep combo ends in full counter opportunity")
	boss.suspend_encounter()
	check(boss.combo_attacks_left == 0 and boss.combo_gap == 0 and boss.sweep_warning == 0, "suspension clears follow-ups")
	arena.queue_free()
	await process_frame
	print("Jungle boss rhythm: ", failures, " failures")
	quit(1 if failures else 0)
