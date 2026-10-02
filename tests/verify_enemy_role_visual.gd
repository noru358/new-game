extends SceneTree
## Posed render fixtures; not live input, human art acceptance, or balance evidence.
## ENEMY_ROLE_CAPTURE_DIR optionally saves actual GL frames at both target sizes.

const RoleVisual = preload("res://game/enemy_role_visual.gd")
const OriginalTexture = preload("res://game/hybrid_actor.svg")
var failures := 0
var checks := 0
var capture_dir := ""
var normal_saves: Dictionary = {}
const ROLE_NAMES := ["fragment", "beast", "lamp", "zone", "support"]

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
	_check(not RoleVisual.supports(-1) and not RoleVisual.supports(5), "hero and unknown roles keep the fallback render path")
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
				_check(body.texture != OriginalTexture and body.has_meta("enemy_role_body"), "authored role body replaces the ordinary hero clone")
				_check(visual.get_child_count() == 3, "role silhouette does not need the former floating role orb")
				_check(body.texture.get_image().get_used_rect().size.x * body.pixel_size <= enemy.collision_radius * 0.02 + 0.01, "visible role width fits the existing hitbox diameter")
				_verify_pose(scene, enemy, body)
			else:
				_check(body.texture == OriginalTexture and not body.has_meta("enemy_role_body") and visual.get_child_count() == 4, "unsupported roles keep the fallback texture and marker")
		_verify_silhouettes(scene, spawned)
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
	_check(body.position == Vector3.UP * RoleVisual.GROUND_CLEARANCE and is_equal_approx(body.offset.y, 34.0), "billboard feet clear the painted terrain while shadow stays grounded")
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
		_check(is_equal_approx(body.scale.y, 0.84) and body.position == Vector3.UP * RoleVisual.GROUND_CLEARANCE and body.offset.y == 34.0, "charge pose retains ground clearance")
		enemy.charge_time = 0.0
	if enemy.role == TrainingEnemy.Role.LAMP:
		enemy.locked_direction = Vector2(-1, 0)
		enemy.warning_time = TrainingEnemy.LAMP_WARNING * 0.10
		scene._process(0)
		_check(body.flip_h and body.scale.y > 1.0 and scene.warning_vertex_count > 0, "lamp braces toward its locked shot and preserves the ground warning")
		enemy.warning_time = 0.0
		enemy._fire_bolt()
		var bolt: EnemyBolt = get_nodes_in_group("enemy_bolts").back()
		_check(bolt.global_position == enemy.global_position + enemy.locked_direction * 24.0 and bolt.direction == enemy.locked_direction, "bolt still originates at the existing actor offset and locked aim")
		scene._physics_process(0)
		scene._process(0)
		_check(not scene.shots.is_empty() and body.scale.y < 0.94, "real lamp fire creates the existing projectile and a grounded recoil")
		for shot in scene.shots:
			_check(not scene.shots[shot].material_override.no_depth_test, "original projectile material retains depth")
	if enemy.role == TrainingEnemy.Role.ZONE:
		var previous_position := enemy.global_position
		enemy.global_position = scene.player.global_position + Vector2(80, 0)
		enemy.attack_cooldown = 0.0
		enemy._zone_velocity(0)
		scene._process(0)
		_check(not get_nodes_in_group("enemy_zones").is_empty() and scene.warning_vertex_count > 0 and body.scale.y < 0.94, "real zone cast preserves its original ground warning and recoils after firing")
		enemy.global_position = previous_position
	if enemy.role in [TrainingEnemy.Role.LAMP, TrainingEnemy.Role.ZONE]:
		var fired := enemy.attacks_fired
		var cooldown := enemy.attack_cooldown
		scene._process(RoleVisual.FIRE_RECOIL)
		_check(body.scale == Vector3.ONE and enemy.attacks_fired == fired and enemy.attack_cooldown == cooldown, "recoil ends without changing attack or cooldown state")
	# Use the real damage path rather than directly assigning a flash flag.
	enemy.take_hit(1.0, Vector2.RIGHT, false)
	scene._process(0)
	_check(enemy.hit_flash > 0.0 and body.texture != ordinary, "actual damage produces a distinct pale flash texture")
	var base_image := ordinary.get_image()
	var flash_image := body.texture.get_image()
	var opaque_pixels := 0
	var brightness_gain := 0.0
	var alpha_preserved := true
	for y in base_image.get_height():
		for x in base_image.get_width():
			var base_pixel := base_image.get_pixel(x, y)
			var flash_pixel := flash_image.get_pixel(x, y)
			alpha_preserved = alpha_preserved and base_pixel.a == flash_pixel.a
			if base_pixel.a >= 0.9:
				opaque_pixels += 1
				brightness_gain += flash_pixel.get_luminance() - base_pixel.get_luminance()
	_check(alpha_preserved and brightness_gain / maxf(1.0, opaque_pixels) > 0.20, "actual hit clearly brightens the body while preserving every silhouette alpha")
	enemy.hit_flash = 0.0
	scene._process(0)
	_check(body.texture == ordinary and body.scale == Vector3.ONE, "hit/charge ends restore the ordinary body")
	_check(enemy.health == original_health - 1.0 and enemy.collision_radius == original_radius, "presentation update does not alter damage or hitbox")

func _verify_silhouettes(scene, enemies: Array[TrainingEnemy]) -> void:
	var masks: Array[PackedByteArray] = []
	for enemy in enemies:
		var body: Sprite3D = scene.actors[enemy].get_node("Body")
		_check(RoleVisual.supports(enemy.role), "all five existing ordinary roles have authored bodies")
		var image := body.texture.get_image()
		var used := image.get_used_rect()
		_check(used.end.y == int(RoleVisual.FOOT_Y) and image.get_pixel(image.get_width() / 2, 72).a == 0.0, "two separated feet meet the shared terrain anchor")
		# Normalize to one canvas so this checks silhouette, not texture width or color.
		var mask := PackedByteArray()
		for y in 80:
			for x in 80:
				var ix := x - (80 - image.get_width()) / 2
				mask.append(1 if ix >= 0 and ix < image.get_width() and image.get_pixel(ix, y).a > 0.5 else 0)
		for other in masks: _check(mask != other, "every role has a distinct silhouette at identical ground scale")
		masks.append(mask)

func _capture_poses(scene, enemies: Array[TrainingEnemy], label: String) -> void:
	# All five bodies appear together. Lamp line and zone circle use their actual
	# existing effect nodes, not illustrations baked into the authored texture.
	for size in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = size
		root.content_scale_size = Vector2i(1280, 720)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		for pose in ["walk", "warning", "hit"]:
			for enemy in enemies:
				enemy.velocity = Vector2(100, 0) if pose == "walk" else Vector2.ZERO
				enemy.locked_direction = enemy.position.direction_to(scene.player.position)
				enemy.warning_time = 0.15 if pose == "warning" and enemy.role in [TrainingEnemy.Role.BEAST, TrainingEnemy.Role.LAMP] else 0.0
				enemy.hit_flash = 0.10 if pose == "hit" else 0.0
			for i in 30:
				scene._process(1.0 / 60.0)
				await process_frame
			await _capture("%s-%s-%dx%d" % [label, pose, size.x, size.y])
		for enemy in enemies: enemy.hit_flash = 0.0
	# Close spacing stresses overlaps between different silhouettes and warnings.
	var extras: Array[TrainingEnemy] = []
	for offset in [Vector2(-70, -70), Vector2(0, -100), Vector2(70, -90), Vector2(40, 90), Vector2(-80, 80), Vector2(135, 65), Vector2(-160, 40), Vector2(175, -60)]:
		var role := extras.size() % 5
		var enemy: TrainingEnemy = scene._spawn_enemy_at(scene.start_point + offset, role, TrainingEnemy.Definitions.ROLES[role].health)
		enemy.set_physics_process(false)
		enemy.locked_direction = enemy.position.direction_to(scene.player.position)
		enemy.warning_time = 0.20 if role in [TrainingEnemy.Role.BEAST, TrainingEnemy.Role.LAMP] else 0.0
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
