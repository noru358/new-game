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
	var first_saved := profile.settle("run-a", "DEFEAT", 7)
	_check(first_saved and profile.currency == 7 and not profile.temple_owned, "defeat banks only earned currency")
	var single := RunProfile.new()
	single.save_prefix = PREFIX
	single.load_state()
	_check(not single.recovered_backup and single.currency == 7, "one normal save slot does not claim a backup recovery")
	_check(profile.settle("run-a", "DEFEAT", 100) and profile.currency == 7, "same run cannot settle twice")
	_check(profile.settle("run-b", "SUCCESS", 9) and profile.currency == 66 and profile.temple_owned and profile.temple_relic and profile.last_first_clear, "first clear grants earned currency, success bonus and one relic")
	_check(profile.settle("run-c", "SUCCESS", 3) and profile.currency == 89 and not profile.last_first_clear, "repeat clear does not repeat first-clear reward")
	var reloaded := RunProfile.new()
	reloaded.save_prefix = PREFIX
	reloaded.load_state()
	_check(reloaded.currency == 89 and reloaded.temple_owned and reloaded.temple_relic and reloaded.last_run_id == "run-c", "all settled progress reloads together")
	var newest := PREFIX + ("_a.json" if reloaded.generation % 2 == 1 else "_b.json")
	var file := FileAccess.open(newest, FileAccess.WRITE)
	file.store_string("broken")
	file.close()
	var restored := RunProfile.new()
	restored.save_prefix = PREFIX
	restored.load_state()
	_check(restored.recovered_backup and not restored.load_error and restored.currency == 66, "corrupt latest slot restores preceding valid settlement")
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
