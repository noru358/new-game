extends SceneTree
const PREFIX := "user://verify_variety_profile"
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)
func _run() -> void:
	for suffix in ["_a.json", "_b.json"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(PREFIX + suffix))
	var profile := RunProfile.new()
	profile.save_prefix = PREFIX
	profile.load_state()
	profile.currency = 500
	check(not profile.buy_attack_branch("DIRECT"), "branch requires four attack ranks")
	for id in ["POWER", "WISP"]:
		for rank in 2: check(profile.buy_growth(id, 6), "base growth purchase")
	var before := profile.currency
	check(profile.buy_attack_branch("DIRECT") and profile.currency == before - 60, "one branch purchased at trial cost")
	check(not profile.buy_attack_branch("COMPANION") and not profile.buy_attack_branch("DIRECT"), "branches mutually exclusive and no duplicate charge")
	var loaded := RunProfile.new()
	loaded.save_prefix = PREFIX
	loaded.load_state()
	check(not loaded.load_error and loaded.attack_branch == "DIRECT", "v4 branch survives reload")
	var scene = load("res://game/hybrid_region.tscn").instantiate()
	scene.profile_save_prefix = PREFIX
	scene.growth_save_prefix = "user://verify_variety_unlocks"
	root.add_child(scene)
	await process_frame
	check(is_equal_approx(scene.player.permanent_basic_damage_bonus, 0.20) and is_equal_approx(scene.player.moving_slash_damage_bonus, 0.10), "direct branch reaches both direct attacks")
	scene.player.moving_slash_enabled = true
	scene.growth.apply_card("S_WISP_SWEEP")
	scene.wisp.fire_cooldown = 1.0
	scene.player._start_moving_slash(Vector2.RIGHT)
	scene.player.moving_slash_landed.emit(Vector2.ZERO)
	scene.player.moving_slash_landed.emit(Vector2.ZERO)
	check(is_equal_approx(scene.wisp.fire_cooldown, 0.88), "multiple targets refund once per actual slash")
	scene.player._start_moving_slash(Vector2.RIGHT)
	scene.player.moving_slash_landed.emit(Vector2.ZERO)
	check(is_equal_approx(scene.wisp.fire_cooldown, 0.76), "next slash can trigger again")
	var target := TrainingEnemy.new()
	scene.simulation.add_child(target)
	target.set_physics_process(false)
	scene.ember_step_mod_enabled = true
	scene.player.dash_charges = 0
	scene.player.dash_cooldown = 1.0
	scene._on_wisp_hit(target)
	scene._on_wisp_hit(target)
	check(is_equal_approx(scene.player.dash_cooldown, 0.95), "multiple wisps share equipment trigger cooldown")
	paused = true
	scene.ember_step_cooldown = 0.0
	scene._on_wisp_hit(target)
	check(is_equal_approx(scene.player.dash_cooldown, 0.95), "paused equipment cannot trigger")
	paused = false
	scene.queue_free()
	await process_frame
	check(loaded.reset_growth() and loaded.currency == 500 and loaded.attack_branch.is_empty(), "respec refunds all growth and branch cost exactly")
	var legacy := loaded._snapshot()
	legacy.version = 3
	legacy.erase("attack_branch")
	var file := FileAccess.open(PREFIX + "_a.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PREFIX + "_b.json"))
	loaded.load_state()
	check(not loaded.load_error and loaded.currency == 500 and loaded.attack_branch.is_empty(), "v3 profile migrates without losing currency")
	for id in ["POWER", "WISP"]:
		for rank in 2: loaded.buy_growth(id, 6)
	check(loaded.buy_attack_branch("COMPANION"), "other branch available after full refund")
	loaded.owned_mods.append("EMBER_STEP")
	check(loaded.buy_gear("A_EMBER") and loaded.slot_mod("A_EMBER", "EMBER_STEP") and loaded.equip("A_EMBER"), "new reward option can be stored and equipped")
	var companion_scene = load("res://game/hybrid_region.tscn").instantiate()
	companion_scene.profile_save_prefix = PREFIX
	companion_scene.growth_save_prefix = "user://verify_variety_unlocks"
	root.add_child(companion_scene)
	await process_frame
	check(companion_scene.ember_step_mod_enabled and is_equal_approx(companion_scene.wisp.permanent_damage_bonus, 0.25), "companion branch and gear apply after restart")
	companion_scene.growth.card_ranks["S_WISP_COUNT"] = 1
	companion_scene.growth._sync_wisps()
	check(is_equal_approx(companion_scene.growth.wisps[1].permanent_damage_bonus, 0.25), "new companion inherits branch bonus")
	companion_scene.queue_free()
	await process_frame
	var invalid := loaded._snapshot()
	invalid.attack_branch = "UNKNOWN"
	file = FileAccess.open(PREFIX + "_a.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(invalid))
	file.close()
	check(loaded._read(PREFIX + "_a.json").is_empty(), "invalid branch rejected")
	print("variety trial: ", failures, " failures")
	quit(1 if failures else 0)
