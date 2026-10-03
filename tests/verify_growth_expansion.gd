extends SceneTree

const PROFILE := "user://verify_growth_expansion_profile"
const UNLOCKS := "user://verify_growth_expansion_unlocks"
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	var profile := RunProfile.new()
	profile.save_prefix = PROFILE
	profile.load_state()
	_check(profile.settle("growth-first-clear", "SUCCESS", 500), "first run funds growth trial")
	for id in ["WISP", "GUARD", "SPEED"]:
		_check(profile.buy_growth(id) and profile.buy_growth(id) and int(profile.growth_ranks[id]) == 2, "new growth track buys two levels: " + id)
	var loaded := RunProfile.new()
	loaded.save_prefix = PROFILE
	loaded.load_state()
	_check(not loaded.load_error and int(loaded.growth_ranks.WISP) == 2 and int(loaded.growth_ranks.GUARD) == 2 and int(loaded.growth_ranks.SPEED) == 2, "three new ranks survive save and reload")
	var scene: Node3D = load("res://game/hybrid_region.tscn").instantiate()
	scene.profile_save_prefix = PROFILE
	scene.growth_save_prefix = UNLOCKS
	root.add_child(scene)
	await physics_frame
	await physics_frame
	_check(is_equal_approx(scene.wisp.attack_interval, WispCompanion.BASE_ATTACK_INTERVAL * 0.92), "permanent wisp cadence changes the live companion")
	_check(is_equal_approx(scene.player.permanent_damage_reduction, 0.10) and is_equal_approx(scene.player.permanent_move_speed_bonus, 0.08), "defense and movement growth reach the live player")
	scene.player.receive_hit(10.0)
	_check(is_equal_approx(scene.player.health, 91.0), "defense rank reduces incoming damage")
	scene.growth.card_ranks["S_WISP_COUNT"] = 1
	scene.growth._sync_wisps()
	_check(scene.growth.wisps.size() == 2 and is_equal_approx(scene.growth.wisps[1].attack_interval, WispCompanion.BASE_ATTACK_INTERVAL * 0.92), "new wisps inherit permanent cadence")
	_check(scene.growth.describe_card("S_WISP_CADENCE", 1).contains("1.15초"), "card preview includes the permanent cadence rank")
	scene.queue_free()
	await physics_frame
	_check(loaded.reset_growth() and int(loaded.growth_ranks.WISP) == 0 and int(loaded.growth_ranks.GUARD) == 0 and int(loaded.growth_ranks.SPEED) == 0, "full respec clears new growth tracks")
	var older_v3: Dictionary = loaded._snapshot()
	older_v3.version = 3
	for id in ["WISP", "GUARD", "SPEED"]: older_v3.growth_ranks.erase(id)
	var legacy_file := FileAccess.open(PROFILE + "_a.json", FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(older_v3))
	legacy_file.close()
	var other_slot := ProjectSettings.globalize_path(PROFILE + "_b.json")
	if FileAccess.file_exists(other_slot): DirAccess.remove_absolute(other_slot)
	var migrated := RunProfile.new()
	migrated.save_prefix = PROFILE
	migrated.load_state()
	_check(not migrated.load_error and int(migrated.growth_ranks.WISP) == 0 and int(migrated.growth_ranks.GUARD) == 0 and int(migrated.growth_ranks.SPEED) == 0, "older v3 profiles fill missing growth tracks with zero")
	older_v3.growth_ranks.WISP = 3
	legacy_file = FileAccess.open(PROFILE + "_a.json", FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(older_v3))
	legacy_file.close()
	migrated.load_state()
	_check(migrated.load_error, "invalid new growth ranks are rejected without overwriting the profile")
	_cleanup()
	if failures == 0: print("Growth expansion verification passed: save, combat, cards and respec")
	quit(1 if failures else 0)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _cleanup() -> void:
	for prefix in [PROFILE, UNLOCKS]:
		for suffix in ["_a.json", "_b.json"]:
			var path := ProjectSettings.globalize_path(prefix + suffix)
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
