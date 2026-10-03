extends SceneTree

const PROFILE_PREFIX := "user://verify_1g_soak_profile_temp"
const UNLOCK_PREFIX := "user://verify_1g_soak_unlock_temp"

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _run() -> void:
	for prefix in [PROFILE_PREFIX, UNLOCK_PREFIX]:
		for suffix in ["_a.json", "_b.json"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(prefix + suffix))
	var scene = load("res://game/hybrid_region.tscn").instantiate()
	scene.profile_save_prefix = PROFILE_PREFIX
	scene.growth_save_prefix = UNLOCK_PREFIX
	root.add_child(scene)
	for i in 3: await physics_frame
	scene.player.hurt_immunity = 10000.0
	var started := Time.get_ticks_msec()
	var max_active := 0
	var choices := 0
	var samples := 0
	Engine.time_scale = 8.0
	while scene.run_time < scene.BOSS_TIME + 5.0 and Time.get_ticks_msec() - started < 180000:
		await physics_frame
		if scene.growth.choosing:
			scene.growth.choose_index(0)
			choices += 1
		max_active = maxi(max_active, scene._active_enemy_count())
		samples += 1
		if scene.run_ended: break
	Engine.time_scale = 1.0
	_check(scene.run_time >= scene.BOSS_TIME + 5.0 and not scene.run_ended, "accelerated four-minute time axis reaches the boss without an unintended ending")
	_check(scene.boss_spawned and is_instance_valid(scene.boss), "boss still appears after live spawning and card choices")
	_check(max_active <= scene.MAX_ENEMIES and max_active > 0, "enemy cap holds throughout the full time axis")
	_check(choices > 0 and scene.growth.level > 1 and scene.run_currency > 0, "automatic XP, card choices and currency progress through a full run")
	if is_instance_valid(scene.boss):
		scene.teleport(scene.temple_section.RETRY_POINT)
		scene.temple_section.tick(0.0)
		scene.boss.take_hit(scene.boss.max_health * 2.0, Vector2.RIGHT, true)
		for i in 3: await physics_frame
		_check(scene.run_ended and scene.end_result == "SUCCESS" and not scene.settlement_pending, "boss defeat settles the accumulated long-run currency")
	print("1G soak: %.1f game seconds in %.1f wall seconds, %d physics samples, %d kills, %d choices, max %d active, %d currency" % [scene.run_time, float(Time.get_ticks_msec() - started) / 1000.0, samples, scene.kills, choices, max_active, scene.run_currency])
	scene.queue_free()
	for i in 2: await process_frame
	for prefix in [PROFILE_PREFIX, UNLOCK_PREFIX]:
		for suffix in ["_a.json", "_b.json"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(prefix + suffix))
	if failures == 0: print("1G accelerated full-run soak passed")
	quit(1 if failures else 0)
