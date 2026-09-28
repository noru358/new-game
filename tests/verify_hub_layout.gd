extends SceneTree

const PROFILE := "user://verify_hub_layout_profile"
const UNLOCKS := "user://verify_hub_layout_unlocks"
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_window().content_scale_size = Vector2i(960, 540)
	var hub: Control = load("res://game/hub.tscn").instantiate()
	hub.profile_save_prefix = PROFILE
	hub.growth_save_prefix = UNLOCKS
	root.add_child(hub)
	await process_frame
	hub.tabs.current_tab = 1
	await process_frame
	_check(hub.gear_list_scroll != hub.gear_detail_scroll and hub.gear_list_scroll.get_parent() == hub.gear_detail_scroll.get_parent(), "gear choice and option detail have independent scroll views")
	hub.gear_list_scroll.scroll_vertical = 75
	await process_frame
	var list_offset: int = hub.gear_list_scroll.scroll_vertical
	var first_y: float = hub.weapon_button.global_position.y
	for button in [hub.weapon_button, hub.echo_weapon_button, hub.accessory_button, hub.weapon_button]:
		button.grab_focus()
		button.pressed.emit()
		await process_frame
		_check(hub.gear_list_scroll.scroll_vertical == list_offset and absf(hub.weapon_button.global_position.y - first_y) < 0.5, "selecting gear preserves the list position at a compact window size")
	hub._select_gear("W_ECHO")
	await process_frame
	var behavior_y: float = hub.mod_behavior_label.global_position.y
	var numeric_y: float = hub.mod_numeric_label.global_position.y
	for id in ["W_FLOW", "W_ECHO", "W_FLOW", "W_ECHO"]:
		hub._select_gear(id)
		await process_frame
		_check(absf(hub.mod_behavior_label.global_position.y - behavior_y) < 0.5 and absf(hub.mod_numeric_label.global_position.y - numeric_y) < 0.5, "switching attack gear preserves both option category positions")
	hub.profile.owned_gear["W_ECHO"] = true
	hub.profile.owned_mods.append("ECHO_WISP")
	hub._refresh()
	hub._slot_mod("ECHO_WISP")
	await process_frame
	_check(absf(hub.mod_behavior_label.global_position.y - behavior_y) < 0.5 and absf(hub.mod_numeric_label.global_position.y - numeric_y) < 0.5, "equipping a behavior option preserves category positions")
	for gear_id in RunProfile.GEAR_AFFIXES:
		hub._select_gear(gear_id)
		for mod_id in RunProfile.GEAR_AFFIXES[gear_id]:
			hub.profile.slotted_mods[gear_id] = mod_id
			hub._refresh()
			await process_frame
			_check(absf(hub.mod_behavior_label.global_position.y - behavior_y) < 0.5 and absf(hub.mod_numeric_label.global_position.y - numeric_y) < 0.5, "long option descriptions preserve equipment detail layout: %s" % mod_id)
	hub.profile.slotted_mods = {"W_ECHO": "ECHO_WISP"}
	_check(hub.growth_buttons.size() == 8, "attack, defense and mobility growth choices appear in the preparation screen")
	hub.tabs.current_tab = 2
	hub.profile.currency = 100
	hub._refresh()
	await process_frame
	var growth_scroll: ScrollContainer = hub.tabs.get_child(2)
	var growth_y: float = hub.growth_buttons.VITALITY.global_position.y
	var power: Button = hub.growth_buttons.POWER
	power.grab_focus()
	for rank in 2:
		power.pressed.emit()
		await process_frame
		_check(growth_scroll.scroll_vertical == 0 and absf(hub.growth_buttons.VITALITY.global_position.y - growth_y) < 0.5, "growth rank text changes do not shift the other category rows: rank %d / scroll %d / y %.1f → %.1f" % [rank + 1, growth_scroll.scroll_vertical, growth_y, hub.growth_buttons.VITALITY.global_position.y])
	hub.queue_free()
	await process_frame
	for prefix in [PROFILE, UNLOCKS]:
		for suffix in ["_a.json", "_b.json"]:
			var path := ProjectSettings.globalize_path(prefix + suffix)
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	if failures == 0: print("Hub layout verification passed: stable gear list and grouped growth")
	quit(1 if failures else 0)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)
