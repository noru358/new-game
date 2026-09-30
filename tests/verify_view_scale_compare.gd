extends SceneTree

const PROFILE_PREFIX := "user://verify_view_scale_compare_profile"
const UNLOCK_PREFIX := "user://verify_view_scale_compare_unlocks"
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _run() -> void:
	var scene = load("res://game/hybrid_region.tscn").instantiate()
	scene.profile_save_prefix = PROFILE_PREFIX
	scene.growth_save_prefix = UNLOCK_PREFIX
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
	var player_visual: Node3D = scene.actors[scene.player]
	_check(scene.view_compare_enabled and is_equal_approx(scene.camera.size, 8.4) and is_equal_approx(player_visual.get_node("Body").scale.x, 0.85), "live run starts in the temporary trial view")
	_check(is_equal_approx(scene.player.collision_radius, 30.0) and is_equal_approx(player_visual.get_node("Shadow").scale.x, 0.85), "trial changes the visual and keeps the combat collider")
	var spawn_point: Vector2 = scene._choose_spawn_point(false)
	_check(spawn_point != Vector2.INF, "comparison test finds a reachable enemy spawn")
	if spawn_point != Vector2.INF:
		var enemy: TrainingEnemy = scene._spawn_enemy_at(spawn_point, TrainingEnemy.Role.BEAST, 45.0)
		var enemy_visual: Node3D = scene.actors[enemy]
		_check(is_equal_approx(enemy_visual.get_node("Body").scale.x, 0.85) and is_equal_approx(enemy_visual.get_node("HealthBar").pixel_size, 0.0102) and is_equal_approx(enemy_visual.get_node("RoleMarker").scale.x, 0.85), "new enemies inherit the trial body, health bar and role marker scale")
		var toggle := InputEventKey.new()
		toggle.keycode = KEY_F6
		toggle.pressed = true
		scene._input(toggle)
		scene._process(0.016)
		_check(not scene.view_compare_enabled and is_equal_approx(scene.camera.size, 9.0) and player_visual.get_node("Body").scale == Vector3.ONE and enemy_visual.get_node("Body").scale == Vector3.ONE, "F6 restores the original camera and actor visuals")
		_check(is_equal_approx(enemy_visual.get_node("HealthBar").pixel_size, 0.012) and enemy_visual.get_node("RoleMarker").scale == Vector3.ONE and scene.view_compare_label.text.contains("원본 비율"), "F6 restores overhead visuals and identifies the mode")
		scene._input(toggle)
		scene._process(0.016)
		_check(scene.view_compare_enabled and is_equal_approx(scene.camera.size, 8.4) and is_equal_approx(enemy_visual.get_node("Body").scale.x, 0.85), "F6 switches back to the trial during the same run")
	scene.queue_free()
	await process_frame
	for prefix in [PROFILE_PREFIX, UNLOCK_PREFIX]:
		for suffix in ["_a.json", "_b.json"]:
			var path := ProjectSettings.globalize_path(prefix + suffix)
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	if failures == 0: print("View scale comparison passed: trial, F6 restoration, new enemy visuals and stable collision")
	quit(1 if failures else 0)
