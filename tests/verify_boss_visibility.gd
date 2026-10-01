extends SceneTree
## Frozen presentation fixtures, not live combat or balance evidence.
## Optional BOSS_VISIBILITY_CAPTURE_DIR writes matched actual GL before/after
## images. A normal headless verification run never requests a screenshot.

var failures := 0
var capture_dir := ""

func _initialize() -> void: call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _run() -> void:
	capture_dir = OS.get_environment("BOSS_VISIBILITY_CAPTURE_DIR")
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	for jungle in [false, true]:
		var scene = load("res://game/jungle_pass.tscn" if jungle else "res://game/hybrid_region.tscn").instantiate()
		var region := "jungle" if jungle else "temple"
		scene.profile_save_prefix = "user://verify_boss_visibility_profile_" + region
		scene.growth_save_prefix = "user://verify_boss_visibility_unlocks_" + region
		root.add_child(scene)
		current_scene = scene
		for i in 5: await process_frame
		scene.set_physics_process(false)
		scene.set_process(false)
		scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
		scene._spawn_now(scene.temple_section.boss_point, TrainingEnemy.Role.BEAST, true)
		var boss: GateBoss = scene.boss
		boss.set_physics_process(false)
		boss.phase = 2
		boss.locked_direction = Vector2.ONE.normalized()
		var body: Sprite3D = scene.actors[scene.player].get_node("Body")
		var boss_visual: Node3D = scene.actors[boss]
		var figure: Node3D = boss_visual.get_node("BossFigure")
		var mesh: MeshInstance3D = figure.get_node("BossCore")
		var original_material: Material = mesh.material_override
		for size in [Vector2i(1280, 720), Vector2i(960, 540)]:
			root.size = size
			root.content_scale_size = Vector2i(1280, 720)
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
			await process_frame
			await process_frame
			for sample in [
				{"name": "rear-counter", "offset": Vector2(-60, -60), "covered": true, "warning": false},
				{"name": "front-counter", "offset": Vector2(90, 90), "covered": false, "warning": false},
				{"name": "side-counter", "offset": Vector2(125, -125), "covered": false, "warning": false},
				{"name": "rear-warning", "offset": Vector2(-60, -60), "covered": true, "warning": true},
			]:
				_set_pose(scene, sample.offset, sample.warning)
				_check(body.no_depth_test == sample.covered, "%s %s %s selects depth only for real overlap" % [region, size, sample.name])
				_check(mesh.material_override == original_material and mesh.material_override.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "boss silhouette retains its original opaque material")
				if sample.warning:
					_check(scene.boss_warning_mesh.get_surface_count() > 0, "actual boss warning geometry remains present")
				if not capture_dir.is_empty():
					await _capture_pair(scene, body, "%s-%s-%dx%d" % [region, sample.name, size.x, size.y])
			_verify_restoration(scene, body, boss_visual, figure)
		# Real field transitions hide the same boss visual and restore its depth.
		_set_pose(scene, Vector2(-60, -60))
		scene.temple_section._set_field(true)
		scene._process(0)
		_check(not body.no_depth_test and not boss_visual.visible, "garden entry clears foreground player rendering")
		scene.temple_section._set_field(false)
		_set_pose(scene, Vector2(-60, -60))
		_check(body.no_depth_test and boss_visual.visible, "returning to the same overlap restores sight protection")
		if jungle:
			for point in [Vector2(4250, 1100), Vector2(4520, 1160), Vector2(4740, 1400)]:
				_check(scene.navigation.is_open(point, scene.ACTOR_CLEARANCE) and scene.navigation.find_path(scene.start_point, point).size() > 1, "live inspection route reaches " + str(point))
		boss.queue_free()
		scene._update_player_boss_visibility()
		_check(not body.no_depth_test, "queued boss cannot leave a foreground player")
		await process_frame
		scene._update_player_boss_visibility()
		_check(not body.no_depth_test and body.alpha_cut == SpriteBase3D.ALPHA_CUT_DISCARD, "freed boss reference restores without a typed access error")
		scene.queue_free()
		await process_frame
		await process_frame
	print("Boss/player visibility: ", failures, " failures")
	quit(1 if failures else 0)

func _set_pose(scene, offset: Vector2, warning: bool = false) -> void:
	var boss: GateBoss = scene.boss
	boss.warning_time = 0
	boss.shock_warning = 0
	boss.ring_warning = 0
	boss.hit_flash = 0
	boss.counter_flash = 0.15 if not warning else 0.0
	boss.recovery_time = 0.55 if not warning else 0.0
	if boss is JungleWarden:
		boss.sweep_warning = 0
		boss.gust_warning = 0.55 if warning else 0.0
		boss.warning_duration = JungleWarden.GUST_WARNING
	else:
		boss.ring_warning = 0.55 if warning else 0.0
	scene.teleport(boss.position + offset)
	scene.player.facing = -offset.normalized()
	scene.player.attack_direction = scene.player.facing
	scene.player.attack_step = 4 if not warning else 0
	scene.player.attack_elapsed = 0.10
	scene.current_attack_step = scene.player.attack_step
	scene.previous_attack_step = scene.player.attack_step
	scene.current_attack_elapsed = 0.10
	scene.previous_attack_elapsed = 0.10
	scene.current_attack_direction = scene.player.facing
	scene.previous_attack_direction = scene.player.facing
	scene.actor_motion[boss] = [boss.position, boss.position]
	scene._process(0)

func _verify_restoration(scene, body: Sprite3D, boss_visual: Node3D, figure: Node3D) -> void:
	_set_pose(scene, Vector2(-60, -60))
	var posed_rotation := body.rotation
	var posed_facing := body.flip_h
	var posed_color := body.modulate
	scene._update_player_boss_visibility()
	_check(body.rotation == posed_rotation and body.flip_h == posed_facing and body.modulate == posed_color, "sight protection preserves the real player pose, facing and color")
	var player_sprites: Array[Node] = scene.actors[scene.player].find_children("*", "Sprite3D", true, false)
	_check(player_sprites.size() == 1 and player_sprites[0] == body, "occlusion reuses exactly the original player sprite without a twin")
	for target in [body, scene.actors[scene.player], boss_visual, figure]:
		target.hide()
		scene._update_player_boss_visibility()
		_check(not body.no_depth_test, "hidden player/boss cannot keep foreground rendering")
		target.show()
		scene._update_player_boss_visibility()
		_check(body.no_depth_test, "visible overlap reactivates after hidden-node restoration")
	var meshes := figure.find_children("*", "MeshInstance3D", true, false)
	for item in meshes: item.hide()
	scene._update_player_boss_visibility()
	_check(not body.no_depth_test, "health bar and empty boss root do not count as occluding geometry")
	for item in meshes: item.show()
	scene._update_player_boss_visibility()
	scene.player.health = 0
	scene._update_player_boss_visibility()
	_check(not body.no_depth_test, "defeated player restores ordinary depth")
	scene.player.health = scene.player.max_health
	scene.boss.health = 0
	scene._update_player_boss_visibility()
	_check(not body.no_depth_test, "defeated boss restores ordinary depth")
	scene.boss.health = scene.boss.max_health
	var camera_transform: Transform3D = scene.camera.transform
	scene.camera.position += scene.camera.global_basis.x * 100
	scene._update_player_boss_visibility()
	_check(not body.no_depth_test, "offscreen player/boss cannot leave an overlay")
	scene.camera.transform = camera_transform
	scene.camera.position = body.global_position - scene.camera.global_basis.z * 20
	scene._update_player_boss_visibility()
	_check(not body.no_depth_test, "boss/player behind the camera cannot leave an overlay")
	scene.camera.transform = camera_transform
	_set_pose(scene, Vector2(90, 90))
	_check(not body.no_depth_test and body.render_priority == 0 and body.alpha_cut == SpriteBase3D.ALPHA_CUT_DISCARD, "front separation restores all original render flags")
	# Normal enemies keep their existing billboard depth path.
	var enemy = scene._spawn_enemy_at(scene.player.position + Vector2(10, 10), TrainingEnemy.Role.BEAST, 100)
	scene.actor_motion[enemy] = [enemy.position, enemy.position]
	scene._process(0)
	_check(not body.no_depth_test and not scene.actors[enemy].get_node("Body").no_depth_test, "ordinary enemy overlap does not acquire boss sight behavior")
	scene.temple_section._remove_actor(enemy)

func _capture_pair(scene, body: Sprite3D, label: String) -> void:
	var obscured := body.no_depth_test
	for before in [true, false]:
		body.no_depth_test = false if before else obscured
		body.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD if before or not obscured else SpriteBase3D.ALPHA_CUT_DISABLED
		body.render_priority = 0 if before or not obscured else 1
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		if image == null or image.is_empty():
			_check(false, "captures require actual graphical rendering")
			return
		var path := capture_dir.path_join(label + ("-before.png" if before else "-after.png"))
		_check(image.save_png(path) == OK, "capture saves " + path)
		print("CAPTURE frozen fixture: ", path, " player=", scene.player.position, " boss=", scene.boss.position, " foreground=", body.no_depth_test)
