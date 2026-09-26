extends SceneTree

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var prefix := "user://verify_1d_%d" % Time.get_ticks_usec()
	var store := UnlockProgress.new()
	store.save_prefix = prefix
	store.load_progress()
	_check(store.lifetime_levelups == 0 and not store.is_unlocked("S_WISP_COUNT"), "new unlock record starts empty")
	for i in range(6):
		store.add_levelup()
	_check(store.is_unlocked("S_WISP_COUNT") and store.is_unlocked("S_WISP_ORBIT") and store.is_unlocked("S_WISP_CHAIN"), "cumulative level milestones unlock cards")
	var restored := UnlockProgress.new()
	restored.save_prefix = prefix
	restored.load_progress()
	_check(restored.lifetime_levelups == 6, "unlock total persists across runs")
	var damaged := FileAccess.open(prefix + "_b.json", FileAccess.WRITE)
	damaged.store_string("{broken")
	damaged.close()
	restored.load_progress()
	_check(restored.lifetime_levelups == 5, "corrupt newest record falls back to previous valid slot")
	_cleanup_store(prefix)

	var scene: Node2D = load("res://game/view_prototype.tscn").instantiate()
	root.add_child(scene)
	await _frames(3)
	var player: SandboxPlayer = scene.get_node("Player")
	var growth: RunGrowth = scene.get_node("RunGrowth")
	var enemies: Node2D = scene.get_node("Enemies")
	growth.unlocks.save_prefix = prefix
	growth.unlocks.load_progress()
	player.hurt_immunity = 100.0
	for enemy in enemies.get_children():
		enemy.set_physics_process(false)
		enemy.global_position = Vector2(2200, 1250)
	var orb_enemy: TrainingEnemy = enemies.get_node("FragmentA")
	orb_enemy.global_position = player.global_position + Vector2(12, 0)
	orb_enemy.health = 1.0
	orb_enemy.take_hit(2.0, Vector2.RIGHT, false)
	await _frames(3)
	_check(growth.xp == 2, "defeated enemy grants XP immediately")
	growth.gain_xp(6)
	_check(growth.level == 2 and growth.pending_choices == 1 and growth.choosing and paused, "level-up pauses combat for card selection")
	_check(growth.current_choices.size() == 3 and _has_group(growth.current_choices, "BASIC") and _has_group(growth.current_choices, "AUTO"), "three choices include manual and auto options")
	_check(growth.current_choices.has("U_CHAIN"), "combo unlock is offered while locked")
	var paused_cooldown: float = scene.get_node("Wisp").fire_cooldown
	await _frames(8)
	_check(is_equal_approx(scene.get_node("Wisp").fire_cooldown, paused_cooldown), "level-up pause freezes automatic attack")
	scene._on_window_focus_exited()
	_check(growth.choosing and paused and not scene.pause_overlay.visible, "focus loss does not replace level-up selection")
	growth.current_choices = ["U_CHAIN"]
	player.health = 60.0
	_check(growth.choose_index(0), "first card can be selected")
	_check(is_equal_approx(player.health, 80.0), "normal level-up selection restores 20 percent health")
	_check(player.combo_limit() == 3 and not paused, "first chain rank unlocks third hit and resumes")
	growth.gain_xp(12)
	_check(growth.level == 3 and growth.unlocks.is_unlocked("S_WISP_COUNT"), "second cumulative level-up unlocks wisp count card")
	growth.current_choices = ["U_CHAIN"]
	growth.choose_index(0)
	_check(player.combo_limit() == 4, "second chain rank unlocks fourth hit")
	growth.apply_card("S_WISP_COUNT")
	growth.apply_card("S_WISP_COUNT")
	_check(growth.wisps.size() == 3, "count upgrades produce three companions")
	growth.apply_card("S_WISP_CADENCE")
	growth.apply_card("S_WISP_DAMAGE")
	_check(is_equal_approx(growth.wisps[0].attack_interval, 1.125) and is_equal_approx(growth.wisps[2].damage_multiplier, 1.2) and growth.wisps[1].power_rank == 1, "wisp cadence and damage apply to every companion")
	growth.apply_card("U_EDGE")
	growth.apply_card("U_TEMPO")
	growth.apply_card("U_REACH")
	growth.apply_card("U_STEP")
	_check(is_equal_approx(player.basic_damage_bonus, 0.15) and is_equal_approx(player.basic_speed_bonus, 0.12) and is_equal_approx(player.basic_reach_bonus, 0.15) and is_equal_approx(player.dash_cooldown_reduction, 0.15), "manual and dash upgrades remain separate")
	growth.unlocks.lifetime_levelups = 6
	growth.apply_card("S_WISP_ORBIT")
	growth.apply_card("S_WISP_CHAIN")
	growth.apply_card("S_SEAL")
	_check(growth.wisps[0].orbit_enabled and growth.wisps[1].chain_jumps == 1 and growth.seal != null, "orbit, chain, and auxiliary seal activate")
	await _frames(60)
	for i in range(growth.wisps.size()):
		for j in range(i + 1, growth.wisps.size()):
			_check(growth.wisps[i].global_position.distance_to(growth.wisps[j].global_position) > 90.0, "three orbiting wisps remain evenly spaced after late unlock")
	for companion in growth.wisps:
		companion.set_physics_process(false)
	growth.seal.set_physics_process(false)
	for enemy in enemies.get_children():
		if is_instance_valid(enemy):
			enemy.global_position = Vector2(2200, 1250)
	var primary: TrainingEnemy = enemies.get_node("FragmentE")
	var secondary: TrainingEnemy = enemies.get_node("FragmentF")
	primary.global_position = Vector2(1400, 690)
	secondary.global_position = Vector2(1490, 705)
	var projectile := WispProjectile.new()
	projectile.setup(growth.wisps[0].global_position.direction_to(primary.global_position), 620.0, 520.0, 6.5)
	projectile.chain_jumps = 1
	scene.add_child(projectile)
	projectile.global_position = growth.wisps[0].global_position
	await _frames(33)
	_check(primary.health < primary.max_health and secondary.health < secondary.max_health, "chain flame strikes nearby second enemy")
	var before := primary.health
	growth.wisps[0].global_position = primary.global_position + Vector2(-20, 0)
	growth.wisps[0].age = 100.0
	growth.wisps[0]._hit_nearby_enemies()
	_check(primary.health < before, "orbit contact adds damage without removing projectile")
	before = primary.health
	growth.seal.global_position = primary.global_position
	growth.seal._explode()
	_check(primary.health < before, "seal deals independent area damage")
	for enemy in enemies.get_children():
		if is_instance_valid(enemy):
			enemy.queue_free()
	await _frames(2)
	scene.remaining_enemies = 0
	scene._next_practice_wave()
	_check(enemies.get_child_count() == 8 and scene.remaining_enemies == 8 and growth.level == 3 and player.combo_limit() == 4, "N practice wave restores enemies while keeping run growth")
	for card_id in RunGrowth.CARDS:
		growth.card_ranks[card_id] = RunGrowth.CARDS[card_id].max
	player.health = 30.0
	growth.pending_choices = 2
	growth._start_choice()
	_check(growth.pending_choices == 0 and not growth.choosing and not paused and is_equal_approx(player.health, 70.0), "exhausted card pool converts each queued choice to 20% healing")
	scene.queue_free()
	await _frames(2)
	paused = false
	var next_run: Node2D = load("res://game/view_prototype.tscn").instantiate()
	root.add_child(next_run)
	await _frames(2)
	_check(next_run.get_node("Player").combo_limit() == 2 and next_run.get_node("RunGrowth").level == 1 and next_run.get_node("RunGrowth").wisps.size() == 1, "new run resets selected cards and wisp count")
	next_run.queue_free()
	await _frames(2)
	_cleanup_store(prefix)
	if failed:
		printerr("1D verification failed")
		quit(1)
	else:
		print("1D verification passed: XP, level-up, cards, combo, wisps, seal, chain, persistence, practice wave")
		quit(0)


func _has_group(cards: Array[String], group: String) -> bool:
	for card_id in cards:
		if RunGrowth.CARDS[card_id].group == group:
			return true
	return false


func _cleanup_store(prefix: String) -> void:
	for suffix in ["_a.json", "_b.json"]:
		var path := ProjectSettings.globalize_path(prefix + suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL: ", label)
