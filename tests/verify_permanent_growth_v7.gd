extends SceneTree
var failures := 0
var checks := 0
var prefix := "user://growth_v7_%d" % Time.get_ticks_usec()
func _initialize(): call_deferred("_run")
func check(ok: bool, message: String):
	checks += 1
	if not ok: failures += 1; printerr("FAIL: ", message)
func write_slot(base: String, data: Dictionary):
	var file := FileAccess.open(base + "_a.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data)); file.close()
func _run():
	var profile := RunProfile.new()
	profile.save_prefix = prefix
	check(profile.settle("fund-growth", "SUCCESS", 10000), "fixture funds via unchanged settlement API")
	for id in RunProfile.GROWTH_IDS:
		check(is_equal_approx(PermanentGrowthCatalog.bonus(id, 2), float(PermanentGrowthCatalog.INCREMENTS[id]) * 2.0), "first two increments unchanged " + id)
	var bank := profile.currency
	check(not profile.buy_growth("SLASH_POWER", 0), "new slash damage observes first-level unlock")
	for id in RunProfile.GROWTH_IDS:
		for rank in range(1, 6):
			var before := profile.currency
			check(profile.buy_growth(id, 6) and profile.growth_ranks[id] == rank and profile.currency == before - RunProfile.GROWTH_COST[rank - 1], "exact purchase " + id + str(rank))
		check(not profile.buy_growth(id, 6), "sixth rank refused " + id)
	check(profile.currency == bank - 3500, "ten tracks cost3500 exactly")
	var loaded := RunProfile.new(); loaded.save_prefix = prefix; loaded.load_state()
	check(not loaded.load_error and loaded.growth_ranks.values().all(func(value): return int(value) == 5), "all ten rank5 reload")
	check(loaded.buy_attack_branch("DIRECT") and loaded.reset_growth() and loaded.currency == bank and loaded.attack_branch.is_empty(), "all prices and branch refund exactly")
	var reload := RunProfile.new(); reload.save_prefix = prefix; reload.load_state()
	check(reload.growth_ranks.values().all(func(value): return int(value) == 0) and reload.currency == bank, "respec persists")
	# Every original save version is read-only until a successful normal API write.
	for version in range(1, 7):
		var base := prefix + "_legacy" + str(version)
		var doc := RunProfile.new()._snapshot(); doc.version = version; doc.currency = 333
		for id in RunProfile.GROWTH_IDS: doc.growth_ranks[id] = 2 if id not in ["SLASH_POWER", "RECOVERY"] else 0
		doc.owned_outpost_ids = [RunProfile.TEMPLE_REGION]; doc.acquired_relic_ids = ["RELIC_TEMPLE"]
		write_slot(base, doc)
		var bytes := FileAccess.get_file_as_bytes(base + "_a.json")
		var old := RunProfile.new(); old.save_prefix = base; old.load_state()
		check(not old.load_error and old.currency == 333 and old.temple_owned and old.temple_relic, "legacy values retained v" + str(version))
		check(FileAccess.get_file_as_bytes(base + "_a.json") == bytes, "load does not write v" + str(version))
		check(old.begin_run("migrate") and FileAccess.get_file_as_bytes(base + "_pre_v7_a.json") == bytes, "raw archive before v7 write v" + str(version))
		for i in 3: old.begin_run("after" + str(i))
		check(FileAccess.get_file_as_bytes(base + "_pre_v7_a.json") == bytes, "later writes preserve original archive v" + str(version))
	var blocked_prefix := prefix + "_archiveblocked"
	var blocked_doc := RunProfile.new()._snapshot(); blocked_doc.version = 6
	write_slot(blocked_prefix, blocked_doc)
	var archive_file := FileAccess.open(blocked_prefix + "_pre_v7_a.json", FileAccess.WRITE); archive_file.store_string("existing unrelated archive"); archive_file.close()
	var original_bytes := FileAccess.get_file_as_bytes(blocked_prefix + "_a.json")
	var blocked := RunProfile.new(); blocked.save_prefix = blocked_prefix; blocked.load_state()
	check(not blocked.begin_run("must-not-write") and FileAccess.get_file_as_bytes(blocked_prefix + "_a.json") == original_bytes, "archive conflict blocks migration without modifying old slot")
	check(FileAccess.get_file_as_string(blocked_prefix + "_pre_v7_a.json") == "existing unrelated archive", "archive conflict never overwrites earlier bytes")
	for value in [-1.0, 2.5, 6.0]:
		var base := prefix + "_invalid" + str(value)
		var doc := RunProfile.new()._snapshot(); doc.growth_ranks.RECOVERY = value
		write_slot(base, doc)
		var invalid := RunProfile.new(); invalid.save_prefix = base; invalid.load_state()
		check(invalid.load_error and not invalid.begin_run("no-write"), "invalid new rank rejected " + str(value))
	# Mounted QA checks actual scene effects, preview, purchases, capped healing.
	var live_prefix := prefix + "_live"
	var live := RunProfile.new(); live.save_prefix = live_prefix; live.currency = 10000
	for id in RunProfile.GROWTH_IDS: live.buy_growth(id, 6); live.buy_growth(id, 6); live.buy_growth(id, 6); live.buy_growth(id, 6); live.buy_growth(id, 6)
	var unlocks := UnlockProgress.new(); unlocks.save_prefix = prefix + "_unlocks"
	for i in 6: unlocks.add_levelup()
	var scene = load("res://game/hybrid_region.tscn").instantiate()
	scene.profile_save_prefix = live_prefix; scene.growth_save_prefix = prefix + "_unlocks"
	root.add_child(scene); await process_frame
	scene.set_physics_process(false); scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
	check(is_equal_approx(scene.player.permanent_basic_damage_bonus, 0.175), "rank5 basic damage applies")
	check(scene.player.max_health == 135 and is_equal_approx(scene.player.permanent_damage_reduction, 0.175), "rank5 health and defense apply")
	check(is_equal_approx(scene.player.permanent_dash_cooldown_reduction, 0.14) and is_equal_approx(scene.player.permanent_move_speed_bonus, 0.14), "rank5 dash and movement apply")
	check(is_equal_approx(scene.player.permanent_slash_cooldown_reduction, 0.105) and is_equal_approx(scene.player.permanent_finisher_reach_bonus, 0.175), "rank5 slash reuse and gather reach apply")
	check(is_equal_approx(scene.wisp.attack_interval, 1.075) and is_equal_approx(scene.player.moving_slash_damage_bonus, 0.14), "rank5 wisp cadence and new slash damage apply")
	scene.player.health = 1; scene.growth.gain_xp(8)
	check(is_equal_approx(scene.player.health, 37.45) and is_equal_approx(scene.growth.level_heal_fraction, 0.27), "new recovery heals27% once on earned level")
	var health: float = scene.player.health
	scene.growth.reroll_choices(); scene.growth.choose_index(0)
	check(scene.player.health == health, "reroll and selection do not duplicate recovery")
	scene.player.health = 134; scene.growth.gain_xp(scene.growth.next_xp())
	check(scene.player.health == 135, "recovery clips at actual max health")
	scene.growth.choose_index(0)
	scene.queue_free(); await process_frame
	var hub = load("res://game/hub.tscn").instantiate()
	hub.profile_save_prefix = live_prefix; hub.growth_save_prefix = prefix + "_unlocks"
	root.add_child(hub); await process_frame
	check(hub.growth_buttons.size() == 10, "all ten tracks mounted in existing UI")
	for id in RunProfile.GROWTH_IDS:
		check(hub.growth_buttons[id].text.contains("5/5") and hub.growth_buttons[id].text.contains(PermanentGrowthCatalog.display_value(id, 5)) and hub.growth_buttons[id].disabled, "UI agrees with rank5 catalog " + id)
	hub.queue_free(); await process_frame
	print("PERMANENT_GROWTH_V7 ", checks, " checks failures ", failures)
	quit(1 if failures else 0)
