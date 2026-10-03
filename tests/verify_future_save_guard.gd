extends SceneTree

const Profile = preload("res://game/run_profile.gd")
const SUFFIXES := ["_a.json", "_b.json"]
const FUTURE_CASES := ["future_a", "future_b", "both_future", "only_future_a", "only_future_b", "future_header", "future_corrupt", "corrupt_future"]
var failures := 0
var checks := 0
var fixture_root := ""


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _document(version: int, generation: int, currency: int) -> String:
	var data := Profile.new()._snapshot()
	data.version = version
	data.generation = generation
	data.currency = currency
	return JSON.stringify(data)


func _write_case(name: String, a: String, b: String) -> void:
	for i in 2:
		var contents := a if i == 0 else b
		if contents.is_empty(): continue
		var file := FileAccess.open(fixture_root.path_join(name) + SUFFIXES[i], FileAccess.WRITE)
		_check(file != null, name + ": synthetic fixture opens")
		if file != null:
			file.store_string(contents)
			file.close()


func _bytes(prefix: String) -> Array:
	var result := []
	for suffix in SUFFIXES:
		result.append(FileAccess.get_file_as_bytes(prefix + suffix) if FileAccess.file_exists(prefix + suffix) else null)
	return result


func _load(prefix: String) -> RunProfile:
	var profile := Profile.new()
	profile.save_prefix = prefix
	profile.load_state()
	return profile


func _verify_future_cases() -> void:
	for name in FUTURE_CASES:
		var prefix := fixture_root.path_join(name)
		var before := _bytes(prefix)
		var profile := _load(prefix)
		_check(profile.load_error and profile.unsupported_save_format and not profile.recovered_backup, name + ": future format blocks, never claims corrupt backup recovery")
		_check(profile.currency == 0 and profile.generation == 0, name + ": older slot is not loaded as usable progress")
		_check(profile.save_block_reason().contains("업데이트") and profile.save_block_reason().contains("보존"), name + ": update and preservation guidance")
		_check(not profile.begin_run("future-launch"), name + ": departure blocked")
		_check(not profile.settle("future-settle", "SUCCESS", 500), name + ": settlement blocked")
		_check(not profile._commit(profile._snapshot()), name + ": central writer blocked")
		_check(not profile.buy_gear("A_EMBER") and not profile.equip("W_START") and not profile.slot_mod("W_FLOW", ""), name + ": gear mutations blocked")
		_check(not profile.buy_growth("POWER") and not profile.reset_growth() and not profile.buy_attack_branch("DIRECT"), name + ": growth mutations blocked")
		_check(not profile.buy_supply() and not profile.select_supply(false), name + ": supply mutations blocked")
		_check(not profile.discover_garden() and not profile.claim_garden_awakening() and not profile.claim_grotto_awakening(), name + ": permanent rewards blocked")
		_check(before == _bytes(prefix), name + ": both slot bytes and absent slot preserved")
		profile.load_state()
		_check(profile.load_error and profile.unsupported_save_format and not profile.begin_run("future-reload"), name + ": same-object reload stays blocked")
		_check(before == _bytes(prefix), name + ": reload preserves bytes")


func _verify_supported_cases() -> void:
	for name in ["valid_corrupt", "corrupt_valid", "valid_same_version"]:
		var prefix := fixture_root.path_join(name)
		var profile := _load(prefix)
		_check(not profile.load_error and not profile.unsupported_save_format, name + ": supported saves remain writable")
		_check(profile.recovered_backup == (name != "valid_same_version"), name + ": corrupt backup recovery remains distinct")
		_check(profile.currency == (101 if name == "valid_same_version" else 17), name + ": newest valid currency selected")
		_check(profile.begin_run("normal-" + name), name + ": normal departure works")
		_check(profile.settle("normal-" + name, "RETREAT", 5), name + ": normal settlement works")
		var reloaded := _load(prefix)
		_check(not reloaded.load_error and reloaded.currency == profile.currency and reloaded.last_run_id == "normal-" + name, name + ": settlement survives reload")
		for suffix in SUFFIXES:
			var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(prefix + suffix))
			_check(document is Dictionary and document.version == Profile.SAVE_VERSION, name + ": write format follows current version")
	var corrupt := _load(fixture_root.path_join("both_corrupt"))
	_check(corrupt.load_error and not corrupt.unsupported_save_format and not corrupt.begin_run("broken"), "both corrupt remains blocked without future-version guidance")
	_check(not corrupt.save_block_reason().contains("업데이트"), "corruption keeps backup guidance")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--future-save-restart":
		fixture_root = args[1]
		_verify_future_cases()
		for name in ["valid_corrupt", "corrupt_valid", "valid_same_version"]:
			var profile := _load(fixture_root.path_join(name))
			_check(not profile.load_error and profile.last_run_id == "normal-" + name, name + ": new process restores settlement")
		if failures == 0: print("Future save restart verification passed: ", checks, " checks")
		quit(1 if failures else 0)
		return
	fixture_root = "user://verify_future_save_guard_%d_%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()]
	_check(DirAccess.make_dir_recursive_absolute(fixture_root) == OK, "create unique synthetic fixture directory")
	var valid_a := _document(6, 1, 17)
	var valid_b := _document(6, 2, 101)
	var future_a := _document(8, 1, 101)
	var future_b := _document(8, 2, 101)
	_write_case("future_a", future_a, valid_b)
	_write_case("future_b", valid_a, future_b)
	_write_case("both_future", future_a, _document(9, 2, 999))
	_write_case("only_future_a", future_a, "")
	_write_case("only_future_b", "", future_b)
	_write_case("future_header", "{\n  \"version\": 8, \"new_schema\": [\"unknown\"]\n}\n", valid_b)
	_write_case("future_corrupt", future_a, "broken")
	_write_case("corrupt_future", "broken", future_b)
	_write_case("valid_corrupt", valid_a, "broken")
	_write_case("corrupt_valid", "broken", _document(6, 2, 17))
	_write_case("valid_same_version", valid_a, valid_b)
	_write_case("both_corrupt", "broken", "broken")
	_verify_future_cases()
	_verify_supported_cases()
	var restart_bytes := {}
	for name in FUTURE_CASES:
		restart_bytes[name] = _bytes(fixture_root.path_join(name))
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--log-file", ProjectSettings.globalize_path(fixture_root.path_join("restart-engine.log")), "--script", "res://tests/verify_future_save_guard.gd", "--", "--future-save-restart", fixture_root], output, true)
	_check(code == 0 and str(output).contains("Future save restart verification passed") and not str(output).contains("SCRIPT ERROR"), "fresh engine process verifies future guard, bytes and normal settlements")
	if code != 0: printerr(output)
	for name in FUTURE_CASES:
		var prefix := fixture_root.path_join(name)
		_check(_load(prefix).load_error, name + ": remains blocked after child process")
		_check(restart_bytes[name] == _bytes(prefix), name + ": parent confirms exact bytes across process restart")
	for file in DirAccess.get_files_at(fixture_root):
		DirAccess.remove_absolute(fixture_root.path_join(file))
	DirAccess.remove_absolute(fixture_root)
	if failures == 0: print("Future save guard verification passed: ", checks, " checks; 8 future combinations, corrupt recovery, v6 writes, byte preservation and fresh-process restart")
	quit(1 if failures else 0)
