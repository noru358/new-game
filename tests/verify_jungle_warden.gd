extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var player := SandboxPlayer.new()
	player.position = Vector2(1400, 1000)
	arena.add_child(player)
	player.set_physics_process(false)
	var boss: JungleWarden = load("res://game/jungle_warden.tscn").instantiate()
	boss.position = Vector2(1200, 1000)
	boss.target = player
	arena.add_child(boss)
	boss.set_physics_process(false)
	boss._beast_velocity(0.01)
	_check(boss.sweep_warning > 0.0 and boss.gust_warning == 0.0, "guardian warns before its lateral sweep")
	var warning: float = boss.sweep_warning
	boss.take_hit(50.0, Vector2.RIGHT, true)
	boss.gather_to(Vector2(1700, 1000))
	_check(boss.sweep_warning == warning and boss.position == Vector2(1200, 1000), "hits and third-hit pull do not interrupt the guardian")
	player.position = Vector2(1200, 700)
	var safe_health: float = player.health
	boss._beast_velocity(1.0)
	_check(player.health == safe_health and boss.sweep_burst_time > 0.0, "moving out of the sweep's marked forward strip is safe")
	var sidestep: Vector2 = boss._beast_velocity(0.40)
	_check(sidestep.length() > 250.0 and absf(sidestep.dot(Vector2.UP)) > 200.0, "sweep is followed by a fast lateral reposition")
	boss.attack_cooldown = 0.0
	player.position = Vector2(1400, 1000)
	boss._beast_velocity(0.01)
	_check(boss.gust_warning > 0.0, "second pattern warns before its directional gust")
	boss._beast_velocity(1.0)
	_check(player.health == safe_health - JungleWarden.GUST_DAMAGE and player.hurt_recoil.length() >= 400.0, "standing in the gust takes damage and is pushed")
	var follow: Vector2 = boss._beast_velocity(0.40)
	_check(follow.length() > 250.0 and follow.dot(Vector2.RIGHT) > 200.0, "gust is followed by forward pursuit")
	boss.take_hit(350.0, Vector2.RIGHT, false)
	_check(boss.phase == 2 and boss.health > 0.0, "guardian escalates below sixty percent health")
	boss.attack_cooldown = 0.0
	boss._beast_velocity(0.01)
	_check(boss.sweep_warning > 0.0 and boss.sweep_warning < JungleWarden.SWEEP_WARNING, "second-phase sweep warning is shorter")
	player.health = 1000.0
	player.hurt_immunity = 1000.0
	boss.attacks_fired = 0
	boss.set_physics_process(true)
	for i in 300: await physics_frame
	_check(boss.attacks_fired >= 2, "the guardian repeats both patterns in live physics after its phase change")
	arena.queue_free()
	await process_frame
	if failures == 0: print("Jungle guardian verification passed: sweep dodge, gust push and second phase")
	quit(1 if failures else 0)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)
