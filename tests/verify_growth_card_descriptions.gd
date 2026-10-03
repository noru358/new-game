extends SceneTree

# Synthetic text/runtime fixtures. Headless bounds are not visual acceptance.
var failures := 0
var checks := 0
var arena: Node2D
var player: SandboxPlayer
var growth: RunGrowth
var wisp: WispCompanion

func _initialize() -> void: call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _enemy(point: Vector2) -> TrainingEnemy:
	var enemy := TrainingEnemy.new()
	enemy.max_health = 1000.0
	enemy.position = point
	enemy.collision_layer = 2
	enemy.collision_mask = 0
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 17.0
	enemy.add_child(shape)
	arena.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy

func _damage(target: TrainingEnemy) -> float:
	player.hit_targets.clear()
	player.attack_step = 1
	player.attack_direction = Vector2.RIGHT
	var before := target.health
	player._hit_enemies(player._attack_spec(1))
	return before - target.health

func _verify_power() -> void:
	var target := _enemy(player.position + Vector2(60, 0))
	for trial in [false, true]:
		growth.damage_cap_trial_enabled = trial
		for power_rank in range(6):
			player.permanent_basic_damage_bonus = PermanentGrowthCatalog.bonus("POWER", power_rank)
			player.basic_damage_bonus = 0.0
			growth.card_ranks.erase("U_EDGE")
			for rank in range(1, growth.card_max_rank("U_EDGE") + 1):
				var before: float = _damage(target) / (SandboxPlayer.ATTACK_DAMAGE * player._attack_spec(1).multiplier)
				var text := growth.describe_card("U_EDGE", rank)
				growth.apply_card("U_EDGE")
				var after: float = _damage(target) / (SandboxPlayer.ATTACK_DAMAGE * player._attack_spec(1).multiplier)
				var values := text.split("\n")[1].split(" → ")
				_check(is_equal_approx(values[0].trim_suffix("%").to_float(), before * 100.0) and is_equal_approx(values[1].trim_suffix("%").to_float(), after * 100.0), "POWER %d / U_EDGE %d / trial %s text equals actual first-hit damage" % [power_rank, rank, trial])
				if power_rank in [3, 5] and rank <= 3:
					_check(values[0].contains(".5%") and values[1].contains(".5%"), "fractional permanent POWER is preserved")
				if power_rank in [0, 1, 2, 4] and rank <= 3:
					_check(not text.contains(".0%"), "integer damage percentages stay concise")
				target.health = target.max_health
	growth.damage_cap_trial_enabled = false
	target.free()

func _verify_companions() -> void:
	var first := _enemy(Vector2(330, 200))
	for rank in [1, 2]:
		growth.apply_card("S_WISP_ORBIT")
		var text := growth.describe_card("S_WISP_ORBIT", rank)
		_check(text.contains("마탄 발사 유지") and text.contains("회전 접촉 피해"), "each ORBIT rank says ordinary shots continue")
		wisp.fire_cooldown = 0.0
		var shots := wisp.shots_fired
		wisp._physics_process(0.0)
		_check(wisp.orbit_enabled and wisp.shots_fired == shots + 1, "ORBIT keeps ordinary cooldown-driven firing")
		_check(is_equal_approx(wisp.orbit_damage, 4.0 if rank == 1 else 7.0), "ORBIT contact value matches rank text")
	for shot in get_nodes_in_group("wisp_projectiles"): shot.free()
	# Real projectile ray hit, first isolated and then with one nearby other enemy.
	for other_present in [false, true]:
		var other: TrainingEnemy = _enemy(Vector2(400, 200)) if other_present else null
		for bonus in [0, 1]:
			growth.permanent_wisp_chain_bonus = bonus
			growth.card_ranks.erase("S_WISP_CHAIN")
			for rank in [1, 2]:
				growth.apply_card("S_WISP_CHAIN")
				var text := growth.describe_card("S_WISP_CHAIN", rank)
				_check(text == "마탄 명중 후 가까운 다른 적에게\n추가 연쇄 %d명 → %d명" % [rank - 1 + bonus, rank + bonus], "CHAIN describes hit prerequisite, OTHER nearby targets and additional count")
				var shot := WispProjectile.new()
				shot.setup(Vector2.RIGHT, 620.0, 520.0, 10.0)
				shot.chain_jumps = wisp.chain_jumps
				shot.position = first.position - Vector2(60, 0)
				arena.add_child(shot)
				shot.set_physics_process(false)
				first.health = 1000.0
				if other != null: other.health = 1000.0
				await physics_frame
				_check(first.health == 1000.0 and (other == null or other.health == 1000.0), "chain causes no damage before projectile hit")
				shot._physics_process(0.12)
				_check(is_equal_approx(first.health, 990.0), "isolated first target never receives repeat chain damage")
				if other != null: _check(is_equal_approx(other.health, 993.2), "one nearby OTHER enemy is hit once despite multiple jumps")
				await process_frame
		if other != null: other.free()
	first.free()

func _verify_layout() -> void:
	var destination := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): destination = argument.trim_prefix("--capture-dir=")
	if not destination.is_empty():
		_check(DisplayServer.get_name() != "headless", "requested captures require a real rendering display; headless cannot pass capture validation")
		if DisplayServer.get_name() == "headless": return
		DirAccess.make_dir_recursive_absolute(destination)
	player.set_combo_rank(2)
	player.permanent_basic_damage_bonus = PermanentGrowthCatalog.bonus("POWER", 5)
	growth.current_choices.assign(["U_EDGE", "S_WISP_ORBIT", "S_WISP_CHAIN"])
	growth.overlay.show()
	for resolution in [Vector2i(960, 540), Vector2i(1280, 720)]:
		root.size = resolution
		root.content_scale_size = Vector2i(1280, 720)
		for variant in [1, 2]:
			growth.card_ranks = {"U_EDGE": 2, "S_WISP_ORBIT": variant - 1, "S_WISP_CHAIN": variant - 1}
			growth._refresh_choices()
			for frame in 4: await process_frame
			for button in growth.choice_buttons:
				_check(button.get_minimum_size().y <= button.size.y and button.get_minimum_size().x <= button.size.x, "all three long descriptions fit existing card bounds at " + str(resolution))
				_check(button.size.is_equal_approx(Vector2(310, 245)) and button.get_global_rect().end.x <= 1280.0, "description does not expand the existing 310x245 card")
				_check(button.get_global_rect().end.y < growth.reroll_button.position.y, "description stays above reroll")
			if not destination.is_empty():
				await RenderingServer.frame_post_draw
				var capture := root.get_texture().get_image()
				_check(capture.get_size() == resolution and capture.save_png(destination.path_join("growth-card-copy-rank%d-%dx%d.png" % [variant, resolution.x, resolution.y])) == OK, "rendered image saved at requested dimensions")
	print("Layout checks are geometric only; rendered Korean glyphs, clipping and human readability require separate visual inspection.")

func _run() -> void:
	arena = Node2D.new()
	root.add_child(arena)
	player = SandboxPlayer.new()
	player.position = Vector2(200, 200)
	arena.add_child(player)
	player.set_physics_process(false)
	wisp = WispCompanion.new()
	wisp.player = player
	arena.add_child(wisp)
	wisp.set_physics_process(false)
	growth = RunGrowth.new()
	growth.player = player
	growth.arena = arena
	growth.wisps.append(wisp)
	growth.unlocks.save_prefix = "user://verify_growth_card_descriptions"
	arena.add_child(growth)
	growth.unlocks.lifetime_levelups = 6
	_check(not growth.choice_batch_trial_enabled and not growth.late_xp_slope_trial and not growth.damage_cap_trial_enabled and not growth.slash_chain_cap_trial_enabled, "all pacing/cap experiments remain opt-in")
	_verify_power()
	await _verify_companions()
	await _verify_layout()
	arena.queue_free()
	await process_frame
	print("Growth card descriptions: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
