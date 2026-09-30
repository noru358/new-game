extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)
func _run() -> void:
	for path in ["res://game/gate_boss.tscn", "res://game/jungle_warden.tscn"]:
		var boss: GateBoss = load(path).instantiate()
		root.add_child(boss)
		boss.set_physics_process(false)
		var hp := boss.health
		boss.take_direct_hit(100, Vector2.RIGHT, false)
		check(boss.health == hp - 100 and boss.counter_flash == 0, "ordinary hits keep their damage")
		boss.recovery_time = 1.2
		hp = boss.health
		check(boss.take_direct_hit(100, Vector2.RIGHT, true) and is_equal_approx(boss.health, hp - 130), "direct counter gets a single 30 percent bonus")
		check(boss.recovery_time == 1.2 and boss.counter_flash > 0, "counter reaction never extends or cancels the fixed recovery")
		hp = boss.health
		boss.take_hit(100, Vector2.RIGHT, false)
		check(boss.health == hp - 100, "automatic and secondary damage do not inherit direct counter bonus")
		boss.suspend_encounter()
		hp = boss.health
		check(not boss.take_direct_hit(100, Vector2.RIGHT, false) and boss.health == hp and boss.counter_flash == 0, "boundary suspension blocks counter damage and clears feedback")
		boss.queue_free()
		await process_frame
	print("Counter reward: %d failures" % failures)
	quit(1 if failures else 0)
