extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", message)


func _attack_state(boss: GateBoss) -> Array[float]:
	var state: Array[float] = [boss.warning_time, boss.charge_time, boss.shock_warning, boss.ring_warning, boss.recovery_time]
	if boss is JungleWarden:
		state.append(boss.sweep_warning)
		state.append(boss.gust_warning)
		state.append(boss.combo_gap)
	return state


func _warning_active(boss: GateBoss) -> bool:
	return boss.warning_time > 0.0 or boss.shock_warning > 0.0 or boss.ring_warning > 0.0 or boss is JungleWarden and (boss.sweep_warning > 0.0 or boss.gust_warning > 0.0)


func _run() -> void:
	for jungle in [false, true]:
		var arena := Node2D.new()
		root.add_child(arena)
		var player: SandboxPlayer = load("res://game/player.tscn").instantiate()
		player.position = Vector2(640, 360)
		player.max_health = 10000.0
		arena.add_child(player)
		player.health = player.max_health
		player.set_physics_process(false)
		var boss: GateBoss = load("res://game/jungle_warden.tscn" if jungle else "res://game/gate_boss.tscn").instantiate()
		boss.position = player.position + Vector2(120, 0)
		boss.target = player
		boss.collision_mask = 4
		boss.encounter_area = Rect2(0, 0, 1280, 720)
		arena.add_child(boss)
		var wisp := WispCompanion.new()
		wisp.player = player
		wisp.attack_interval = 0.27
		wisp.projectile_speed = 1800.0
		wisp.damage_multiplier = 0.12
		wisp.target_visibility_filter = func(_candidate: TrainingEnemy) -> bool: return true
		arena.add_child(wisp)
		var companion_hits := [0]
		wisp.enemy_hit.connect(func(_enemy: TrainingEnemy) -> void: companion_hits[0] += 1)
		var direct_hits := 0
		var interrupted_warnings := 0
		var previous_warning := false
		var previous_fired := 0
		for frame in 840:
			await physics_frame
			if not is_instance_valid(boss) or boss.is_queued_for_deletion(): break
			var warning := _warning_active(boss)
			if previous_warning and not warning and boss.attacks_fired == previous_fired:
				interrupted_warnings += 1
			previous_warning = warning
			previous_fired = boss.attacks_fired
			if frame % 9 == 0:
				var state := _attack_state(boss)
				boss.take_direct_hit(1.0, Vector2.LEFT, frame % 36 == 0)
				_check(state == _attack_state(boss), "direct hits preserve active boss intent and recovery")
				direct_hits += 1
		_check(direct_hits >= 80 and companion_hits[0] >= 8, "real direct and automatic companion hits continue through the encounter")
		_check(interrupted_warnings == 0, "continuous hits do not erase boss warnings without firing")
		_check(boss.attacks_started >= 3 and boss.attacks_fired >= 3, "boss fires several patterns under continuous hits")
		print("BOSS_HIT_CONTINUITY jungle=", jungle, " direct=", direct_hits, " companion=", companion_hits[0], " started=", boss.attacks_started, " fired=", boss.attacks_fired, " interrupts=", interrupted_warnings)
		arena.queue_free()
		await process_frame
	print("Boss hit continuity: ", failures, " failures")
	quit(1 if failures else 0)
