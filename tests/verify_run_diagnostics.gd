extends SceneTree

const PROFILE := "user://verify_run_diagnostics_profile"
const UNLOCKS := "user://verify_run_diagnostics_unlocks"
var failures := 0
var now_usec := 0


func _initialize() -> void: call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func scene_for(enabled: bool):
	var scene = load("res://game/hybrid_region.tscn").instantiate()
	scene.profile_save_prefix = PROFILE
	scene.growth_save_prefix = UNLOCKS
	scene.diagnostics_enabled = enabled
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
	return scene


func cleanup() -> void:
	for prefix in [PROFILE, UNLOCKS]:
		for suffix in ["_a.json", "_b.json"]:
			var path := ProjectSettings.globalize_path(prefix + suffix)
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)


func _run() -> void:
	cleanup()
	var scene = await scene_for(false)
	check(scene.diagnostics == null, "diagnostics are absent by default")
	scene.queue_free()
	await process_frame
	cleanup()
	scene = await scene_for(true)
	var d = scene.diagnostics
	check(d != null, "explicit opt-in installs the local observer")
	# Deterministic clock fixture; production uses monotonic microseconds.
	d.clock = func(): return now_usec
	d.started_usec = 0
	d.last_usec = 0
	d.wall_usec = {"active": 0, "choice": 0, "pause": 0}
	scene.run_time = 2.0
	now_usec = 2000000
	d.observe(scene)
	scene.player.health = 95.0
	scene.growth.gain_xp(8)
	check(is_equal_approx(d.level_heal, 5.0) and d.level_heal_events == 1, "95 to 100 records five actual level-heal HP")
	now_usec = 5000000
	scene.growth.reroll_choices()
	scene.growth.gain_xp(22)
	check(scene.growth.points_earned == 3 and scene.growth.choice_windows_opened == 1, "overflow retains the original choice window and point accounting")
	check(d.level_heal == 5.0 and d.level_heal_events == 3, "overhealing is clipped while logical level-heal events are retained")
	scene.growth.choose_index(0)
	now_usec = 7000000
	scene.growth.choose_index(0)
	now_usec = 9000000
	scene.growth.choose_index(0)
	check(d.snapshot(scene).choice_wall_seconds == 7.0, "reroll and sequential cards count one continuous seven-second choice interval")
	check(d.level_heal == 5.0 and d.level_heal_events == 3, "card selection never adds a second heal")
	now_usec = 10000000
	scene._set_paused(true)
	now_usec = 13000000
	var report: Dictionary = d.snapshot(scene)
	check(report.active_wall_seconds == 3.0 and report.choice_wall_seconds == 7.0 and report.pause_wall_seconds == 3.0 and report.wall_seconds == 13.0, "active, card and external pause wall time are disjoint")
	check(report.active_seconds == 2.0, "diagnostics read the gameplay clock without advancing it")
	scene._set_paused(false)
	now_usec = 14000000
	scene.player.health = 10.0
	scene.supply_ready = true
	scene.player.health_changed.connect(scene._try_use_supply)
	scene.growth.gain_xp(scene.growth.next_xp())
	check(scene.player.health == 60.0 and d.level_heal == 25.0, "10 to 30 records twenty level-heal HP and excludes the following thirty-point supply heal")
	scene.growth.reroll_choices()
	scene.growth.choose_index(0)
	check(d.level_heal == 25.0, "supply-triggering level heal is not counted again on reroll or selection")
	scene.player.health = 40.0
	scene.supply_ready = true
	scene.player.receive_hit(10.0)
	check(scene.player.health == 60.0 and d.damage_taken == 10.0 and d.damage_events == 1, "damage records ten HP before supply healing masks it")
	scene.player.receive_hit(50.0)
	check(d.damage_taken == 10.0 and d.damage_events == 1, "invulnerable ignored hits add no damage event")
	now_usec = 15000000
	scene.growth.gain_xp(scene.growth.next_xp())
	now_usec = 17000000
	root.focus_exited.emit()
	now_usec = 20000000
	scene.growth.choose_index(0)
	check(paused and scene.paused, "focus pause remains after the choice closes")
	now_usec = 22000000
	scene._set_paused(false)
	report = d.snapshot(scene)
	check(report.choice_wall_seconds == 9.0 and report.pause_wall_seconds == 8.0, "focus interruption while choosing is pause time, without double counting")
	check(report.wall_seconds == report.active_wall_seconds + report.choice_wall_seconds + report.pause_wall_seconds, "wall-time ledger reconciles exactly")
	check(d.snapshot(scene) == report, "repeated same-time snapshots do not inflate totals")
	# Exercise real destination-boss hooks without treating this fixture as play.
	scene.run_time = 300.0
	scene.temple_section.tick(0.0)
	now_usec = 24000000
	scene.run_time = 301.2
	scene.temple_section.tick(1.2)
	check(d.boss_times.has("ready") and is_equal_approx(d.boss_times.ready.active_seconds, 301.2), "ready event records actual post-warning boss creation")
	scene.teleport(scene.temple_section.retry_point)
	scene.temple_section.tick(0.0)
	check(d.boss_times.has("arrive") and d.boss_times.has("engage") and d.boss_engagements == 1, "arrival and first engagement use destination-boundary hooks")
	var first_engagement: Dictionary = d.boss_times.engage.duplicate()
	scene.teleport(scene.start_point)
	scene.temple_section.tick(0.0)
	now_usec = 27000000
	scene.run_time = 304.0
	scene.teleport(scene.temple_section.retry_point)
	scene.temple_section.tick(0.0)
	check(d.boss_engagements == 2 and d.boss_times.engage == first_engagement, "re-entry counts engagements without replacing the first timestamp")
	var healed_before_retry: float = d.level_heal
	var first_ready: Dictionary = d.boss_times.ready.duplicate()
	scene.player.health = 0.0
	scene.death_pending = true
	check(scene.temple_section.handle_death(), "boss death opens the existing retry flow")
	scene.temple_section.retry_boss()
	check(d.boss_engagements == 3 and d.boss_times.ready == first_ready and d.boss_times.engage == first_engagement, "retry records one engagement without replacing first ready or engage times")
	check(scene.player.health == scene.player.max_health and d.level_heal == healed_before_retry, "retry restoration is not misreported as level-up healing")
	now_usec = 30000000
	scene.run_time = 307.0
	scene.boss.take_hit(scene.boss.max_health * 2.0, Vector2.RIGHT, true)
	check(d.boss_times.has("kill") and d.boss_times.kill.active_seconds == 307.0, "boss defeat records the real kill hook")
	scene._finish_run("SUCCESS")
	report = d.snapshot(scene)
	now_usec = 40000000
	d.record_level_heal(100.0)
	d.record_damage(100.0)
	d.boss_event("ready", 999.0)
	scene.run_time = 999.0
	scene.run_currency = 999
	scene.player.health = 1.0
	check(d.finished and d.snapshot(scene) == report and d.finish(scene, "DEFEAT") == report, "terminal report freezes once, excluding result-screen time and late events")
	var serialized := JSON.stringify(report)
	check(not serialized.contains("user://") and not serialized.contains("save_prefix") and not serialized.contains("run_id"), "report contains gameplay counters rather than profile paths or identifiers")
	paused = false
	scene.queue_free()
	await process_frame
	cleanup()
	print("Run diagnostics verification: ", failures, " failures")
	quit(1 if failures else 0)
