extends SceneTree
var failures := 0
var scene
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)
func _release() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(action)
func _walk_threshold(inside: bool) -> void:
	var section = scene.temple_section
	var trigger: Rect2 = section.layout.ENTRY_TRIGGER if inside else section.layout.EXIT_TRIGGER
	for frame in 300:
		_release()
		var movement: Vector2 = scene.player.position.direction_to(trigger.get_center()).rotated(-scene.player.input_rotation)
		if movement.x < -0.1: Input.action_press("move_left", -movement.x)
		if movement.x > 0.1: Input.action_press("move_right", movement.x)
		if movement.y < -0.1: Input.action_press("move_up", -movement.y)
		if movement.y > 0.1: Input.action_press("move_down", movement.y)
		await physics_frame
		section.tick(1.0 / 60.0)
		if section.in_garden == inside:
			_release()
			return
	_release()
	check(false, "normal-speed threshold approach timed out")
func _run() -> void:
	scene = load("res://game/hybrid_region.tscn").instantiate()
	scene.profile_save_prefix = "user://verify_garden_transition_profile"
	scene.growth_save_prefix = "user://verify_garden_transition_growth"
	for prefix in [scene.profile_save_prefix, scene.growth_save_prefix]:
		for suffix in ["_a.json", "_b.json"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(prefix + suffix))
	root.add_child(scene)
	await process_frame
	# Keep real player physics; drive the clock explicitly and freeze combat pressure.
	scene.set_physics_process(false)
	scene.wisp.set_physics_process(false)
	var section = scene.temple_section
	var outside = scene._spawn_enemy_at(Vector2(2950, 450), TrainingEnemy.Role.FRAGMENT, 22.0)
	outside.set_physics_process(false)
	var run_id: String = scene.run_id
	scene.player.health = 51
	scene.run_currency = 17
	scene.supply_ready = false
	scene.run_time = 299.0
	scene.teleport(section.Garden.RETURN_POINT)
	await _walk_threshold(true)
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
		guardian.set_physics_process(false)
		guardian.take_hit(7.0, Vector2.RIGHT, false)
		var hp := guardian.health
		section.tick(0.0)
		check(section.in_garden, "released arrival input does not trigger a return")
		var actor_count: int = scene.actors.size()
		await _walk_threshold(false)
		check(not section.in_garden and scene.player.position == section.Garden.RETURN_POINT, "exit returns to original corridor")
		check(outside.process_mode != Node.PROCESS_MODE_DISABLED and outside.is_in_group("training_enemies") and guardian.process_mode == Node.PROCESS_MODE_DISABLED, "active field actors restore without duplication")
		await _walk_threshold(true)
		check(guardian.health == hp and guardian.process_mode != Node.PROCESS_MODE_DISABLED, "reentry preserves guardian damage")
		check(scene.actors.size() == actor_count, "normal exit and reentry do not duplicate actors")
		check(not section.claim_garden_reward(), "entering field cannot skip guardian objective")
	scene.queue_free()
	paused = false
	await process_frame
	print("Garden transitions: ", failures, " failures")
	quit(1 if failures else 0)
