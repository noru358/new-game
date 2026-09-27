extends SceneTree

var failures := 0
const PREFIX := "user://verify_1g_profile_temp"

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for suffix in ["_a.json", "_b.json"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(PREFIX + suffix))
	var profile := RunProfile.new()
	profile.save_prefix = PREFIX
	profile.load_state()
	_check(not profile.load_error and profile.currency == 0, "fresh profile begins empty")
	_check(not profile.region_available(RunProfile.JUNGLE_REGION) and not profile.settle("too-early", "SUCCESS", 0, RunProfile.JUNGLE_REGION), "second region cannot clear before the first")
	var first_saved := profile.settle("run-a", "DEFEAT", 7)
	_check(first_saved and profile.currency == 3 and profile.last_lost == 4 and not profile.temple_owned, "defeat loses half the earned currency, rounding the loss up")
	var single := RunProfile.new()
	single.save_prefix = PREFIX
	single.load_state()
	_check(not single.recovered_backup and single.currency == 3, "one normal save slot does not claim a backup recovery")
	_check(profile.settle("run-a", "DEFEAT", 100) and profile.currency == 3, "same run cannot settle twice")
	_check(profile.settle("run-b", "SUCCESS", 9) and profile.currency == 62 and profile.temple_owned and profile.temple_relic and profile.last_first_clear, "first clear grants all earned currency, success bonus and one first-clear record")
	_check(profile.region_available(RunProfile.JUNGLE_REGION) and not profile.jungle_owned, "first clear opens the second region without marking it complete")
	_check(profile.settle("run-c", "SUCCESS", 3) and profile.currency == 85 and not profile.last_first_clear, "repeat clear does not repeat first-clear reward")
	var reloaded := RunProfile.new()
	reloaded.save_prefix = PREFIX
	reloaded.load_state()
	_check(reloaded.currency == 85 and reloaded.temple_owned and reloaded.temple_relic and reloaded.last_run_id == "run-c", "all settled progress reloads together")
	var newest := PREFIX + ("_a.json" if reloaded.generation % 2 == 1 else "_b.json")
	var file := FileAccess.open(newest, FileAccess.WRITE)
	file.store_string("broken")
	file.close()
	var restored := RunProfile.new()
	restored.save_prefix = PREFIX
	restored.load_state()
	_check(restored.recovered_backup and not restored.load_error and restored.currency == 62, "corrupt latest slot restores preceding valid settlement")
	_check(reloaded.settle("run-jungle", "SUCCESS", 0, RunProfile.JUNGLE_REGION) and reloaded.jungle_owned and reloaded.currency == 135, "second region has an independent first-clear record and reward")
	var jungle_reloaded := RunProfile.new()
	jungle_reloaded.save_prefix = PREFIX
	jungle_reloaded.load_state()
	_check(jungle_reloaded.jungle_owned and jungle_reloaded.temple_owned and jungle_reloaded.temple_relic, "both region records survive reload without requiring a new save format")
	for suffix in ["_a.json", "_b.json"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(PREFIX + suffix))
	var broken := FileAccess.open(PREFIX + "_a.json", FileAccess.WRITE)
	broken.store_string("broken")
	broken.close()
	var blocked := RunProfile.new()
	blocked.save_prefix = PREFIX
	blocked.load_state()
	_check(blocked.load_error and not blocked.settle("run-x", "SUCCESS", 1), "corrupt-only profile is not silently overwritten")
	for suffix in ["_a.json", "_b.json"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(PREFIX + suffix))
	if failures == 0: print("Run profile verification passed: idempotent settlement, first clear, reload and backup recovery")
	quit(1 if failures else 0)
