extends SceneTree
## Native OpenGL observation of real scene/input; not a natural run or balance proof.

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", message)


func _run() -> void:
	var capture_dir := OS.get_environment("BOSS_LIVE_CAPTURE_DIR")
	if capture_dir.is_empty():
		printerr("FAIL: BOSS_LIVE_CAPTURE_DIR is required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	root.size = Vector2i(1280, 720)
	for jungle in [false, true]:
		var region := "jungle" if jungle else "temple"
		var scene: Node3D = load("res://game/jungle_pass.tscn" if jungle else "res://game/hybrid_region.tscn").instantiate()
		scene.profile_save_prefix = "user://capture_boss_live_%s_profile" % region
		scene.growth_save_prefix = "user://capture_boss_live_%s_unlocks" % region
		root.add_child(scene)
		current_scene = scene
		for i in 5: await process_frame
		scene.set_physics_process(false)
		var section: Node = scene.temple_section
		scene.player.global_position = section.boss_area.position - Vector2(80, -section.boss_area.size.y * 0.5)
		scene.run_time = scene.BOSS_TIME
		section.tick(0.0)
		section.tick(1.3)
		_check(scene.boss_spawned, region + " boss spawned through the real section")
		var boss: GateBoss = scene.boss
		scene.player.max_health = 1000.0
		scene.player.health = 1000.0
		scene.teleport(boss.position + Vector2(0, 170))
		_check(scene.navigation.is_open(scene.player.global_position, scene.ACTOR_CLEARANCE), region + " live input starts on a navigable boss floor")
		section.tick(0.0)
		var start_position: Vector2 = scene.player.global_position
		var captured := false
		for frame in 300:
			Input.action_release("move_left")
			Input.action_release("move_up")
			if frame < 45: Input.action_press("move_up")
			elif frame < 90: Input.action_press("move_left")
			Input.action_press("attack")
			await physics_frame
			if not is_instance_valid(boss) or boss.is_queued_for_deletion(): break
			var area_warning: bool = boss.shock_warning > 0.25 or boss.ring_warning > 0.25 or boss is JungleWarden and (boss.sweep_warning > 0.25 or boss.gust_warning > 0.25)
			if not captured and frame > 15 and (boss.warning_time > 0.25 or area_warning):
				await process_frame
				if boss.warning_time <= 0.0 and not area_warning: continue
				scene._draw_boss_warning()
				print("BOSS_TELL region=", region, " sweep=", boss.sweep_warning if boss is JungleWarden else 0.0, " gust=", boss.gust_warning if boss is JungleWarden else 0.0, " shock=", boss.shock_warning, " charge=", boss.warning_time, " surfaces=", scene.boss_warning_mesh.get_surface_count(), " point=", boss.global_position)
				if area_warning: _check(scene.boss_warning_mesh.get_surface_count() > 0, region + " active area tell has rendered world geometry")
				await RenderingServer.frame_post_draw
				var image := root.get_texture().get_image()
				_check(not image.is_empty() and image.get_size() == Vector2i(1280, 720) and image.save_png(capture_dir.path_join(region + "-live-warning.png")) == OK, region + " native warning frame captured")
				captured = true
		Input.action_release("attack")
		Input.action_release("move_left")
		Input.action_release("move_up")
		_check(captured and scene.player.global_position.distance_to(start_position) > 20.0 and scene.player.attack_sequence > 0 and boss.attacks_fired > 0 and scene.wisp.shots_fired > 0, region + " live input, boss attack and companion fire continue in the rendered scene")
		print("BOSS_LIVE region=", region, " input_distance=", scene.player.global_position.distance_to(start_position), " attacks=", scene.player.attack_sequence, " boss_fired=", boss.attacks_fired, " wisp_shots=", scene.wisp.shots_fired)
		scene.queue_free()
		current_scene = null
		await process_frame
		for prefix in ["user://capture_boss_live_%s_profile" % region, "user://capture_boss_live_%s_unlocks" % region]:
			for suffix in ["_a.json", "_b.json"]:
				var path := ProjectSettings.globalize_path(prefix + suffix)
				if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("Boss live native: ", failures, " failures")
	quit(1 if failures else 0)
