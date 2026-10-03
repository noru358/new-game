extends SceneTree
## Independent mechanism/lifecycle regression for the approved candidate.
const Ledger = preload("res://tests/helpers/build_action_ledger.gd")
var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var p: SandboxPlayer = load("res://game/player.tscn").instantiate()
	p.position = Vector2(800, 700)
	p.flow_weave_enabled = true
	p.moving_slash_enabled = true
	arena.add_child(p)
	p.set_physics_process(false)
	var target := _target(arena, Vector2(880, 700), 1000.0)
	var other := _target(arena, Vector2(895, 710), 1000.0)
	p._hit_moving_slash(p.position, target.position)
	_check(p.flow_weave_ready, "slash hit prepares enhanced basic")
	var after_slash := target.health
	p.facing = Vector2.LEFT
	p._start_attack()
	p._hit_enemies(p._attack_spec(1))
	_check(p.flow_weave_ready and p.flow_weave_attack and not p.flow_weave_refund_used, "empty swing retains preparation without refund")
	_check(target.health == after_slash, "empty swing cannot damage target behind player")
	p.facing = Vector2.RIGHT
	p.moving_slash_cooldown = 0.5
	p._start_attack()
	var before := [target.health, other.health]
	var step := p.attack_step
	p._hit_enemies(p._attack_spec(step))
	var expected: float = p.ATTACK_DAMAGE * p.ATTACKS[step - 1].multiplier * 1.25
	_check(is_equal_approx(before[0] - target.health, expected) and is_equal_approx(before[1] - other.health, expected), "one enhanced swing keeps 25 percent on every hit target")
	_check(not p.flow_weave_ready and p.flow_weave_attack and p.flow_weave_refund_used, "first effective damage consumes preparation for this swing")
	_check(is_equal_approx(p.moving_slash_cooldown, 0.28), "multiple targets refund exactly 0.22 once")
	var after := [target.health, other.health]
	p._hit_enemies(p._attack_spec(step))
	_check(target.health == after[0] and other.health == after[1] and is_equal_approx(p.moving_slash_cooldown, 0.28), "repeated active frames cannot damage or refund twice")
	p._start_attack()
	_check(not p.flow_weave_attack, "following basic is not enhanced again")
	# Invalid targets do not consume a prepared action.
	other.remove_from_group("training_enemies")
	target.health = 0.0
	p.flow_weave_ready = true
	p._start_attack()
	p._hit_enemies(p._attack_spec(p.attack_step))
	_check(p.flow_weave_ready and not p.flow_weave_refund_used and target.health == 0.0, "dead but not yet freed target is ignored")
	target.remove_from_group("training_enemies")
	var boss := GateBoss.new()
	var waves := {"count": 0}
	p.flow_wave_enabled = true
	p.flow_wave_triggered.connect(func(_point): waves.count += 1)
	boss.position = Vector2(880, 700)
	boss.encounter_active = false
	arena.add_child(boss)
	boss.set_physics_process(false)
	p._start_attack()
	var boss_before := boss.health
	p._hit_enemies(p._attack_spec(p.attack_step))
	_check(boss.health == boss_before and p.flow_weave_ready and not p.flow_weave_refund_used, "inactive boss that rejects damage does not consume or refund")
	_check(waves.count == 0 and not p.flow_wave_used, "invalid target cannot trigger the optional enhanced-hit wave")
	boss.encounter_active = true
	p.attack_path_filter = func(_from: Vector2, _to: Vector2) -> bool: return false
	p._start_attack()
	p._hit_enemies(p._attack_spec(p.attack_step))
	_check(boss.health == boss_before and p.flow_weave_ready, "blocked line of attack retains preparation")
	p.attack_path_filter = Callable()
	p.moving_slash_cooldown = 0.1
	p._start_attack()
	p._hit_enemies(p._attack_spec(p.attack_step))
	_check(boss.health < boss_before and not p.flow_weave_ready and p.moving_slash_cooldown == 0.0, "active boss damage consumes once and refund clamps at zero")
	_check(waves.count == 1 and p.flow_wave_used, "first valid enhanced hit triggers the existing wave once")
	# Killing a living target is a valid hit; negative HP is overkill, not denial.
	boss.remove_from_group("training_enemies")
	var fragile := _target(arena, Vector2(880, 700), 1.0)
	p.flow_weave_ready = true
	p.moving_slash_cooldown = 0.4
	p._start_attack()
	p._hit_enemies(p._attack_spec(p.attack_step))
	_check(fragile.health < 0.0 and not p.flow_weave_ready and is_equal_approx(p.moving_slash_cooldown, 0.18), "living target killed by the enhanced hit still consumes and refunds")
	p.flow_weave_ready = true
	p.restore_for_boss_retry()
	_check(not p.flow_weave_ready and not p.flow_weave_attack, "boss retry clears preparation and active enhancement")
	p.flow_weave_ready = true
	p.flow_weave_attack = true
	p.clear_flow_weave()
	_check(not p.flow_weave_ready and not p.flow_weave_attack and not p.flow_weave_refund_used, "run-end mount reset clears all transient weave flags")
	var fresh: SandboxPlayer = load("res://game/player.tscn").instantiate()
	arena.add_child(fresh)
	fresh.set_physics_process(false)
	_check(not fresh.flow_weave_enabled and not fresh.flow_weave_ready and not fresh.flow_weave_attack, "new player without W_FLOW cannot inherit old flags")
	fresh.flow_weave_enabled = true
	_check(not fresh.flow_weave_ready, "new W_FLOW equipment starts unprepared")
	# Ledger arithmetic separates useful damage, overkill and the cooldown floor.
	var ledger = Ledger.new()
	ledger.register(1, 10.0)
	ledger.begin("basic", 1, 0.0)
	ledger.hit(1, -5.0, "basic", 1, 0.1)
	ledger.hit(1, -5.0, "basic", 1, 0.1)
	ledger.finish("basic", 1, 0.2, false)
	ledger.refund(0.1, 0.0, 0.1, 1)
	var report: Dictionary = ledger.snapshot()
	_check(report.damage.basic.raw == 15.0 and report.damage.basic.effective == 10.0 and report.damage.basic.overkill == 5.0 and report.damage.basic.hits == 1, "ledger clips damage at remaining positive HP and deduplicates unchanged HP")
	_check(report.actions.basic.started == 1 and report.actions.basic.hitting == 1 and report.actions.basic.missed_completed == 0, "ledger counts actions separately from target hits")
	_check(is_equal_approx(report.refund_effective_seconds, 0.1), "ledger measures actual cooldown saving at the floor")
	arena.queue_free()
	await process_frame
	await _lifecycle()
	print("Flow weave retention checks=", checks, " failures=", failures)
	quit(1 if failures else 0)

func _target(arena: Node2D, point: Vector2, hp: float) -> TrainingEnemy:
	var enemy := TrainingEnemy.new()
	enemy.position = point
	enemy.max_health = hp
	arena.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy

func _lifecycle() -> void:
	var prefix := "user://flow_weave_lifecycle_profile"
	var unlock_prefix := "user://flow_weave_lifecycle_unlocks"
	var profile := RunProfile.new()
	profile.save_prefix = prefix
	var unlocks := UnlockProgress.new()
	unlocks.save_prefix = unlock_prefix
	for i in 6: unlocks.add_levelup()
	_check(profile.settle("flow-weave-prior-fixture", "SUCCESS", 100) and profile.buy_gear("W_FLOW") and profile.equip("W_FLOW"), "lifecycle fixture owns and separately equips existing W_FLOW")
	var scene = _scene(prefix, unlock_prefix)
	root.add_child(scene)
	await physics_frame
	await physics_frame
	_check(scene.player.flow_weave_enabled and not scene.player.flow_weave_ready, "equipped W_FLOW enters real region unprepared")
	scene.player.flow_weave_ready = true
	scene.player.flow_weave_attack = true
	scene._finish_run("RETREAT")
	_check(scene.run_ended and not scene.player.flow_weave_ready and not scene.player.flow_weave_attack, "parent run-end mount clears transient state on real settlement")
	scene.queue_free()
	await process_frame
	paused = false
	var restarted = _scene(prefix, unlock_prefix)
	root.add_child(restarted)
	await physics_frame
	await physics_frame
	_check(restarted.player.flow_weave_enabled and not restarted.player.flow_weave_ready and not restarted.player.flow_weave_attack, "new run of same saved W_FLOW does not inherit preparation")
	restarted.player.flow_weave_ready = true
	restarted.queue_free()
	await process_frame
	profile.load_state()
	_check(profile.equip("W_START"), "saved equipment switches through existing equip API")
	var changed = _scene(prefix, unlock_prefix)
	root.add_child(changed)
	await physics_frame
	await physics_frame
	_check(not changed.player.flow_weave_enabled and not changed.player.flow_weave_ready and not changed.player.flow_weave_attack, "changed weapon enters next run without W_FLOW flags")
	changed.queue_free()
	await process_frame
	for suffix in ["_a.json", "_b.json"]:
		if FileAccess.file_exists(prefix + suffix):
			var contents := FileAccess.get_file_as_string(prefix + suffix)
			_check(not contents.contains("flow_weave"), "transient preparation is absent from both saved profile slots")

func _scene(prefix: String, unlock_prefix: String):
	var scene = load("res://game/hybrid_region.tscn").instantiate()
	scene.profile_save_prefix = prefix
	scene.growth_save_prefix = unlock_prefix
	return scene

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)
