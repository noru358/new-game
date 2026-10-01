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
	if phase == "purchase":
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
		print("PRICE_TRIAL_CHECK ", JSON.stringify({"late_cost": late_cost, "phase": phase, "user_dir": OS.get_user_data_dir(), "synthetic_fixture": true, "passed": true}))
	get_tree().quit(1 if failures else 0)
