extends SceneTree

const PROFILE := "user://verify_card_choice_trial_profile"
const UNLOCKS := "user://verify_card_choice_trial_unlocks"
const PRIORITIES := {
	"gather": ["U_TEMPO", "U_REACH", "U_EDGE", "S_WISP_FOLLOWUP", "S_WISP_COUNT", "S_WISP_DAMAGE", "S_WISP_CHAIN", "S_WISP_CADENCE", "U_SLASH_SWEEP", "U_SLASH_CADENCE", "S_WISP_SWEEP", "S_WISP_REPLY", "U_STEP", "S_WISP_ORBIT", "S_SEAL"],
	"movement": ["U_SLASH_CADENCE", "U_SLASH_SWEEP", "S_WISP_REPLY", "S_WISP_SWEEP", "U_TEMPO", "U_EDGE", "U_REACH", "S_WISP_FOLLOWUP", "S_WISP_COUNT", "S_WISP_DAMAGE", "S_WISP_CADENCE", "S_WISP_CHAIN", "U_STEP", "S_WISP_ORBIT", "S_SEAL"],
	"companion": ["S_WISP_COUNT", "S_WISP_CADENCE", "S_WISP_DAMAGE", "S_WISP_CHAIN", "S_WISP_FOLLOWUP", "S_WISP_SWEEP", "S_WISP_REPLY", "S_WISP_ORBIT", "U_REACH", "U_TEMPO", "U_SLASH_SWEEP", "U_SLASH_CADENCE", "U_EDGE", "U_STEP", "S_SEAL"],
}
var failures := 0
var checks := 0
var report := {
	"scope": "512 seeded offer sequences per existing v34 priority, then isolated earned-XP modal fixtures; not combat, human preference or balance acceptance",
	"tradeoff": RunGrowth.CHOICE_FAMILY_TRIAL_NOTICE,
	"seeds": 512, "offers": {}, "modal": [],
}


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _pick(offered: Array[String], build: String) -> int:
	for card_id in PRIORITIES[build]:
		if offered.has(card_id): return offered.find(card_id)
	return 0


func _verify_offers() -> void:
	var growth := RunGrowth.new()
	var player := SandboxPlayer.new()
	growth.player = player
	player.moving_slash_enabled = true
	growth.permanent_combo_progression = true
	growth.unlocks.lifetime_levelups = 6
	_check(not growth.choice_family_trial_enabled, "ordinary runs default to the original offers")
	for trial in [false, true]:
		growth.choice_family_trial_enabled = trial
		var modes := {}
		for build in PRIORITIES:
			var counts := {}
			for milestone in [3, 6, 9]:
				counts[str(milestone)] = {"no_slash_cadence_offered": 0, "no_slash_card_offered": 0, "two_family_choices": 0, "selected_families": {}}
			for seed_value in 512:
				growth.rng.seed = seed_value
				growth.card_ranks = {"U_STEP": 2}
				var seen := {}
				var selected := {}
				var two_families := 0
				for choice in range(1, 10):
					var offered := growth.roll_choices()
					var unique := {}
					var families := {}
					var manual := false
					var companion := false
					for card_id in offered:
						unique[card_id] = true
						seen[card_id] = true
						families[growth._offer_family(card_id)] = true
						manual = manual or RunGrowth.CARDS[card_id].group == "BASIC"
						companion = companion or card_id.begins_with("S_WISP_")
						_check(int(growth.card_ranks.get(card_id, 0)) < int(RunGrowth.CARDS[card_id].max) and growth.unlocks.is_unlocked(card_id), "only eligible ranks are offered")
					_check(offered.size() == 3 and unique.size() == 3 and manual and companion, "manual/companion guarantees and three unique cards remain")
					if trial: _check(families.size() == 3, "trial uses three action families when they remain available")
					if families.size() < 3: two_families += 1
					var chosen := offered[_pick(offered, build)]
					growth.card_ranks[chosen] = int(growth.card_ranks.get(chosen, 0)) + 1
					var family := growth._offer_family(chosen)
					selected[family] = int(selected.get(family, 0)) + 1
					if choice in [3, 6, 9]:
						var row: Dictionary = counts[str(choice)]
						if not seen.has("U_SLASH_CADENCE"): row.no_slash_cadence_offered += 1
						if not seen.has("U_SLASH_CADENCE") and not seen.has("U_SLASH_SWEEP"): row.no_slash_card_offered += 1
						row.two_family_choices += two_families
						for key in selected: row.selected_families[key] = int(row.selected_families.get(key, 0)) + selected[key]
			modes[build] = counts
		report.offers["trial" if trial else "baseline"] = modes
	var first_pairs := {}
	var third_cards := {}
	for seed_value in 64:
		growth.card_ranks = {"U_STEP": 2}
		growth.choice_family_trial_enabled = false
		growth.rng.seed = seed_value
		var baseline := growth.roll_choices()
		growth.choice_family_trial_enabled = true
		growth.rng.seed = seed_value
		var trial := growth.roll_choices()
		_check(trial.slice(0, 2) == baseline.slice(0, 2), "trial leaves the two existing guaranteed draws unchanged")
		growth.rng.seed = seed_value
		_check(trial == growth.roll_choices(), "same seed and ranks reproduce trial offers")
		first_pairs[str(trial.slice(0, 2))] = true
		third_cards[trial[2]] = true
	_check(first_pairs.size() > 12 and third_cards.size() > 3, "trial preserves random individual cards, not a fixed build deck")
	for card_id in RunGrowth.CARDS: growth.card_ranks[card_id] = RunGrowth.CARDS[card_id].max
	_check(growth.roll_choices().is_empty(), "exhausted pool remains empty")
	growth.card_ranks.S_WISP_DAMAGE = 0
	_check(growth.roll_choices() == ["S_WISP_DAMAGE"], "one eligible card is offered once")
	growth.card_ranks.S_WISP_CADENCE = 0
	_check(growth.roll_choices().size() == 2, "two same-family cards remain available")
	growth.card_ranks.S_WISP_COUNT = 0
	_check(growth.roll_choices().size() == 3, "three same-family cards use the full-pool fallback")
	growth.card_ranks.clear()
	growth.unlocks.lifetime_levelups = 0
	player.moving_slash_enabled = false
	for seed_value in 64:
		growth.rng.seed = seed_value
		for card_id in growth.roll_choices():
			_check(not card_id.begins_with("U_SLASH_") and card_id not in ["S_WISP_REPLY", "S_WISP_SWEEP", "S_WISP_COUNT", "S_WISP_ORBIT", "S_WISP_CHAIN", "U_CHAIN"], "locked movement, lifetime cards and permanent combo stay excluded")
	growth.permanent_combo_progression = false
	_check(growth.roll_choices()[0] == "U_CHAIN", "legacy lab's guaranteed combo card is preserved")
	growth.free()
	player.free()


func _verify_descriptions() -> void:
	var growth := RunGrowth.new()
	var player := SandboxPlayer.new()
	growth.player = player
	_check(growth.describe_card("U_REACH", 1) == "평타 범위\n+0% → +15%", "two-hit players are not promised locked gather or finisher moves")
	player.set_combo_rank(2)
	player.echo_finisher_enabled = true
	player.echo_finisher_radius_bonus = 0.10
	player.echo_gather_reach_bonus = 0.08
	player.permanent_finisher_reach_bonus = 0.10
	var radii: Array[float] = []
	for step in range(1, 5): radii.append(player._attack_spec(step).radius)
	for rank in range(1, 4):
		growth.apply_card("U_REACH")
		for step in range(1, 5):
			_check(is_equal_approx(player._attack_spec(step).radius, radii[step - 1] * (1.0 + 0.15 * rank)), "percentage range preview matches every live attack, including equipped gather and burst")
		_check(growth.describe_card("U_REACH", rank).contains("+%d%% → +%d%%" % [15 * (rank - 1), 15 * rank]), "selected-rank history uses the same percentage units as the next-card preview")
	growth.basic_speed_base = 0.18
	player.basic_speed_bonus = 0.18
	var windup: float = player._attack_spec(4).windup
	growth.apply_card("U_TEMPO")
	_check(is_equal_approx(player._attack_spec(4).windup, windup * 1.18 / 1.30) and growth.describe_card("U_TEMPO", 1).contains("+18% → +30%"), "tempo includes existing speed and really speeds up the finisher")
	player.permanent_basic_damage_bonus = 0.30
	growth.apply_card("U_EDGE")
	_check(is_equal_approx(1.0 + player.basic_damage_bonus + player.permanent_basic_damage_bonus, 1.45) and growth.describe_card("U_EDGE", 1).contains("130% → 145%"), "damage scope and preview include the existing permanent contribution")
	growth.free()
	player.free()


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func _verify_modal(trial: bool) -> void:
	_cleanup()
	var scene = load("res://game/hybrid_region.tscn").instantiate()
	scene.profile_save_prefix = PROFILE
	scene.growth_save_prefix = UNLOCKS
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
	var growth: RunGrowth = scene.growth
	growth.choice_family_trial_enabled = trial
	growth.rng.seed = 250
	scene.player.health = 10.0
	var rows: Array = []
	for choice in range(1, 10):
		growth.gain_xp(growth.next_xp())
		_check(growth.choosing and paused and growth.pending_choices == 1, "one earned level opens the ordinary modal")
		_check(growth.points_earned == choice and growth.points_spent == choice - 1 and growth.exhausted_points == 0, "offer changes do not create or consume points")
		_check(growth.choice_family_trial_label.visible == trial, "only the opt-in fixture displays its tradeoff label")
		if choice == 1:
			_check(growth.describe_card("U_REACH", 1).contains("3타 집결") and not growth.describe_card("U_REACH", 1).contains("마무리"), "scope names only the currently unlocked combo")
			var health: float = scene.player.health
			_check(growth.reroll_choices() and growth.rerolls_left == 0, "one reroll remains available")
			_check(scene.player.health == health and growth.points_earned == choice and not growth.reroll_choices(), "reroll cannot heal, grant points or repeat")
		if choice in [3, 6, 9]:
			_check(growth.describe_card("U_REACH", 1) == "평타·집결·마무리 범위\n+0% → +15%", "reach preview describes the percentage applied to all unlocked attack radii")
			await _capture(growth, "trial" if trial else "baseline", choice)
		var offered := growth.current_choices.duplicate()
		var index := _pick(growth.current_choices, "movement")
		await _key(KEY_1 + index)
		_check(growth.points_spent == choice and growth.pending_choices == 0 and not growth.choosing and not paused, "real number-key choice consumes one point and resumes")
		_check(is_equal_approx(scene.player.health, minf(100.0, 10.0 + 20.0 * choice)), "one level grants one clipped 20-percent heal")
		if choice in [3, 6, 9]: rows.append({"points": choice, "offered": offered, "chosen": offered[index], "cards": growth.selected_card_ranks.duplicate(), "health": scene.player.health, "windows": growth.choice_windows_opened})
	_check(growth.level == 10 and growth.choice_windows_opened == 9 and growth.unlocks.lifetime_levelups == 9, "nine ordinary earned choices preserve level, window and unlock counters")
	paused = true
	growth.gain_xp(growth.next_xp())
	await _key(KEY_1)
	_check(paused and not growth.choosing, "choice preserves the prior external pause")
	paused = false
	growth.end_run()
	var spent := growth.points_spent
	growth.gain_xp(1000)
	_check(growth.points_spent == spent and growth.points_earned == 10 and not growth.choose_index(0), "ended run cannot gain or consume extra choices")
	report.modal.append({"mode": "trial" if trial else "baseline", "checkpoints": rows})
	scene.queue_free()
	await process_frame
	_cleanup()


func _capture(growth: RunGrowth, mode: String, choice: int) -> void:
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
			_check(button.get_minimum_size().y <= button.size.y and button.get_global_rect().end.y < growth.choice_family_trial_label.global_position.y, "actual card fits above the trial label at " + str(resolution))
		_check(growth.choice_family_trial_label.get_minimum_size().x <= growth.choice_family_trial_label.size.x and growth.choice_family_trial_label.get_global_rect().end.y <= growth.reroll_button.global_position.y, "trial label fits before reroll")
		var path := destination.path_join("%s-choice-%d-%dx%d.png" % [mode, choice, resolution.x, resolution.y])
		var screenshot := root.get_texture().get_image()
		_check(screenshot.get_size() == resolution and screenshot.save_png(path) == OK, "actual modal screenshot saved: " + path)


func _cleanup() -> void:
	for prefix in [PROFILE, UNLOCKS]:
		for suffix in ["_a.json", "_b.json"]:
			var path := ProjectSettings.globalize_path(prefix + suffix)
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)


func _run() -> void:
	_verify_offers()
	_verify_descriptions()
	await _verify_modal(false)
	await _verify_modal(true)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file := FileAccess.open(argument.trim_prefix("--report="), FileAccess.WRITE)
			file.store_string(JSON.stringify(report, "  "))
			file.close()
	print("Card choice trial verification: ", checks, " checks, ", failures, " failures. Baseline remains default. ", RunGrowth.CHOICE_FAMILY_TRIAL_NOTICE)
	quit(1 if failures else 0)
