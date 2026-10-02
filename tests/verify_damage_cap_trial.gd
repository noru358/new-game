extends SceneTree

const PROFILE := "user://verify_damage_cap_trial_profile"
const UNLOCKS := "user://verify_damage_cap_trial_unlocks"
const DAMAGE_CARDS := ["U_EDGE", "S_WISP_DAMAGE"]
var failures := 0
var checks := 0
var report := {"scope": "isolated rank/candidate and earned-XP modal fixtures; not normal-run pacing or balance acceptance", "damage_only": true, "fixtures": []}


func _initialize() -> void: call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _cleanup() -> void:
	for prefix in [PROFILE, UNLOCKS]:
		for suffix in ["_a.json", "_b.json"]:
			var path := ProjectSettings.globalize_path(prefix + suffix)
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)


func _scene():
	_cleanup()
	var scene = load("res://game/hybrid_region.tscn").instantiate()
	scene.profile_save_prefix = PROFILE
	scene.growth_save_prefix = UNLOCKS
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
	scene.growth.unlocks.lifetime_levelups = 6
	return scene


func _verify_values() -> void:
	var scene = await _scene()
	var growth: RunGrowth = scene.growth
	var player: SandboxPlayer = scene.player
	_check(not growth.damage_cap_trial_enabled and not growth.choice_family_trial_enabled, "both comparison switches default independently off")
	var raw_capacity := 0
	for id in RunGrowth.CARDS: raw_capacity += growth.card_max_rank(id)
	_check(raw_capacity == 39 and raw_capacity - 2 - int(growth.card_ranks.U_STEP) == 35, "baseline raw 39 ranks mean 35 additional live-run selections")
	for rank in range(1, 4):
		growth.apply_card("U_EDGE")
		growth.apply_card("S_WISP_DAMAGE")
		_check(is_equal_approx(player.basic_damage_bonus, 0.15 * rank), "baseline direct damage ranks retain their exact formula")
		_check(is_equal_approx(growth.wisps[0].damage_multiplier, 1.0 + 0.20 * rank), "baseline companion damage ranks retain their exact formula")
		_check(growth.wisps[0].power_rank == rank, "baseline impact rank remains unchanged")
	_check(growth.describe_card("U_EDGE", 3).contains("130% → 145%") and growth.describe_card("S_WISP_DAMAGE", 3).contains("14.0 → 16.0"), "baseline third-rank previews remain exact")
	for id in DAMAGE_CARDS: growth.apply_card(id)
	_check(int(growth.card_ranks.U_EDGE) == 3 and int(growth.card_ranks.S_WISP_DAMAGE) == 3, "baseline still blocks a fourth application")
	for seed_value in 64:
		growth.rng.seed = seed_value
		for id in growth.roll_choices(): _check(id not in DAMAGE_CARDS, "baseline rank-three damage cards leave the offer pool")
	growth.damage_cap_trial_enabled = true
	_check(not growth.choice_family_trial_enabled, "cap trial does not enable the offer-family trial")
	var trial_capacity := 0
	for id in RunGrowth.CARDS:
		trial_capacity += growth.card_max_rank(id)
		_check(growth.card_max_rank(id) == int(RunGrowth.CARDS[id].max) + (1 if id in DAMAGE_CARDS else 0), "only the two selected damage caps change: " + id)
	_check(trial_capacity == 41 and trial_capacity - 2 - int(growth.card_ranks.U_STEP) == 37, "trial adds exactly two live-run selections")
	var offered := {}
	for seed_value in 64:
		growth.rng.seed = seed_value
		for id in growth.roll_choices(): offered[id] = true
	_check(offered.has("U_EDGE") and offered.has("S_WISP_DAMAGE"), "both earned fourth-rank options remain randomly offerable")
	_check(growth.describe_card("U_EDGE", 4).contains("145% → 152.5%") and growth.describe_card("S_WISP_DAMAGE", 4).contains("16.0 → 17.0"), "fourth-rank preview shows half-sized increments without integer rounding")
	for id in DAMAGE_CARDS: growth.apply_card(id)
	_check(is_equal_approx(player.basic_damage_bonus, 0.525) and is_equal_approx(growth.wisps[0].damage_multiplier, 1.7), "fourth rank adds +7.5 percentage points / +0.10 coefficient exactly once")
	for id in DAMAGE_CARDS: growth.apply_card(id)
	growth._sync_wisps()
	_check(int(growth.card_ranks.U_EDGE) == 4 and int(growth.card_ranks.S_WISP_DAMAGE) == 4 and is_equal_approx(player.basic_damage_bonus, 0.525) and is_equal_approx(growth.wisps[0].damage_multiplier, 1.7), "repeat application and recomputation cannot stack extra damage")
	_check(growth.wisps[0].power_rank == 3, "extra damage does not enlarge wisp impact, knockback or visuals")
	growth.apply_card("S_WISP_COUNT")
	_check(growth.wisps.size() == 2 and is_equal_approx(growth.wisps[1].damage_multiplier, 1.7) and growth.wisps[1].power_rank == 3, "a later companion inherits the same damage-only cap")
	for seed_value in 64:
		growth.rng.seed = seed_value
		for id in growth.roll_choices(): _check(id not in DAMAGE_CARDS, "rank-four cards leave the trial pool")
	scene.teleport(Vector2(2500, 1050))
	var target := TrainingEnemy.new()
	target.max_health = 1000.0
	target.health = 1000.0
	target.position = player.position + Vector2(65, 0)
	scene.simulation.add_child(target)
	target.set_physics_process(false)
	await physics_frame
	player.attack_path_filter = Callable()
	player.facing = Vector2.RIGHT
	player.next_combo_step = 1
	player._start_attack()
	player._hit_enemies(player._attack_spec(1))
	_check(is_equal_approx(target.health, 984.75), "actual first-hit damage is 15.25 at the fourth direct rank")
	var wisp: WispCompanion = growth.wisps[0]
	wisp.global_position = player.position - Vector2(30, 0)
	wisp._fire(target)
	var matching_shot := false
	for shot in get_nodes_in_group("wisp_projectiles"):
		if shot is WispProjectile and shot.target == target:
			matching_shot = true
			_check(is_equal_approx(shot.damage, 17.0) and shot.power_rank == 3, "actual projectile carries 17 damage and unchanged impact rank")
	_check(matching_shot, "live companion created a projectile for the test target")
	player.permanent_basic_damage_bonus = 0.30
	wisp.permanent_damage_bonus = 0.15
	_check(growth.describe_card("U_EDGE", 4).contains("175% → 182.5%") and growth.describe_card("S_WISP_DAMAGE", 4).contains("17.5 → 18.5"), "fourth-rank preview includes existing permanent damage bonuses")
	scene.queue_free()
	await process_frame
	_cleanup()


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func _verify_modal(cap_trial: bool, family_trial: bool) -> void:
	var scene = await _scene()
	var growth: RunGrowth = scene.growth
	growth.damage_cap_trial_enabled = cap_trial
	growth.choice_family_trial_enabled = family_trial
	# A bounded late-run setup, not a claim about when real play reaches these ranks.
	for id in RunGrowth.CARDS: growth.card_ranks[id] = growth.card_max_rank(id)
	for id in DAMAGE_CARDS: growth.card_ranks[id] = growth.card_max_rank(id) - 1
	growth.player.basic_damage_bonus = growth._damage_card_bonus("U_EDGE", int(growth.card_ranks.U_EDGE))
	growth._sync_wisps()
	scene.player.health = 10.0
	growth.gain_xp(8 + 10 + 12)
	_check(growth.choosing and paused and growth.pending_choices == 3 and growth.current_choices.size() == 2, "overflow XP opens the two legal last-rank options")
	_check(growth.points_earned == 3 and growth.points_spent == 0 and is_equal_approx(scene.player.health, 70.0), "all three earned levels heal once before selection")
	_check(growth.reroll_button.disabled and not growth.reroll_choices(), "a two-card exhausted candidate pool cannot reroll or spend an extra point")
	var maximum := 4 if cap_trial else 3
	for i in growth.current_choices.size():
		_check(growth.choice_buttons[i].text.contains("등급 %d / %d" % [maximum, maximum]), "actual modal shows the effective cap")
	_check(growth.choice_family_trial_label.visible == (cap_trial or family_trial), "independent experiment switches have an explicit UI notice")
	var mode := "cap-on" if cap_trial else "cap-off"
	mode += "-family-on" if family_trial else "-family-off"
	await _capture(growth, mode)
	var first := growth.current_choices[0]
	await _key(KEY_1)
	_check(growth.points_spent == 1 and growth.pending_choices == 2 and growth.choosing and not growth.current_choices.has(first), "first real key spends one point and removes the now-maxed card")
	await _key(KEY_1)
	_check(growth.points_spent == 2 and growth.pending_choices == 0 and growth.exhausted_points == 1 and not growth.choosing and not paused, "second real key spends one point; surplus point is accounted for after exhaustion")
	_check(growth.points_earned == growth.points_spent + growth.exhausted_points and is_equal_approx(scene.player.health, 70.0), "point ledger balances with no repeated healing")
	_check(growth.build_details().contains("%d/%d등급" % [maximum, maximum]), "selected-card history uses the effective cap")
	var values := {"basic_bonus": scene.player.basic_damage_bonus, "wisp_multiplier": growth.wisps[0].damage_multiplier}
	growth.current_choices.assign([first])
	growth.choosing = true
	_check(not growth.choose_index(0) and growth.points_spent == 2, "stale input cannot buy an already-maxed rank")
	growth.choosing = false
	paused = true
	growth.gain_xp(growth.next_xp())
	_check(paused and growth.points_earned == 4 and growth.exhausted_points == 2 and not growth.choosing, "fully exhausted trial keeps external pause and records the next earned point")
	paused = false
	report.fixtures.append({"mode": mode, "maximum": maximum, "values": values, "points_earned": growth.points_earned, "points_spent": growth.points_spent, "points_exhausted": growth.exhausted_points, "choice_windows": growth.choice_windows_opened})
	scene.queue_free()
	await process_frame
	_cleanup()


func _verify_permanent_caps() -> void:
	_cleanup()
	var profile := RunProfile.new()
	profile.save_prefix = PROFILE
	profile.load_state()
	_check(profile.settle("damage-cap-disposable-fixture", "SUCCESS", 1000), "disposable profile funds the existing permanent purchase check")
	for id in ["POWER", "WISP"]:
		_check(profile.buy_growth(id) and profile.buy_growth(id) and int(profile.growth_ranks[id]) == 2, "first two permanent purchases stay unchanged: " + id)
	var reloaded := RunProfile.new()
	reloaded.save_prefix = PROFILE
	reloaded.load_state()
	_check(not reloaded.load_error and int(reloaded.growth_ranks.POWER) == 2 and int(reloaded.growth_ranks.WISP) == 2 and RunProfile.GROWTH_COST.slice(0, 2) == [20, 35], "existing profile schema, prices and permanent ranks reload unchanged")
	var growth := RunGrowth.new()
	_check(not growth.damage_cap_trial_enabled and growth.card_max_rank("U_EDGE") == 3, "a new run never inherits the experiment from profile data")
	growth.free()
	_cleanup()


func _capture(growth: RunGrowth, mode: String) -> void:
	var destination := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): destination = argument.trim_prefix("--capture-dir=")
	if destination.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(destination)
	for resolution in [Vector2i(960, 540), Vector2i(1280, 720)]:
		root.size = resolution
		root.content_scale_size = Vector2i(1280, 720)
		for frame in 4: await process_frame
		await RenderingServer.frame_post_draw
		for button in growth.choice_buttons:
			if button.visible: _check(button.get_minimum_size().y <= button.size.y and button.get_global_rect().end.y < growth.choice_family_trial_label.global_position.y, "last-rank card stays within its panel")
		_check(growth.choice_family_trial_label.get_minimum_size().x <= growth.choice_family_trial_label.size.x and growth.choice_family_trial_label.get_global_rect().end.y <= growth.reroll_button.global_position.y, "experiment notice fits above reroll")
		var screenshot := root.get_texture().get_image()
		_check(screenshot.get_size() == resolution and screenshot.save_png(destination.path_join("%s-%dx%d.png" % [mode, resolution.x, resolution.y])) == OK, "actual cap modal capture saved")


func _run() -> void:
	await _verify_values()
	for cap_trial in [false, true]:
		for family_trial in [false, true]: await _verify_modal(cap_trial, family_trial)
	_verify_permanent_caps()
	report.validation = {"checks": checks, "failures": failures}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file := FileAccess.open(argument.trim_prefix("--report="), FileAccess.WRITE)
			file.store_string(JSON.stringify(report, "  "))
			file.close()
	print("Damage cap trial verification: ", checks, " checks, ", failures, " failures. Default caps unchanged; two independent opt-in flags; live capacity 35 versus 37.")
	quit(1 if failures else 0)
