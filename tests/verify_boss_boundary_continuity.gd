extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", message)


func _run() -> void:
	for jungle in [false, true]:
		var scene: Node3D = load("res://game/jungle_pass.tscn" if jungle else "res://game/hybrid_region.tscn").instantiate()
		scene.profile_save_prefix = "user://verify_boss_boundary_%s_profile" % ("jungle" if jungle else "temple")
		scene.growth_save_prefix = "user://verify_boss_boundary_%s_unlocks" % ("jungle" if jungle else "temple")
		root.add_child(scene)
		await process_frame
		scene.set_physics_process(false)
		scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
		scene.player.set_physics_process(false)
		var section: Node = scene.temple_section
		var outside: Vector2 = section.boss_area.position - Vector2(80, -section.boss_area.size.y * 0.5)
		var inside: Vector2 = section.boss_area.get_center()
		scene.player.global_position = outside
		scene.run_time = scene.BOSS_TIME - 0.01
		section.tick(0.0)
		_check(not scene.boss_announced, "boss remains unannounced before the four-minute deadline")
		scene.run_time = scene.BOSS_TIME
		section.tick(0.0)
		_check(scene.boss_announced and not scene.boss_spawned, "four-minute deadline starts the existing visible spawn warning")
		section.tick(1.3)
		_check(scene.boss_spawned and section.boss_ready, "warning spawns the waiting destination boss")
		var boss: GateBoss = scene.boss
		boss.set_physics_process(false)
		var initial_health := boss.health
		scene.player.global_position = inside
		section.tick(0.0)
		_check(section.boss_active and boss.encounter_active, "entry engages the boss")
		if jungle:
			boss.sweep_warning = 0.12
		else:
			boss.warning_time = 0.12
		var fired_before := boss.attacks_fired
		scene.player.global_position = outside
		section.tick(0.0)
		_check(not section.boss_active and not boss.encounter_active and boss.health == initial_health, "free exit pauses combat without resetting HP")
		_check(boss.sweep_warning > 0.0 if jungle else boss.warning_time > 0.0, "exit cannot erase a warned boss attack")
		scene.player.global_position = inside
		section.tick(0.0)
		_check((boss.sweep_warning if jungle else boss.warning_time) >= GateBoss.REENTRY_WARNING_FLOOR, "re-entry leaves readable warning time")
		boss._beast_velocity(0.36)
		_check(boss.attacks_fired == fired_before + 1, "the paused attack resolves on re-entry")
		if jungle:
			boss.recovery_time = 0.0
			boss.combo_gap = 0.12
			boss.combo_attacks_left = 1
			boss.pending_gust = true
		else:
			boss.recovery_time = 0.0
			boss.warning_time = 0.0
			boss.charge_time = 0.2
			boss.charge_pending = true
			boss.charge_followups = 1
		scene.player.global_position = outside
		section.tick(0.0)
		scene.player.global_position = inside
		section.tick(0.0)
		if jungle:
			_check(boss.combo_gap > 0.0 and boss.combo_attacks_left == 1, "jungle follow-up survives a boundary crossing")
			boss._beast_velocity(0.13)
			_check(boss.gust_warning > 0.0, "jungle follow-up resumes with its wind warning")
		else:
			_check(boss.charge_time == 0.0 and boss.warning_time >= GateBoss.REENTRY_WARNING_FLOOR and boss.charge_followups == 1, "mid-charge exit converts to a warned resumed charge")
			boss._beast_velocity(boss.warning_time + 0.01)
			_check(boss.charge_time > 0.0, "resumed charge follows the full visible warning")
		_check(not section.retry_used and not section.retry_pending, "free exit leaves the one boss retry untouched")
		print("BOSS_BOUNDARY jungle=", jungle, " hp=", boss.health, " fired=", boss.attacks_fired)
		scene.queue_free()
		await process_frame
		for prefix in ["user://verify_boss_boundary_%s_profile" % ("jungle" if jungle else "temple"), "user://verify_boss_boundary_%s_unlocks" % ("jungle" if jungle else "temple")]:
			for suffix in ["_a.json", "_b.json"]:
				var path := ProjectSettings.globalize_path(prefix + suffix)
				if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("Boss boundary continuity: ", failures, " failures")
	quit(1 if failures else 0)
