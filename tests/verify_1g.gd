extends SceneTree

const PROFILE_PREFIX := "user://verify_1g_run_profile_temp"
const UNLOCK_PREFIX := "user://verify_1g_run_unlock_temp"
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _frames(count: int) -> void:
	for i in count: await physics_frame

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _new_scene() -> Node3D:
	var scene = load("res://game/hybrid_region.tscn").instantiate()
	scene.profile_save_prefix = PROFILE_PREFIX
	scene.growth_save_prefix = UNLOCK_PREFIX
	root.add_child(scene)
	return scene

func _run() -> void:
	for prefix in [PROFILE_PREFIX, UNLOCK_PREFIX]:
		for suffix in ["_a.json", "_b.json"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(prefix + suffix))
	var scene := _new_scene()
	await _frames(3)
	_check(scene.actors.size() == 1 and scene.run_time > 0.0 and not scene.show_practice_controls, "main scene begins a live timed run without fixed practice enemies")
	_check(scene.run_hud.text.contains("문지기까지 05:00"), "the live HUD shows the five-minute boss countdown")
	_check(not scene.player.moving_slash_enabled and scene.player.combo_limit() == 2, "fresh live run starts with two attacks before early permanent move milestones")
	scene.growth.gain_xp(scene.growth.next_xp())
	_check(scene.growth.choosing and not scene.growth.current_choices.has("U_CHAIN"), "first level-up offers a card without re-selling the permanent combo")
	_check(scene.growth.describe_card("S_WISP_CADENCE", 1).contains("→") and scene.growth.describe_card("S_WISP_CADENCE", 1).contains("초"), "numeric cards explain the actual before and after value")
	var prior_choices: Array[String] = scene.growth.current_choices.duplicate()
	var rerolled: bool = scene.growth.reroll_choices()
	_check(rerolled and scene.growth.rerolls_left == 0 and scene.growth.current_choices != prior_choices, "one reroll changes at least one offered card")
	scene.growth.choose_index(0)
	_check(scene.player.moving_slash_enabled and scene.player.combo_limit() == 3, "first lifetime level-up opens Q and the third attack")
	for i in 2:
		scene.growth.gain_xp(scene.growth.next_xp())
		while scene.growth.choosing: scene.growth.choose_index(0)
	_check(scene.player.moving_slash_enabled and scene.player.combo_limit() == 4 and not scene.growth.roll_choices().has("U_CHAIN"), "three lifetime level-ups permanently open Q and the full combo without a combo card")
	scene.player.hurt_immunity = 1000.0
	var spawn_point: Vector2 = scene._choose_spawn_point(false)
	_check(spawn_point != Vector2.INF and scene.navigation.is_open(spawn_point, scene.ACTOR_CLEARANCE) and scene.navigation.find_path(spawn_point, scene.player.position).size() >= 2, "spawn finder chooses reachable clear ground away from player")
	scene._spawn_now(spawn_point, TrainingEnemy.Role.FRAGMENT, false)
	_check(scene._active_enemy_count() == 1, "time spawn joins the real combat scene")
	var first_enemy: TrainingEnemy = scene.actors.keys().filter(func(actor): return actor is TrainingEnemy)[0]
	_check(scene.actors[first_enemy].has_node("HealthBar"), "hybrid enemies carry a depth-tested overhead health bar")
	first_enemy.health = first_enemy.max_health * 0.5
	scene._update_health_bar(scene.actors[first_enemy], first_enemy)
	var bar_image: Image = scene._health_bar_image(first_enemy, 0.5)
	_check(is_equal_approx(float(scene.actors[first_enemy].get_node("HealthBar").get_meta("shown_ratio")), 0.5) and bar_image.get_pixel(12, 3) != bar_image.get_pixel(42, 3), "the overhead bar fills to the actual health ratio")
	for i in 47: scene.pending_spawns.append({"boss": false, "delay": 1000.0})
	scene.spawn_credit = 1.0
	scene._physics_process(0.0)
	_check(scene._active_enemy_count() == 48 and scene.spawn_credit < 1.0, "ordinary enemy cap discards a failed spawn attempt without building debt")
	scene.pending_spawns.clear()
	for actor in scene.actors:
		if actor is TrainingEnemy: actor.set_physics_process(false)
	var paused_at: float = scene.run_time
	scene._set_paused(true)
	await _frames(10)
	_check(is_equal_approx(scene.run_time, paused_at), "pause freezes run clock")
	scene._set_paused(false)
	scene.run_time = 45.0
	scene._update_run_hud()
	_check(scene.run_hud.text.contains("문지기까지 04:15"), "the countdown follows elapsed play time")
	_check(is_equal_approx(scene._spawn_rate(), 0.85), "second time band raises the spawn rate")
	scene.run_time = 120.0
	_check(is_equal_approx(scene._spawn_rate(), 1.10), "mixed-role time band begins")
	scene.run_time = 200.0
	_check(is_equal_approx(scene._spawn_rate(), 1.40), "late wave is denser")
	scene.run_time = 299.99
	await _frames(4)
	_check(scene.boss_announced, "the boss is announced when the five-minute clock is reached")
	await _frames(85)
	_check(scene.boss_spawned and is_instance_valid(scene.boss) and scene.boss.max_health == GateBoss.BOSS_HEALTH, "one boss appears after the warning")
	_check(scene.actors[scene.boss].has_node("HealthBar"), "the boss has the same world-space health readout")
	_check(scene.actors[scene.boss].has_node("BossFigure/BossCore") and not scene.actors[scene.boss].get_node("Body").visible, "the boss has a distinct stone sentinel silhouette")
	_check(not scene.boss.encounter_active, "destination boss waits until the player arrives")
	scene.teleport(scene.temple_section.RETRY_POINT)
	scene.temple_section.tick(0.0)
	for actor in scene.actors:
		if actor is TrainingEnemy: actor.set_physics_process(false)
	scene.paused = true
	scene.boss.position = scene.player.position + Vector2(200, 0)
	scene.boss.attack_cooldown = 0.0
	scene.boss.charge_time = 0.0
	scene.boss.warning_time = 0.0
	scene.boss.next_attack_shock = false
	scene.player.hurt_immunity = 0.0
	scene.boss._beast_velocity(0.01)
	_check(scene.boss.warning_time > 0.0 and scene.boss.next_attack_shock and scene.boss.shock_warning == 0.0, "boss starts with a warned charge")
	scene._update_run_hud()
	_check(scene.run_hud.text.contains("붉은 띠 밖으로 회피"), "charge warning names the safe response")
	scene.boss._beast_velocity(0.01)
	_check(scene.boss.warning_time > 0.0 and scene.boss.shock_warning == 0.0, "charge warning is not replaced by the next shock")
	for i in 60: scene.boss._beast_velocity(1.0 / 60.0)
	_check(scene.boss.charge_time == 0.0 and scene.boss.attack_cooldown > 0.0, "charge completes before the alternate pattern")
	scene.boss.attack_cooldown = 0.0
	scene.boss._beast_velocity(0.01)
	scene._draw_boss_warning()
	_check(scene.boss.shock_warning > 0.0 and scene.boss_warning_mesh.get_surface_count() > 0, "boss alternate shock has an airborne warning")
	scene._update_run_hud()
	_check(scene.run_hud.text.contains("주황 원 밖으로 회피"), "shock warning names its circular safe response")
	var before: float = scene.player.health
	scene.boss._beast_velocity(0.8)
	_check(scene.player.health == before - GateBoss.SHOCK_DAMAGE, "boss shock deals its displayed radius damage")
	scene.boss.take_hit(300.0, Vector2.RIGHT, false)
	scene.boss.ring_warning = GateBoss.RING_WARNING
	scene._draw_boss_warning()
	scene._update_run_hud()
	_check(scene.boss.phase == 2 and scene.boss_warning_mesh.get_surface_count() > 0 and scene.run_hud.text.contains("안쪽이 안전"), "second phase shows a separate outer-ring dodge")
	scene.player.health = 0.0
	scene.death_pending = true
	scene.boss.take_hit(1000.0, Vector2.RIGHT, true)
	_check(is_instance_valid(scene.ending_visual) and not scene.actors.has(scene.boss) and not scene.ending_visual.get_node("HealthBar").visible, "boss visual transfers to its ending without a duplicate live body or health bar")
	scene._physics_process(0.0)
	_check(scene.end_result == "SUCCESS" and scene.run_ended and scene.profile.temple_owned and scene.profile.temple_relic and scene.profile.currency >= 50, "same-frame boss and player defeat resolves success and first-clear settlement")
	var after_success: int = scene.profile.currency
	scene.queue_free()
	paused = false
	await process_frame
	var second := _new_scene()
	await _frames(3)
	_check(second.profile.currency == after_success and second.profile.temple_relic and second.player.combo_limit() == 4 and second.player.moving_slash_enabled, "next run restores first-clear and early permanent combat moves")
	second.run_currency = 5
	second.player.hurt_immunity = 0.0
	second.player.receive_hit(200.0, second.player.position + Vector2.LEFT)
	second._physics_process(0.0)
	_check(second.end_result == "DEFEAT" and second.profile.currency == after_success + 2 and second.profile.last_lost == 3 and not second.profile.last_first_clear, "death banks half of earned currency without a second first-clear reward")
	second.queue_free()
	paused = false
	await process_frame
	var third := _new_scene()
	await _frames(3)
	third.run_currency = 4
	var restart_key := InputEventKey.new()
	restart_key.pressed = true
	restart_key.keycode = KEY_R
	third._input(restart_key)
	_check(not third.run_ended and third.profile.currency == after_success + 2, "R does not end or restart an active run")
	restart_key.keycode = KEY_G
	third._input(restart_key)
	_check(not third.run_ended and third.retreat_overlay.visible and paused, "G pauses for confirmation before settlement")
	third._cancel_retreat()
	_check(not third.paused and not third.run_ended, "cancel resumes the original live run")
	third._request_retreat()
	third._finish_run("RETREAT")
	_check(third.end_result == "RETREAT" and third.profile.currency == after_success + 5 and third.profile.last_lost == 1 and third.profile.temple_relic, "confirmed retreat settles after a smaller loss")
	third.queue_free()
	paused = false
	await process_frame
	for prefix in [PROFILE_PREFIX, UNLOCK_PREFIX]:
		for suffix in ["_a.json", "_b.json"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(prefix + suffix))
	if failures == 0: print("1G verification passed: live spawn, pause, boss, success/death/retreat and settlement")
	quit(1 if failures else 0)
