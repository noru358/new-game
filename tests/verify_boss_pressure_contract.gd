extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", message)


func _run() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var player: SandboxPlayer = load("res://game/player.tscn").instantiate()
	player.position = Vector2(640, 360)
	player.max_health = 1000.0
	arena.add_child(player)
	player.health = player.max_health
	player.set_physics_process(false)
	var boss: GateBoss = load("res://game/gate_boss.tscn").instantiate()
	boss.position = player.position + Vector2(90, 0)
	boss.target = player
	arena.add_child(boss)
	boss.set_physics_process(false)
	_check(is_equal_approx(boss._attack_delay(), 1.0), "default early recovery is one second")
	boss.brisk_cadence = false
	_check(is_equal_approx(boss._attack_delay(), 1.2), "old early recovery remains selectable")
	boss.phase = 2
	_check(is_equal_approx(boss._attack_delay(), 1.45), "old late recovery remains selectable")
	boss.brisk_cadence = true
	_check(is_equal_approx(boss._attack_delay(), 1.2), "new late recovery still gives a counter window")
	boss.phase = 1
	boss.next_attack_shock = true
	boss._finish_pattern()
	_check(boss.shock_warning == GateBoss.SHOCK_WARNING and boss.recovery_time == 0.0, "close first charge links into a full pulse warning")
	var health_before := player.health
	player.position = boss.position + Vector2(270, 0)
	boss._beast_velocity(GateBoss.SHOCK_WARNING + 0.01)
	_check(player.health == health_before and boss.recovery_time >= boss._attack_delay() and not boss.next_attack_shock, "leaving the pulse circle avoids the linked strike and opens the full counter window")
	boss.recovery_time = 0.0
	boss.shock_warning = 0.0
	boss.brisk_cadence = false
	boss.next_attack_shock = true
	player.position = boss.position + Vector2(90, 0)
	boss._finish_pattern()
	_check(boss.shock_warning == 0.0 and is_equal_approx(boss.recovery_time, 1.2), "the baseline restores separate charge and pulse patterns")
	var warden: JungleWarden = load("res://game/jungle_warden.tscn").instantiate()
	warden.position = player.position + Vector2(180, 0)
	warden.target = player
	arena.add_child(warden)
	warden.set_physics_process(false)
	_check(is_equal_approx(warden._attack_delay(), 1.0), "jungle uses the same reversible early counter interval")
	warden.brisk_cadence = false
	_check(is_equal_approx(warden._attack_delay(), 1.2), "jungle baseline interval is reproducible")
	arena.queue_free()
	await process_frame
	print("Boss pressure contract: ", failures, " failures")
	quit(1 if failures else 0)
