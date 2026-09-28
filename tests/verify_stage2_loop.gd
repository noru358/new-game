extends SceneTree

const PROFILE := "user://verify_stage2_loop_profile"
const UNLOCKS := "user://verify_stage2_loop_unlocks"
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _profile() -> RunProfile:
	var profile := RunProfile.new()
	profile.save_prefix = PROFILE
	profile.load_state()
	return profile


func _run() -> void:
	_cleanup()
	var first := _profile()
	_check(first.region_available(RunProfile.TEMPLE_REGION) and not first.region_available(RunProfile.JUNGLE_REGION), "new profile starts at the first region")
	_check(first.settle("first-region", "SUCCESS", 30), "first region success is saved")
	_check(first.buy_gear("W_FLOW") and first.equip("W_FLOW"), "first clear makes the Q weapon usable")
	_check(first.buy_growth("POWER") and first.buy_growth("VITALITY"), "first clear income buys attack and survival growth")
	var unlocks := UnlockProgress.new()
	unlocks.save_prefix = UNLOCKS
	unlocks.load_progress()
	for i in 3: unlocks.add_levelup()
	var after_first := _profile()
	var loaded_unlocks := UnlockProgress.new()
	loaded_unlocks.save_prefix = UNLOCKS
	loaded_unlocks.load_progress()
	_check(after_first.region_available(RunProfile.JUNGLE_REGION) and after_first.equipped_weapon == "W_FLOW" and int(after_first.growth_ranks.POWER) == 1 and int(after_first.growth_ranks.VITALITY) == 1 and loaded_unlocks.lifetime_levelups == 3, "region, weapon, growth and card milestones survive a fresh load")
	var jungle: Node3D = load("res://game/jungle_pass.tscn").instantiate()
	jungle.profile_save_prefix = PROFILE
	jungle.growth_save_prefix = UNLOCKS
	root.add_child(jungle)
	await physics_frame
	_check(jungle.player.flow_weave_enabled and not jungle.player.echo_finisher_enabled and jungle.player.max_health == 110.0 and jungle.player.permanent_basic_damage_bonus > 0.0, "next region starts with the purchased Q build")
	jungle.queue_free()
	await physics_frame
	var after_jungle := _profile()
	_check(after_jungle.settle("second-region", "SUCCESS", 20, RunProfile.JUNGLE_REGION), "second region success is saved")
	_check(after_jungle.buy_gear("W_ECHO") and after_jungle.equip("W_ECHO"), "second clear makes the finisher weapon usable")
	var final_profile := _profile()
	_check(final_profile.jungle_owned and final_profile.equipped_weapon == "W_ECHO" and final_profile.owned_gear.has("W_FLOW") and final_profile.owned_gear.has("W_ECHO"), "both clears and both weapon choices persist after restart")
	var temple: Node3D = load("res://game/hybrid_region.tscn").instantiate()
	temple.profile_save_prefix = PROFILE
	temple.growth_save_prefix = UNLOCKS
	root.add_child(temple)
	await physics_frame
	_check(temple.player.echo_finisher_enabled and not temple.player.flow_weave_enabled and temple.player.max_health == 110.0, "a replay starts with a different saved combat build")
	temple.queue_free()
	await physics_frame
	_cleanup()
	if failures == 0: print("Stage 2 loop verification passed: clear, unlock, growth, next region, alternate build, restart")
	quit(1 if failures else 0)


func _cleanup() -> void:
	for prefix in [PROFILE, UNLOCKS]:
		for suffix in ["_a.json", "_b.json"]:
			var path := ProjectSettings.globalize_path(prefix + suffix)
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
