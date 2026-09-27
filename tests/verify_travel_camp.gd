extends SceneTree

const PROFILE := "user://verify_travel_camp_profile"
const UNLOCKS := "user://verify_travel_camp_unlocks"
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	var camp: Node3D = load("res://game/travel_camp.tscn").instantiate()
	camp.profile_save_prefix = PROFILE
	camp.growth_save_prefix = UNLOCKS
	root.add_child(camp)
	await process_frame
	_check(camp.stations.size() == 3 and not camp.preparation.visible, "walkable camp begins with three closed stations")
	for station in camp.stations:
		camp.player_visual.position = station.position + Vector3(1.4, 0, 0)
		camp._update_prompt()
		_check(camp.prompt.text.contains(station.name), "nearby station is identified")
		var interact := InputEventKey.new()
		interact.keycode = KEY_E
		interact.pressed = true
		camp._unhandled_key_input(interact)
		_check(camp.preparation.visible and camp.preparation.tabs.current_tab == station.tab, "interaction opens the station's matching preparation tab")
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		camp._unhandled_key_input(escape)
		_check(not camp.preparation.visible, "escape returns to the walkable camp")
	camp.queue_free()
	await process_frame
	_cleanup()
	if failures == 0: print("Travel camp verification passed: stations open matching tabs and return to camp")
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
