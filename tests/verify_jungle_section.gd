extends SceneTree

const PROFILE := "user://verify_jungle_section_profile"
const UNLOCKS := "user://verify_jungle_section_unlocks"
var failures := 0

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)
func cleanup() -> void:
	for prefix in [PROFILE, UNLOCKS]:
		for suffix in ["_a.json", "_b.json"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(prefix + suffix))
func _run() -> void:
	cleanup()
	var seed := RunProfile.new()
	seed.save_prefix = PROFILE
	seed.currency = 100
	check(seed.settle("temple-seed", "SUCCESS", 0) and seed.settle("jungle-seed", "SUCCESS", 0, RunProfile.JUNGLE_REGION), "prepare both region unlocks")
	check(seed.buy_gear("W_ECHO") and seed.equip("W_ECHO"), "prepare echo weapon")
	var scene = load("res://game/jungle_pass.tscn").instantiate()
	scene.profile_save_prefix = PROFILE
	scene.growth_save_prefix = UNLOCKS
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	var section = scene.temple_section
	var layout = section.layout
	check(scene.navigation.find_path(scene.start_point, layout.ENTRY_TRIGGER.get_center()).size() > 1, "hidden entrance reachable")
	check(scene.navigation.find_path(layout.FIELD_ENTRY, layout.ALTAR).size() > 1, "stream route reaches inner ruins")
	for point in layout.FIRST_WAVE + layout.SECOND_WAVE:
		check(scene.navigation.is_open(point, 45.0) and scene.navigation.find_path(layout.FIELD_ENTRY, point).size() > 1, "every fixed defender has a walkable approach")
	check(scene.navigation.find_path(scene.start_point, layout.ALTAR).is_empty(), "no walkable shortcut between fields")
	check(scene.navigation.is_open(section.boss_point, 48) and scene.navigation.is_open(section.retry_point, 30), "boss/retry points clear actual obstacles")
	check(scene.navigation.find_path(scene.start_point, section.retry_point).size() > 1, "boss arena reachable through existing routes")
	check(scene.profile.discover_garden() and scene.profile.claim_garden_awakening(), "seed temple progress")
	var hp: float = scene.player.health
	var run_id: String = scene.run_id
	var enemy = scene._spawn_enemy_at(Vector2(900, 1200), TrainingEnemy.Role.FRAGMENT, 22)
	section.enter_garden()
	section.tick(0.0)
	check(scene.is_place_discovered("JUNGLE_GROTTO") and scene.display_bounds() == layout.FIELD_BOUNDS, "grotto discovery and map bounds")
	check(enemy.process_mode == Node.PROCESS_MODE_DISABLED and not enemy.is_in_group("training_enemies"), "main field enemy inactive inside grotto")
	check(not section.claim_garden_reward(), "entry cannot claim hidden reward")
	for point in layout.FIRST_WAVE:
		scene.teleport(point + Vector2(0, 190))
		section.tick(1.0)
	for actor in scene.actors.keys():
		if is_instance_valid(actor) and actor is TrainingEnemy and not actor is GateBoss and section.field_area.has_point(actor.global_position):
			actor.take_hit(10000.0, Vector2.RIGHT, false)
	while scene.growth.choosing: scene.growth.choose_index(0)
	check(section.wave_kills == 3 and not section.claim_garden_reward(), "first group clear still locks reward")
	for point in layout.SECOND_WAVE:
		scene.teleport(point + Vector2(0, 190))
		section.tick(1.0)
	for actor in scene.actors.keys():
		if is_instance_valid(actor) and actor is TrainingEnemy and not actor is GateBoss and section.field_area.has_point(actor.global_position):
			actor.take_hit(10000.0, Vector2.RIGHT, false)
	while scene.growth.choosing: scene.growth.choose_index(0)
	check(section.wave_kills == 6 and section.guardian_reservations == 0, "two distinct groups cleared")
	scene.teleport(layout.ALTAR)
	var prefix: String = scene.profile.save_prefix
	scene.profile.save_prefix = "user://missing_v22_directory/profile"
	check(not section.claim_garden_reward() and not section.garden_claimed, "failed save never grants awakening")
	scene.profile.save_prefix = prefix
	check(section.claim_garden_reward() and not section.claim_garden_reward(), "first claim grants once")
	check(paused and scene.awakening_overlay.visible, "first permanent reward gives a readable paused receipt")
	scene._close_awakening_receipt()
	check(scene.grotto_awakening_applied and scene.profile.awakenings.has("ECHO_GROTTO"), "equipped weapon awakens immediately")
	check(section.garden_claimed, "first claim marks only this run")
	var dummy = scene._spawn_enemy_at(layout.ALTAR + Vector2(90, 0), TrainingEnemy.Role.BEAST, 100.0)
	scene.player.echo_finisher_center = layout.ALTAR
	scene.player.attack_sequence = 121
	scene._on_player_attack_landed(layout.ALTAR, Vector2.RIGHT, 4, true)
	scene._on_player_attack_landed(layout.ALTAR, Vector2.RIGHT, 4, true)
	check(scene.echo_grotto_blasts.size() == 1, "one delayed blast per fourth attack even with several targets")
	scene._tick_grotto_blasts(0.24)
	check(dummy.health == 100.0, "secondary blast waits")
	scene._tick_grotto_blasts(0.02)
	check(dummy.health < 100.0 and scene.echo_grotto_blasts.is_empty(), "secondary blast damages in radius")
	dummy.queue_free()
	var saved := RunProfile.new()
	saved.save_prefix = PROFILE
	saved.load_state()
	check(not saved.load_error and saved.discovered_places.size() == 2 and saved.awakenings.has("EMBER_GARDEN") and saved.awakenings.has("ECHO_GROTTO"), "both discoveries and awakenings reload")
	var malformed := saved._snapshot()
	malformed.awakenings = ["ECHO_GROTTO", "ECHO_GROTTO"]
	var invalid_path := PROFILE + "_invalid.json"
	var invalid_file := FileAccess.open(invalid_path, FileAccess.WRITE)
	invalid_file.store_string(JSON.stringify(malformed))
	invalid_file.close()
	check(saved._read(invalid_path).is_empty(), "duplicate awakening IDs are rejected")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(invalid_path))
	scene.run_time = 300.0
	section.tick(0.0)
	section.tick(1.3)
	check(scene.boss_spawned and not section.boss_active, "boss waits while player explores hidden field")
	section.leave_garden()
	check(scene.echo_grotto_blasts.is_empty(), "field transition clears delayed blast")
	check(scene.player.health == hp and scene.run_id == run_id and scene.run_time == 300.0, "field return preserves run state")
	check(enemy.process_mode != Node.PROCESS_MODE_DISABLED and enemy.is_in_group("training_enemies"), "main enemies resume on return")
	scene.teleport(section.retry_point)
	section.tick(0.0)
	var health: float = scene.boss.health
	scene.boss.take_hit(30.0, Vector2.RIGHT, false)
	check(section.boss_active and scene.boss.health == health - 30.0, "entry enables damage")
	scene.teleport(Vector2(4250, 1100))
	section.tick(0.0)
	scene.boss.take_hit(30.0, Vector2.RIGHT, false)
	check(not section.boss_active and scene.boss.health == health - 30.0, "exit preserves HP and blocks damage")
	scene.teleport(section.retry_point)
	section.tick(0.0)
	scene.player.health = 0.0
	check(section.handle_death() and section.retry_pending, "first boss death offers retry")
	section.retry_boss()
	check(section.retry_used and scene.player.health == scene.player.max_health and scene.boss.health == scene.boss.max_health, "retry restores combatants")
	check(not section.handle_death(), "second death cannot retry")
	scene.queue_free()
	paused = false
	await process_frame
	var return_scene = load("res://game/jungle_pass.tscn").instantiate()
	return_scene.profile_save_prefix = PROFILE
	return_scene.growth_save_prefix = UNLOCKS
	root.add_child(return_scene)
	await process_frame
	return_scene.set_physics_process(false)
	check(return_scene.grotto_awakening_applied, "saved echo awakening applies on a later run")
	return_scene.temple_section.enter_garden()
	return_scene.temple_section.wave_kills = 6
	return_scene.teleport(return_scene.temple_section.layout.ALTAR)
	return_scene.player.health = 50.0
	check(return_scene.temple_section.claim_garden_reward(), "repeat clear grants one reward")
	check(return_scene.player.health == 70.0 and not return_scene.temple_section.claim_garden_reward(), "repeat reward heals 20 percent only once per run")
	return_scene.queue_free()
	await process_frame
	cleanup()
	print("Jungle section: %d failures" % failures)
	quit(1 if failures else 0)
