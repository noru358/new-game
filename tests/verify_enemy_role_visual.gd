extends SceneTree
## Posed render fixtures; not live input, human art acceptance, or balance evidence.
## ENEMY_ROLE_CAPTURE_DIR optionally saves actual GL frames at both target sizes.

const RoleVisual = preload("res://game/enemy_role_visual.gd")
const OriginalTexture = preload("res://game/hybrid_actor.svg")
var failures := 0
var checks := 0
var capture_dir := ""
var normal_saves: Dictionary = {}

func _initialize() -> void: call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _save_bytes() -> Dictionary:
	var result: Dictionary = {}
	for prefix in ["user://loop_conquest_profile", "user://loop_conquest_1d_unlocks"]:
		for suffix in ["_a.json", "_b.json"]:
			var path: String = prefix + suffix
			result[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	return result

func _run() -> void:
	normal_saves = _save_bytes()
	capture_dir = OS.get_environment("ENEMY_ROLE_CAPTURE_DIR")
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	for jungle in [false, true]:
		var label := "jungle" if jungle else "temple"
		var scene = load("res://game/jungle_pass.tscn" if jungle else "res://game/hybrid_region.tscn").instantiate()
		scene.profile_save_prefix = "user://verify_enemy_role_profile_" + label + str(Time.get_ticks_usec())
		scene.growth_save_prefix = "user://verify_enemy_role_unlocks_" + label + str(Time.get_ticks_usec())
		root.add_child(scene)
		current_scene = scene
		for i in 3: await process_frame
		scene.set_physics_process(false)
		scene.set_process(false)
		scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
		var player_body: Sprite3D = scene.actors[scene.player].get_node("Body")
		_check(player_body.texture == OriginalTexture and not player_body.has_meta("enemy_role_body"), label + " keeps the original hero")
		for time in [0.0, 20.0, 44.99]:
			scene.run_time = time
			for i in 20:
				_check(scene._roll_role() == TrainingEnemy.Role.FRAGMENT, "opening schedule remains fragment-only before 45 seconds")
		scene.run_time = 0.0
		var spawned: Array[TrainingEnemy] = []
		var offsets := [Vector2(-100, 0), Vector2(110, -25), Vector2(-115, -155), Vector2(0, -190), Vector2(140, -165)]
		for role in 5:
			var enemy: TrainingEnemy = scene._spawn_enemy_at(scene.start_point + offsets[role], role, TrainingEnemy.Definitions.ROLES[role].health)
			enemy.set_physics_process(false)
			spawned.append(enemy)
			var visual: Node3D = scene.actors[enemy]
			var body: Sprite3D = visual.get_node("Body")
			_check(enemy.collision_radius == 30.0 and enemy.contact_margin == 3.0, "existing ordinary hitbox and contact margin preserved")
			_check(enemy.health == TrainingEnemy.Definitions.ROLES[role].health and enemy.xp_reward() == TrainingEnemy.Definitions.ROLES[role].xp and enemy.currency_reward() == TrainingEnemy.Definitions.ROLES[role].currency, "existing role stats and rewards preserved")
			_check(not body.no_depth_test and body.alpha_cut == SpriteBase3D.ALPHA_CUT_DISCARD, "ordinary bodies retain terrain depth")
			if RoleVisual.supports(role):
				_check(body.texture != OriginalTexture and body.has_meta("enemy_role_body"), "stone/horn body replaces the ordinary hero clone")
				_check(visual.get_child_count() == 3, "role silhouette does not need the former floating role orb")
				_check(body.texture.get_image().get_used_rect().size.x * body.pixel_size <= enemy.collision_radius * 0.02 + 0.01, "visible role width fits the existing hitbox diameter")
				_verify_pose(scene, enemy, body)
			else:
				_check(body.texture == OriginalTexture and not body.has_meta("enemy_role_body") and visual.get_child_count() == 4, "three remaining roles keep their previous texture and marker")
		# Fragments and beast have different silhouettes, not only a palette swap.
		_check(RoleVisual.FRAGMENT_TEXTURE.get_image().get_data() != RoleVisual.BEAST_TEXTURE.get_image().get_data() and RoleVisual.FRAGMENT_TEXTURE.get_width() != RoleVisual.BEAST_TEXTURE.get_width(), "two authored silhouettes are independent")
		if not capture_dir.is_empty(): await _capture_poses(scene, spawned, label)
		# Bosses still use their existing mesh figure with the unused old sprite hidden.
		scene._spawn_now(scene.temple_section.boss_point, TrainingEnemy.Role.BEAST, true)
		scene.boss.set_physics_process(false)
		var boss_visual: Node3D = scene.actors[scene.boss]
		var boss_body: Sprite3D = boss_visual.get_node("Body")
		scene._process(0)
		_check(not boss_body.visible and boss_body.texture == OriginalTexture and not boss_body.has_meta("enemy_role_body") and boss_visual.has_node("BossFigure"), "boss figure bypasses ordinary role visuals")
		scene.queue_free()
		await process_frame
		await process_frame
	_check(_save_bytes() == normal_saves, "normal profile and unlock slot bytes/absence preserved")
	print("Enemy role visuals: ", checks, " checks, ", failures, " failures; posed fixtures only")
	quit(1 if failures else 0)

func _verify_pose(scene, enemy: TrainingEnemy, body: Sprite3D) -> void:
	var ordinary: Texture2D = body.texture
	var original_health := enemy.health
	var original_radius := enemy.collision_radius
	enemy.velocity = Vector2(-100, 0)
	scene._process(0.10)
	_check(body.flip_h and body.scale.y < 1.0, "moving stone turns toward screen-left and shows a small grounded stride")
	_check(body.position == Vector3.ZERO and is_equal_approx(body.offset.y, 34.0), "billboard pixel anchor stays at the terrain sample")
	enemy.velocity = Vector2(100, 0)
	scene._process(0.10)
	_check(not body.flip_h, "moving stone turns toward screen-right")
	enemy.velocity = Vector2.ZERO
	scene._process(0)
	_check(body.scale == Vector3.ONE, "idle body restores its full silhouette")
	if enemy.role == TrainingEnemy.Role.BEAST:
		enemy.locked_direction = Vector2(-1, 0)
		enemy.warning_time = TrainingEnemy.BEAST_WARNING * 0.25
		scene._process(0)
		_check(body.flip_h and body.scale.y < 0.94 and scene.warning_vertex_count > 0, "warning crouch follows locked direction and retains actual ground telegraph")
		enemy.warning_time = 0.0
		enemy.charge_time = 0.2
		scene._process(0)
		_check(is_equal_approx(body.scale.y, 0.84) and body.position == Vector3.ZERO and body.offset.y == 34.0, "charge pose remains anchored")
		enemy.charge_time = 0.0
	# Use the real damage path rather than directly assigning a flash flag.
	enemy.take_hit(1.0, Vector2.RIGHT, false)
	scene._process(0)
	_check(enemy.hit_flash > 0.0 and body.texture != ordinary, "actual damage produces a distinct pale flash texture")
	var base_pixel := ordinary.get_image().get_pixel(32, 50)
	var flash_pixel := body.texture.get_image().get_pixel(32, 50)
	_check(flash_pixel.r > base_pixel.r + 0.20 and flash_pixel.a == base_pixel.a, "hit flash brightens authored color while preserving silhouette alpha")
	enemy.hit_flash = 0.0
	scene._process(0)
	_check(body.texture == ordinary and body.scale == Vector3.ONE, "hit/charge ends restore the ordinary body")
	_check(enemy.health == original_health - 1.0 and enemy.collision_radius == original_radius, "presentation update does not alter damage or hitbox")

func _capture_poses(scene, enemies: Array[TrainingEnemy], label: String) -> void:
	for i in range(2, 5): (scene.actors[enemies[i]] as Node3D).hide()
	var beast := enemies[1]
	var fragment := enemies[0]
	for size in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = size
		root.content_scale_size = Vector2i(1280, 720)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		for pose in ["walk", "warning", "charge", "hit"]:
			fragment.velocity = Vector2(100, 0) if pose == "walk" else Vector2.ZERO
			beast.velocity = Vector2(-100, 0) if pose == "walk" else Vector2.ZERO
			beast.locked_direction = beast.position.direction_to(scene.player.position)
			beast.warning_time = 0.15 if pose == "warning" else 0.0
			beast.charge_time = 0.20 if pose == "charge" else 0.0
			fragment.hit_flash = 0.10 if pose == "hit" else 0.0
			beast.hit_flash = fragment.hit_flash
			for i in 30:
				scene._process(1.0 / 60.0)
				await process_frame
			await _capture("%s-%s-%dx%d" % [label, pose, size.x, size.y])
		fragment.hit_flash = 0.0
		beast.hit_flash = 0.0
	# Deliberately posed close spacing stresses overlapping silhouettes/telegraphs.
	var extras: Array[TrainingEnemy] = []
	for offset in [Vector2(-70, -70), Vector2(0, -100), Vector2(70, -90), Vector2(40, 90), Vector2(-80, 80), Vector2(135, 65), Vector2(-160, 40), Vector2(175, -60)]:
		var role := TrainingEnemy.Role.BEAST if extras.size() % 3 == 0 else TrainingEnemy.Role.FRAGMENT
		var enemy: TrainingEnemy = scene._spawn_enemy_at(scene.start_point + offset, role, TrainingEnemy.Definitions.ROLES[role].health)
		enemy.set_physics_process(false)
		enemy.locked_direction = enemy.position.direction_to(scene.player.position)
		enemy.warning_time = 0.20 if role == TrainingEnemy.Role.BEAST else 0.0
		extras.append(enemy)
	scene.player.attack_step = 2
	scene.player.attack_elapsed = 0.1
	scene.current_attack_step = 2
	scene.previous_attack_step = 2
	scene.current_attack_elapsed = 0.1
	scene.previous_attack_elapsed = 0.1
	for size in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = size
		scene._process(0)
		await process_frame
		await _capture("%s-dense-attack-%dx%d" % [label, size.x, size.y])

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(image != null and not image.is_empty(), "actual GL output required for " + label)
	if image == null or image.is_empty(): return
	_check(image.save_png(capture_dir.path_join(label + ".png")) == OK, "save posed frame " + label)
	print("CAPTURE frozen fixture: ", label)
