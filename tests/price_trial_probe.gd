extends Node
## Invoked only by test_price_trial_launcher.py in disposable trial copies.
## Synthetic wallets/unlocks exercise transactions; they are NOT income evidence.

var failures := 0

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 4 or args[0] != "--synthetic-price-check":
		printerr("FAIL: run through tests/test_price_trial_launcher.py only")
		get_tree().quit(1)
		return
	var late_cost := int(args[1])
	var expected_dir := args[2].replace("\\", "/")
	var phase := args[3]
	_check(OS.get_user_data_dir().replace("\\", "/") == expected_dir, "engine resolves user:// to this trial's private directory")
	_check(FileAccess.file_exists("user://price-trial-owner.json"), "trial ownership receipt exists")
	_check(ProjectSettings.get_setting("application/config/disable_project_settings_override"), "engine disables project override loading")
	_check(RunProfile.GROWTH_COST == [20, late_cost], "engine uses selected price curve")
	_check(RunProfile.GEAR_COST == {"W_FLOW": 35, "W_ECHO": 45, "A_EMBER": 24}, "gear costs remain unchanged")
	_check(RunProfile.ATTACK_BRANCH_COST == 60 and RunProfile.SUPPLY_COST == 12, "branch and supply costs remain unchanged")
	if failures:
		get_tree().quit(1)
		return
	await get_tree().process_frame
	var camp = get_tree().current_scene
	var hub = camp.preparation
	var profile: RunProfile = hub.profile
	var card_trials := {}
	if phase in ["cards-00", "cards-01", "cards-10", "cards-11"]:
		var cap := phase.substr(6, 1) == "1"
		var offers := phase.substr(7, 1) == "1"
		card_trials = {"damage_cap_trial": cap, "offer_family_trial": offers}
		_check(profile.currency == 0 and profile.generation == 0 and not profile.load_error and hub.unlocks.lifetime_levelups == 0, "card-trial copy starts fresh, without money or unlock grants")
		_check(get_tree().change_scene_to_file("res://game/hybrid_region.tscn") == OK, "real battle scene starts from the copy")
		await get_tree().process_frame
		await get_tree().process_frame
		var battle = get_tree().current_scene
		battle.set_physics_process(false)
		battle.simulation.process_mode = Node.PROCESS_MODE_DISABLED
		var growth: RunGrowth = battle.growth
		_check(growth.damage_cap_trial_enabled == cap and growth.choice_family_trial_enabled == offers, "copy-only defaults reach the actual run independently")
		_check(growth.card_max_rank("U_EDGE") == (4 if cap else 3) and growth.card_max_rank("S_WISP_DAMAGE") == (4 if cap else 3), "selected cap policy reaches the live card pool")
		_check(growth.card_max_rank("U_TEMPO") == 3 and growth.card_max_rank("S_WISP_COUNT") == 2 and RunProfile.GROWTH_COST.size() == 2, "other run caps and permanent cap remain fixed")
		growth.gain_xp(8)
		_check(growth.choosing and growth.points_earned == 1 and growth.pending_choices == 1 and get_tree().paused, "real earned XP opens the original modal")
		_check(growth.choice_family_trial_label.visible == (cap or offers), "live modal identifies enabled experiments")
		for i in growth.current_choices.size():
			var id := growth.current_choices[i]
			var next_rank := int(growth.card_ranks.get(id, 0)) + 1
			_check(growth.choice_buttons[i].text.ends_with("등급 %d / %d" % [next_rank, growth.card_max_rank(id)]), "actual copied modal uses its current rank and effective limit")
		_check(growth.choose_index(0) and growth.points_spent == 1 and not growth.choosing and not get_tree().paused, "copied run consumes exactly one earned choice")
	elif phase == "purchase":
		_check(profile.currency == 0 and profile.generation == 0 and not profile.load_error, "playable copy starts genuinely fresh")
		_check(profile.owned_gear.is_empty() and profile.equipped_weapon == "W_START" and profile.owned_outpost_ids.is_empty(), "no gear, progress or ownership grants")
		_check(hub.unlocks.lifetime_levelups == 0, "no permanent card-unlock grants")
		_check(not profile.growth_available("SLASH", 0) and not profile.growth_available("FINISH", 0), "original growth gates remain")
		for id in RunProfile.GROWTH_IDS:
			_check(profile.growth_ranks[id] == 0, "fresh rank is zero: " + id)
		if failures:
			get_tree().quit(1)
			return
		# Explicitly synthetic fixture from this point onward, only in a disposable copy.
		profile.currency = 3000
		_check(profile._commit(profile._snapshot()), "synthetic wallet saves in isolated copy")
		_check(not profile.buy_gear("W_FLOW"), "first weapon stays gated before temple success despite funded wallet")
		_check(profile.settle("synthetic-unlock-only", "SUCCESS", 0), "original temple success unlock condition")
		hub._select_gear("W_FLOW")
		_check(hub.gear_action_button.text.ends_with("35") and not hub.gear_action_button.disabled, "first weapon UI costs 35 after unlock")
		hub.gear_action_button.pressed.emit()
		_check(profile.currency == 3015 and profile.owned_gear.has("W_FLOW") and profile.equipped_weapon == "W_START", "purchase costs 35 and keeps equip separate")
		hub.gear_action_button.pressed.emit()
		_check(profile.equipped_weapon == "W_FLOW" and profile.currency == 3015, "separate equip is free")
		hub.unlocks.lifetime_levelups = 3
		hub.unlocks._save_progress()
		_check(hub.unlocks.generation == 1, "synthetic unlock fixture saves")
		for id in RunProfile.GROWTH_IDS:
			hub._refresh()
			var before := profile.currency
			_check(hub.growth_buttons[id].text.ends_with("구매 20"), "rank-one UI stays 20: " + id)
			hub.growth_buttons[id].pressed.emit()
			_check(profile.growth_ranks[id] == 1 and profile.currency == before - 20, "rank-one button charges 20: " + id)
			_check(hub.growth_buttons[id].text.ends_with("구매 %d" % late_cost), "rank-two UI shows selected price: " + id)
			hub.growth_buttons[id].pressed.emit()
			_check(profile.growth_ranks[id] == 2 and profile.currency == before - 20 - late_cost, "rank-two button charges selected price: " + id)
		_check(profile.buy_attack_branch("DIRECT"), "unchanged branch purchase works")
		_check(profile.currency == 3015 - 8 * (20 + late_cost) - 60, "all purchases conserve synthetic wallet")
	elif phase == "reset":
		_check(not profile.load_error and profile.currency == 3015 - 8 * (20 + late_cost) - 60, "separate engine process reloads own curve's paid balance")
		_check(profile.growth_ranks.values().all(func(rank): return rank == 2) and profile.attack_branch == "DIRECT", "all purchased ranks/branch survive restart")
		_check(profile.equipped_weapon == "W_FLOW" and hub.unlocks.lifetime_levelups == 3, "equipment and permanent unlocks reload")
		hub.reset_button.pressed.emit()
		_check(profile.currency == 3015 and profile.attack_branch.is_empty(), "reset refunds exactly this copy's paid growth/branch costs")
		_check(profile.growth_ranks.values().all(func(rank): return rank == 0), "reset clears ranks")
		_check(profile.reset_growth() and profile.currency == 3015, "repeated reset cannot mint currency")
	elif phase == "reload":
		_check(profile.currency == 3015 and profile.growth_ranks.values().all(func(rank): return rank == 0), "refund balance and reset ranks survive another engine restart")
		_check(profile.owned_gear.has("W_FLOW") and profile.equipped_weapon == "W_FLOW", "reset preserves gear")
	else:
		_check(false, "unknown test phase")
	if failures == 0:
		print("PRICE_TRIAL_CHECK ", JSON.stringify({"late_cost": late_cost, "phase": phase, "user_dir": OS.get_user_data_dir(), "synthetic_fixture": true, "card_trials": card_trials, "passed": true}))
	get_tree().quit(1 if failures else 0)
