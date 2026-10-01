extends SceneTree
## Presentation must retain the current playable temple and hidden-field contract.

var failures := 0

func _initialize() -> void: call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _frames(count: int) -> void:
	for i in count: await physics_frame

func _fresh(enabled: bool, suffix: String, path: String = "res://game/hybrid_region.tscn"):
	var scene = load(path).instantiate()
	scene.temple_environment_enabled = enabled
	scene.profile_save_prefix = "user://verify_temple_environment_profile_" + suffix
	scene.growth_save_prefix = "user://verify_temple_environment_unlocks_" + suffix
	root.add_child(scene)
	current_scene = scene
	return scene

func _run() -> void:
	var baseline = _fresh(false, "baseline")
	await _frames(3)
	var original_barriers: Array[Rect2] = baseline.terrain.barriers().duplicate()
	var original_camera: float = baseline.camera.size
	var original_speed: float = baseline.player.move_speed_multiplier
	var original_dash: float = baseline.player.dash_distance_multiplier
	_check(baseline.temple_environment_root == null, "startup baseline switch retains the original visual path")
	baseline.queue_free()
	await process_frame
	await process_frame
	var scene = _fresh(true, "kit")
	await _frames(3)
	_check(is_instance_valid(scene.temple_environment_root), "real temple scene mounts the representative kit")
	_check(scene.terrain.barriers() == original_barriers, "every original wall, water and terrain barrier is preserved")
	_check(scene.camera.size == original_camera and scene.player.move_speed_multiplier == original_speed and scene.player.dash_distance_multiplier == original_dash, "presentation preserves camera and locomotion")
	_check(scene.temple_environment_root.get_meta("replaced_wall_areas").size() == 4, "four existing wall visuals are replaced, not stacked over the original boxes")
	for point in [Vector2(3400, 710), Vector2(3400, 1380), Vector2(3900, 1120), scene.temple_section.RETRY_POINT, scene.temple_section.BOSS_POINT, scene.temple_section.Garden.ENTRY_TRIGGER.get_center()]:
		_check(scene.navigation.find_path(scene.start_point, point).size() > 1, "existing lane, destination or concealed-branch route stays connected: %s" % point)
	_check(scene.clear_attack(Vector2(3100, 710), Vector2(3700, 710)), "gallery lane still permits direct attacks")
	_check(not scene.clear_attack(Vector2(3180, 950), Vector2(3180, 1150)), "worked stone retains its original solid attack blocker")
	var threshold: MeshInstance3D = scene.temple_environment_root.get_node("RuinedSanctuaryThreshold")
	scene.teleport(Vector2(3980, 850))
	await process_frame
	await process_frame
	_check(threshold.material_override.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "complete far threshold fades when it covers the player")
	_check(scene.temple_environment_root.get_node("Masonry").material_override.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "other masonry stays solid during selective threshold fade")
	scene.teleport(Vector2(3900, 1120))
	await process_frame
	await process_frame
	_check(threshold.material_override.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "normal processional approach restores the threshold silhouette")
	_check(scene.navigation.is_open(Vector2(4038, 945), 30), "high broken corbel adds no ground obstacle beneath its overhang")
	var enemy = scene._spawn_enemy_at(Vector2(3980, 850), TrainingEnemy.Role.BEAST, 100.0)
	enemy.set_physics_process(false)
	enemy.warning_time = 0.55
	enemy.locked_direction = enemy.position.direction_to(scene.player.position)
	await process_frame
	await process_frame
	_check(threshold.material_override.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "visible enemy behind the threshold receives the same sight protection")
	_check(scene.warning_vertex_count > 0, "existing enemy attack telegraph remains present with the threshold faded")
	scene.temple_section._remove_actor(enemy)
	await process_frame
	await process_frame
	_check(threshold.material_override.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "enemy-only threshold fade restores after the actor leaves")
	# A defeated actor can be freed before the next dictionary cleanup tick.
	# Inspect validity before its type; the accelerated run exposed this case.
	var actor_count: int = scene.actors.size()
	var expired := TrainingEnemy.new()
	scene.actors[expired] = null
	expired.free()
	scene._update_temple_environment_visibility()
	scene.actors.erase(expired)
	_check(scene.actors.size() == actor_count, "visibility tolerates a freed actor pending normal cleanup")
	scene.spawn_credit = -100000.0
	scene.player.hurt_immunity = 1000.0
	scene.teleport(Vector2(3120, 710))
	for action in ["move_right", "move_down"]: Input.action_press(action)
	await _frames(90)
	for action in ["move_right", "move_down"]: Input.action_release(action)
	await _frames(2)
	_check(scene.player.position.x > 3580 and absf(scene.player.position.y - 710) < 10, "actual player walks the paved lane without a visual-only step or snag")
	for action in ["move_left", "move_up"]: Input.action_press(action)
	await _frames(90)
	for action in ["move_left", "move_up"]: Input.action_release(action)
	await _frames(2)
	_check(scene.player.position.x < 3190, "actual return travel remains reversible")
	scene.temple_section.enter_garden()
	await process_frame
	await process_frame
	_check(not scene.temple_environment_root.visible, "main-field kit hides during the separate garden visit")
	scene.temple_section.leave_garden()
	await process_frame
	await process_frame
	_check(scene.temple_environment_root.visible, "returning from the garden restores the corridor kit")
	scene.run_time = 300.0
	scene.teleport(Vector2(3900, 1120))
	scene.temple_section.tick(0.0)
	scene.temple_section.tick(1.3)
	_check(scene.boss_spawned and scene.boss.position == scene.temple_section.BOSS_POINT, "same five-minute destination boss can spawn beside the sample")
	scene.teleport(scene.temple_section.RETRY_POINT)
	scene.temple_section.tick(0.0)
	_check(scene.temple_section.boss_active, "existing sanctuary entry still engages the boss")
	print("Temple environment resource counts: ", scene.temple_environment_root.get_meta("resource_counts"))
	scene.queue_free()
	await process_frame
	await process_frame
	var jungle = _fresh(true, "jungle", "res://game/jungle_pass.tscn")
	await _frames(3)
	_check(jungle.temple_environment_root == null, "temple kit never appears in the inherited jungle scene")
	jungle.queue_free()
	await process_frame
	print("Temple environment verification: ", failures, " failures")
	quit(1 if failures else 0)
