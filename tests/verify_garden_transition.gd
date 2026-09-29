extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)
func _run() -> void:
	var scene = load("res://game/hybrid_region.tscn").instantiate()
	scene.profile_save_prefix = "user://verify_garden_transition_profile"
	scene.growth_save_prefix = "user://verify_garden_transition_growth"
	for prefix in [scene.profile_save_prefix, scene.growth_save_prefix]:
		for suffix in ["_a.json", "_b.json"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(prefix + suffix))
	root.add_child(scene)
	await process_frame
	var section = scene.temple_section
	var outside = scene._spawn_enemy_at(Vector2(2950, 450), TrainingEnemy.Role.FRAGMENT, 22.0)
	var run_id: String = scene.run_id
	scene.player.health = 51
	scene.run_currency = 17
	scene.supply_ready = false
	scene.run_time = 299.0
	scene.teleport(section.Garden.ENTRY_TRIGGER.get_center())
	scene._physics_process(0.0)
	check(section.in_garden and scene.player.position == section.Garden.FIELD_ENTRY, "walking into hidden entrance enters mini field")
	check(scene.display_bounds() == section.GARDEN_AREA and scene.garden_terrain_mesh.visible and not scene.terrain_mesh.visible, "map and visible terrain switch together")
	check(outside.process_mode == Node.PROCESS_MODE_DISABLED and not outside.is_in_group("training_enemies"), "outside actors cannot move or become wisp targets")
	check(scene.run_id == run_id and scene.player.health == 51 and scene.run_currency == 17 and not scene.supply_ready, "transition preserves run health currency and spent supply")
	scene._physics_process(1.1)
	scene._physics_process(1.3)
	check(scene.run_time > 300 and scene.boss_spawned and not scene.boss.encounter_active, "main clock continues and boss waits while exploring")
	check(scene._spawn_rate() == 0.0, "garden contains only its fixed guardians")
	var guardian: TrainingEnemy
	for actor in scene.actors:
		if actor is TrainingEnemy and section.GARDEN_AREA.has_point(actor.position): guardian = actor
	check(guardian != null, "entry guardian appears with a warning")
	if guardian != null:
		guardian.take_hit(7.0, Vector2.RIGHT, false)
		var hp := guardian.health
		section.portal_cooldown = 0.0
		scene.teleport(section.Garden.EXIT_TRIGGER.get_center())
		section.tick(0.0)
		check(not section.in_garden and scene.player.position == section.Garden.RETURN_POINT, "exit returns to original corridor")
		check(outside.process_mode != Node.PROCESS_MODE_DISABLED and outside.is_in_group("training_enemies") and guardian.process_mode == Node.PROCESS_MODE_DISABLED, "active field actors restore without duplication")
		section.enter_garden()
		check(guardian.health == hp and guardian.process_mode != Node.PROCESS_MODE_DISABLED, "reentry preserves guardian damage")
		check(not section.claim_garden_reward(), "entering field cannot skip guardian objective")
	scene.queue_free()
	paused = false
	await process_frame
	print("Garden transitions: ", failures, " failures")
	quit(1 if failures else 0)
