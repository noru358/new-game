extends SceneTree
const PROFILE := "user://verify_temple_section_profile"
const UNLOCKS := "user://verify_temple_section_unlocks"
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)
func fresh_scene():
	var scene = load("res://game/hybrid_region.tscn").instantiate()
	scene.profile_save_prefix = PROFILE
	scene.growth_save_prefix = UNLOCKS
	root.add_child(scene)
	return scene
func garden_clear(scene) -> void:
	scene.temple_section.enter_garden()
	scene.temple_section.tick(0.0)
	for point in scene.temple_section.GUARD_POINTS:
		scene.teleport(point + Vector2(0, 190))
		scene.temple_section.tick(1.1)
		for actor in scene.actors.keys():
			if is_instance_valid(actor) and actor is TrainingEnemy and not actor is GateBoss and scene.temple_section.GARDEN_AREA.has_point(actor.global_position) and actor.health > 0:
				actor.take_hit(10000.0, Vector2.RIGHT, false)
	while scene.growth.choosing: scene.growth.choose_index(0)
	scene.teleport(scene.temple_section.ALTAR_POINT)
func _run() -> void:
	for prefix in [PROFILE, UNLOCKS]:
		for suffix in ["_a.json", "_b.json"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(prefix + suffix))
	var seed := RunProfile.new()
	seed.save_prefix = PROFILE
	seed.currency = 100
	check(seed.buy_gear("A_EMBER") and seed.equip("A_EMBER"), "prepare owned accessory")
	var scene = fresh_scene()
	await process_frame
	var section = scene.temple_section
	check(section != null and not scene.is_place_discovered("TEMPLE_GARDEN"), "new run has an undiscovered garden")
	check(not scene.minimap._discovered_geometry({"discovery_id": "TEMPLE_GARDEN"}), "secret geometry hidden before discovery")
	check(scene.navigation.find_path(scene.start_point, section.RETRY_POINT).size() > 1 and scene.navigation.is_open(section.BOSS_POINT, 48), "boss route and spawn fit actual collision geometry")
	check(scene.navigation.find_path(Vector2(3400, 650), section.Garden.ENTRY_TRIGGER.get_center()).size() > 1, "hidden entrance is reachable from corridor")
	check(scene.navigation.find_path(section.Garden.FIELD_ENTRY, section.ALTAR_POINT).size() > 1, "mini-field entry reaches altar around pond and walls")
	check(scene.navigation.find_path(scene.start_point, section.ALTAR_POINT).is_empty(), "two fields cannot be crossed without the entrance")
	for point in section.GUARD_POINTS:
		check(scene.navigation.find_path(section.Garden.FIELD_ENTRY, point).size() > 1, "each guardian can be reached through actual paths")
	garden_clear(scene)
	check(section.guardians_defeated == 3 and section.guardian_reservations == 0 and scene.is_place_discovered("TEMPLE_GARDEN"), "three actual enemies guard the discovered garden")
	check(not scene.profile.awakenings.has("EMBER_GARDEN"), "discovery and combat alone do not grant awakening")
	var original_prefix: String = scene.profile.save_prefix
	scene.profile.save_prefix = "user://missing_garden_test_directory/profile"
	check(not section.claim_garden_reward() and not section.garden_claimed and not scene.profile.awakenings.has("EMBER_GARDEN"), "failed save never grants or consumes awakening")
	scene.profile.save_prefix = original_prefix
	check(section.claim_garden_reward() and not section.claim_garden_reward(), "altar grants reward once after successful save")
	check(is_equal_approx(scene.wisp.permanent_damage_bonus, 0.35) and scene.wisp.chain_jumps == 1, "equipped accessory awakening applies immediately")
	scene.apply_garden_awakening()
	check(is_equal_approx(scene.wisp.permanent_damage_bonus, 0.35), "reapplying cannot stack awakening")
	scene.growth.unlocks.lifetime_levelups = 6
	scene.growth.apply_card("S_WISP_CHAIN")
	check(scene.wisp.chain_jumps == 2, "card chains stack with permanent awakening")
	var saved := RunProfile.new()
	saved.save_prefix = PROFILE
	saved.load_state()
	check(saved.awakenings.has("EMBER_GARDEN") and saved.discovered_places.has("TEMPLE_GARDEN"), "awakening survives reload before settlement")
	section.leave_garden()
	scene.run_time = 300.0
	scene.teleport(Vector2(3400, 800))
	section.tick(0.0)
	check(not scene.boss_spawned and scene.boss_announced, "destination spawn is announced before appearing")
	section.tick(1.3)
	check(scene.boss_spawned and not scene.boss.encounter_active and scene.boss.position == section.BOSS_POINT, "five minutes creates a waiting destination boss")
	var health: float = scene.boss.health
	scene.boss.take_hit(50.0, Vector2.RIGHT, false)
	check(scene.boss.health == health, "outside player cannot damage sleeping boss")
	scene.teleport(section.RETRY_POINT)
	section.tick(0.0)
	scene.boss.take_hit(50.0, Vector2.RIGHT, false)
	check(section.boss_active and scene.boss.health == health - 50.0 and scene._spawn_rate() == 0.0, "entry engages boss and suspends ambient spawning")
	var intruder = scene._spawn_enemy_at(section.RETRY_POINT + Vector2(150, 0), TrainingEnemy.Role.FRAGMENT, 22.0)
	var currency: int = scene.run_currency
	section.tick(0.0)
	check(intruder.is_queued_for_deletion() and scene.run_currency == currency, "duel cleanup does not award enemy currency")
	scene.teleport(Vector2(3900, 1100))
	section.tick(0.0)
	check(not section.boss_active and not scene.boss.encounter_active and scene.boss.health == health - 50.0, "leaving suspends combat without resetting HP")
	scene.boss.take_hit(50.0, Vector2.RIGHT, false)
	check(scene.boss.health == health - 50.0, "outside attacks cannot chip boss")
	scene.teleport(section.RETRY_POINT)
	section.tick(0.0)
	check(scene.boss.health == health - 50.0, "reentry resumes remaining boss HP")
	var ranks: Dictionary = scene.growth.card_ranks.duplicate()
	var earned: int = scene.growth.points_earned
	var generation: int = scene.profile.generation
	scene.supply_ready = false
	scene.player.health = 0
	scene.death_pending = true
	scene._physics_process(0.0)
	check(section.retry_pending and paused and not scene.run_ended and scene.profile.generation == generation, "first boss death offers retry without settling")
	section.retry_boss()
	check(not paused and section.retry_used and scene.player.health == scene.player.max_health and scene.boss.health == scene.boss.max_health, "retry restores both combatants once")
	check(scene.growth.card_ranks == ranks and scene.growth.points_earned == earned and scene.run_currency == currency and not scene.supply_ready, "retry preserves build/currency and does not restore supplies")
	var boss_id: int = scene.boss.get_instance_id()
	section.retry_boss()
	check(scene.boss.get_instance_id() == boss_id, "duplicate retry input has no effect")
	scene.player.health = 0
	scene.death_pending = true
	scene._physics_process(0.0)
	check(scene.run_ended and scene.end_result == "DEFEAT", "second boss death settles defeat")
	saved.load_state()
	check(saved.awakenings.has("EMBER_GARDEN"), "boss defeat keeps claimed awakening")
	scene.queue_free()
	paused = false
	await process_frame
	var revisit = fresh_scene()
	await process_frame
	garden_clear(revisit)
	revisit.player.health = 10.0
	check(revisit.temple_section.claim_garden_reward() and is_equal_approx(revisit.player.health, 30.0), "revisit reward heals 20 percent")
	check(not revisit.temple_section.claim_garden_reward() and is_equal_approx(revisit.player.health, 30.0), "revisit healing is once per run")
	revisit.temple_section.leave_garden()
	revisit.run_time = 300.0
	revisit.teleport(revisit.temple_section.RETRY_POINT)
	revisit.temple_section.tick(0.0)
	revisit.temple_section.tick(1.3)
	revisit.boss.take_hit(10000.0, Vector2.RIGHT, false)
	revisit.player.health = 0.0
	revisit.death_pending = true
	revisit._physics_process(0.0)
	check(revisit.end_result == "SUCCESS" and not revisit.temple_section.retry_pending, "simultaneous boss/player death keeps success priority")
	revisit.queue_free()
	paused = false
	await process_frame
	for decline in [false, true]:
		var end_scene = fresh_scene()
		await process_frame
		if decline:
			end_scene.run_time = 300.0
			end_scene.teleport(end_scene.temple_section.RETRY_POINT)
			end_scene.temple_section.tick(0.0)
			end_scene.temple_section.tick(1.3)
		end_scene.player.health = 0
		end_scene.death_pending = true
		end_scene._physics_process(0.0)
		if decline:
			check(end_scene.temple_section.retry_pending, "boss death offers choice before declining")
			end_scene.temple_section.decline_retry()
		check(end_scene.run_ended and end_scene.end_result == "DEFEAT", "decline or ordinary death settles defeat")
		end_scene.queue_free()
		paused = false
		await process_frame
	print("Temple section: ", failures, " failures")
	quit(1 if failures else 0)
