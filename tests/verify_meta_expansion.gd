extends SceneTree

const PREFIX := "user://verify_meta_expansion_profile"
const UNLOCKS := "user://verify_meta_expansion_unlocks"
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	var profile := RunProfile.new()
	profile.save_prefix = PREFIX
	profile.load_state()
	_check(not profile.buy_growth("SLASH") and not profile.buy_growth("FINISH", 2), "Q and finisher growth remain locked before their move milestones")
	_check(profile.settle("first-temple", "SUCCESS", 0) and profile.buy_gear("W_FLOW"), "first region opens its Q weapon")
	_check(profile.settle("repeat-temple", "SUCCESS", 0) and RunProfile.REGION_MODS[RunProfile.TEMPLE_REGION].has(profile.last_mod_award), "a repeat clear grants an unowned regional option")
	var first_mod: String = profile.last_mod_award
	_check(profile.owned_mods.has(first_mod) and profile.mod_for("W_FLOW").is_empty(), "new option is stored without overwriting the weapon")
	var reloaded := RunProfile.new()
	reloaded.save_prefix = PREFIX
	reloaded.load_state()
	_check(reloaded.owned_mods.has(first_mod) and reloaded.owned_gear.W_FLOW, "option and weapon survive reload separately")
	_check(reloaded.settle("first-jungle", "SUCCESS", 0, RunProfile.JUNGLE_REGION) and reloaded.jungle_owned, "second region first clear unlocks the combo weapon")
	_check(reloaded.settle("repeat-jungle", "SUCCESS", 0, RunProfile.JUNGLE_REGION) and RunProfile.REGION_MODS[RunProfile.JUNGLE_REGION].has(reloaded.last_mod_award), "jungle repeat grants a region option even when its weapon is unpurchased")
	var jungle_mod: String = reloaded.last_mod_award
	_check(reloaded.settle("another-temple", "SUCCESS", 0) and reloaded.last_mod_award != first_mod, "further clears grant unowned options before duplicates")
	var both_saved := RunProfile.new()
	both_saved.save_prefix = PREFIX
	both_saved.load_state()
	_check(both_saved.owned_mods.has(first_mod) and both_saved.owned_mods.has(jungle_mod), "options from both regions survive a fresh profile load")
	_check(not reloaded.slot_mod("W_ECHO", jungle_mod), "an unpurchased weapon cannot slot an option")
	var unlocks := UnlockProgress.new()
	unlocks.save_prefix = UNLOCKS
	unlocks.load_progress()
	for i in 3: unlocks.add_levelup()
	var hub: Control = load("res://game/hub.tscn").instantiate()
	hub.profile_save_prefix = PREFIX
	hub.growth_save_prefix = UNLOCKS
	root.add_child(hub)
	await process_frame
	hub._select_region(RunProfile.JUNGLE_REGION)
	_check(hub.jungle_region_button.disabled == false and hub.progress_label.text.contains("재도전 성공"), "departure UI shows regional replay reward")
	_check(hub.start_button.text.contains("정글 절벽 관문"), "region selection changes the departure target")
	hub.queue_free()
	await process_frame
	_check(reloaded.buy_gear("W_ECHO"), "second clear permits purchasing the combo weapon")
	if RunProfile.GEAR_AFFIXES.W_ECHO.has(jungle_mod):
		_check(reloaded.slot_mod("W_ECHO", jungle_mod) and reloaded.mod_for("W_ECHO") == jungle_mod, "stored option can be slotted after buying its weapon")
	else:
		_check(reloaded.buy_gear("A_EMBER") and reloaded.slot_mod("A_EMBER", jungle_mod), "regional accessory option can be slotted after buying its gear")
	_check(reloaded.equip("W_ECHO") and reloaded.buy_growth("SLASH", 3) and reloaded.buy_growth("FINISH", 3), "both new growth axes purchase after move unlock")
	var scene: Node3D = load("res://game/jungle_pass.tscn").instantiate()
	scene.profile_save_prefix = PREFIX
	scene.growth_save_prefix = UNLOCKS
	root.add_child(scene)
	await physics_frame
	await physics_frame
	_check(scene.player.echo_finisher_enabled and is_equal_approx(scene.player.permanent_finisher_reach_bonus, 0.05) and is_equal_approx(scene.player.permanent_slash_cooldown_reduction, 0.03), "saved weapon and growth alter the live run")
	scene.teleport(Vector2(2600, 1120))
	scene.player.facing = Vector2.RIGHT
	scene.player.next_combo_step = 3
	scene.player._start_attack()
	scene.player._start_attack()
	var target := TrainingEnemy.new()
	target.max_health = 1000.0
	target.position = scene.player.echo_finisher_center + Vector2(0, 120)
	scene.simulation.add_child(target)
	target.set_physics_process(false)
	scene.player.attack_path_filter = Callable()
	scene.player._hit_enemies(scene.player._attack_spec(4))
	_check(target.health < 1000.0 and scene.player._attack_spec(4).angle == 360.0, "new fourth hit damages a side target around the third-hit gathering point")
	target.queue_free()
	scene.queue_free()
	await process_frame
	_cleanup()
	if failures == 0: print("Meta expansion verification passed: saved regional offers, unlock-gated growth and combo weapon")
	quit(1 if failures else 0)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _cleanup() -> void:
	for prefix in [PREFIX, UNLOCKS]:
		for suffix in ["_a.json", "_b.json"]:
			var path := ProjectSettings.globalize_path(prefix + suffix)
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
