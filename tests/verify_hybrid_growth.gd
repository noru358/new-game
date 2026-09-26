extends SceneTree

var failures := 0

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://game/hybrid_height.tscn").instantiate()
	scene.growth_save_prefix = "user://verify_hybrid_growth_temp"
	root.add_child(scene)
	await _frames(3)
	_check(scene.growth.unlocks.save_prefix != "user://loop_conquest_1d_unlocks", "lab growth keeps the main game's unlock save separate")
	for actor in scene.actors:
		if actor is TrainingEnemy:
			actor.set_physics_process(false)
	var enemy: TrainingEnemy
	for actor in scene.actors:
		if actor is TrainingEnemy:
			enemy = actor
			break
	enemy.position = Vector2(480, 1660)
	enemy.take_hit(100.0, Vector2.RIGHT, false)
	_check(scene.kills == 1 and scene.growth.xp == 2 and get_nodes_in_group("experience_orbs").is_empty(), "distant enemy defeat grants XP immediately without a pickup")
	scene.growth.gain_xp(6)
	_check(scene.growth.choosing and paused and scene.growth.current_choices.has("U_CHAIN"), "level-up pauses with a three-card choice including combo")
	var first_index: int = scene.growth.current_choices.find("U_CHAIN")
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_1 + first_index
	scene._input(key)
	_check(not scene.growth.choosing and not paused and scene.player.combo_limit() == 3, "number key selects the first combo rank and resumes")
	scene.growth.gain_xp(10)
	_check(scene.growth.choosing and scene.growth.unlocks.is_unlocked("S_WISP_COUNT"), "second level-up unlocks wisp division")
	scene.growth.choose_index(scene.growth.current_choices.find("U_CHAIN"))
	_check(scene.player.combo_limit() == 4, "second combo card grants four hits")
	scene.growth.apply_card("S_WISP_COUNT")
	await _frames(2)
	_check(scene.growth.wisps.size() == 2 and scene.wisp_visuals.size() == 2, "additional wisp gains a separate 3D visual")
	var extra: WispCompanion = scene.growth.wisps[1]
	_check(extra.target_visibility_filter.is_valid() and extra.follow_position_filter.is_valid(), "new wisp inherits camera and cliff filters")
	var left: Vector2 = scene.growth.wisps[0].formation_offset()
	var right: Vector2 = extra.formation_offset()
	_check(is_equal_approx(left.dot(scene.player.facing), right.dot(scene.player.facing)) and absf(left.dot(scene.player.facing.orthogonal()) + right.dot(scene.player.facing.orthogonal())) < 0.01, "two wisps balance around player facing")
	scene.player.facing = Vector2.UP
	left = scene.growth.wisps[0].formation_offset()
	right = extra.formation_offset()
	_check(is_equal_approx(left.dot(scene.player.facing), right.dot(scene.player.facing)) and absf(left.dot(scene.player.facing.orthogonal()) + right.dot(scene.player.facing.orthogonal())) < 0.01, "wisp pair rotates with player direction")
	scene.growth.apply_card("S_WISP_COUNT")
	_check(scene.growth.wisps.size() == 3 and scene.wisp_visuals.size() == 3, "third wisp completes the facing-based formation")
	scene.growth.unlocks.lifetime_levelups = 6
	scene.growth.apply_card("S_WISP_ORBIT")
	scene.growth.apply_card("S_WISP_CHAIN")
	_check(extra.orbit_enabled and extra.chain_jumps == 1, "orbit and chain upgrades propagate to the additional wisp")
	scene.growth.apply_card("S_WISP_DAMAGE")
	_check(extra.power_rank == 1 and scene.wisp_visuals[extra].material_override.albedo_color != Color("49dce8"), "wisp power visibly brightens the 3D body")
	scene.growth.apply_card("S_SEAL")
	_check(scene.growth.seal != null and scene.growth.seal.target_visibility_filter.is_valid(), "seal uses the 3D camera for target selection")
	scene.teleport(Vector2(600, 1700))
	var target: TrainingEnemy
	for actor in scene.actors:
		if actor is TrainingEnemy:
			target = actor
			break
	target.position = scene.player.position + Vector2(70, 0)
	_check(scene.growth.seal._find_target() == target, "seal selects an on-camera, reachable enemy in hidden 2D simulation")
	scene.growth.seal.position = target.position
	scene.growth.seal.telegraph = 0.3
	scene._process(0.0)
	scene._draw_enemy_warnings(1.0)
	_check(scene.warning_mesh.get_surface_count() > 0 and scene.seal_visual.visible and not scene.warning_visual.material_override.no_depth_test, "airborne seal warning and focus are depth-tested")
	var vertices: PackedVector3Array = scene.warning_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var flat := true
	for vertex in vertices:
		if absf(vertex.y - vertices[0].y) > 0.001:
			flat = false
	_check(flat, "seal ring remains in one air plane across changing terrain")
	var health_before: float = target.health
	scene.growth.seal._explode()
	_check(target.health < health_before, "3D-presented seal retains the real 2D area hit")
	scene.queue_free()
	await _frames(2)
	for suffix in ["_a.json", "_b.json"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://verify_hybrid_growth_temp" + suffix))
	if failures == 0:
		print("Hybrid growth verification passed: automatic XP, cards, combo, facing wisps and airborne seal")
	quit(1 if failures else 0)
