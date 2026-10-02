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
	_check(hub.gear_list_scroll != hub.gear_detail_scroll and hub.gear_detail_column.is_ancestor_of(hub.gear_effects_label) and hub.gear_detail_column.is_ancestor_of(hub.gear_detail_scroll), "gear effect, awakening and option choices share one visible detail column")
	var option_panel: Control = hub.gear_detail_scroll.get_child(0)
	_check(option_panel.size.y <= hub.gear_detail_scroll.size.y and hub.mod_preview_label.global_position.y + hub.mod_preview_label.size.y <= hub.tabs.global_position.y + hub.tabs.size.y, "all four option rows and the selected description fit at 960×540")
	for style_name in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var style: StyleBox = hub.weapon_button.get_theme_stylebox(style_name)
		_check(style.get_content_margin(SIDE_LEFT) == 12.0 and style.get_content_margin(SIDE_TOP) == 12.0 and style.get_content_margin(SIDE_RIGHT) == 12.0 and style.get_content_margin(SIDE_BOTTOM) == 12.0, "button %s keeps the same content margins" % style_name)
	var pressed_style: StyleBoxFlat = hub.weapon_button.get_theme_stylebox("pressed")
	_check(pressed_style.bg_color == (hub.weapon_button.get_theme_stylebox("hover") as StyleBoxFlat).bg_color, "pressing keeps the hovered background color")
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
	hub.mod_buttons["WIDE"].pressed.emit()
	_check(hub.mod_preview_label.text.begins_with(RunProfile.affix_description("WIDE")) and hub.profile.mod_for("W_ECHO").is_empty(), "an unowned option can be selected for its full description without equipping it")
	var behavior_y: float = hub.mod_behavior_label.global_position.y
	var numeric_y: float = hub.mod_numeric_label.global_position.y
	for id in ["W_FLOW", "W_ECHO", "W_FLOW", "W_ECHO"]:
		hub._select_gear(id)
		await process_frame
		_check(absf(hub.mod_behavior_label.global_position.y - behavior_y) < 0.5 and absf(hub.mod_numeric_label.global_position.y - numeric_y) < 0.5, "switching attack gear preserves both option category positions")
	hub.profile.owned_gear["W_ECHO"] = true
	hub.profile.owned_mods.append("ECHO_WISP")
	hub._refresh()
	hub.gear_detail_scroll.scroll_vertical = 100
	await process_frame
	var detail_offset: int = hub.gear_detail_scroll.scroll_vertical
	hub.mod_buttons["ECHO_WISP"].grab_focus()
	hub._slot_mod("ECHO_WISP")
	await process_frame
	_check(hub.gear_detail_scroll.scroll_vertical == detail_offset and absf(hub.mod_behavior_label.global_position.y - (behavior_y - detail_offset)) < 0.5 and absf(hub.mod_numeric_label.global_position.y - (numeric_y - detail_offset)) < 0.5, "equipping a behavior option preserves the scrolled detail position")
	hub.gear_detail_scroll.scroll_vertical = 0
	await process_frame
	for gear_id in RunProfile.GEAR_AFFIXES:
		hub._select_gear(gear_id)
		await process_frame
		_check(hub.gear_effects_label.get_content_height() <= hub.gear_effects_label.size.y + 1.0, "equipment effects remain readable above option controls: %s" % gear_id)
		var gear_behavior_y: float = hub.mod_behavior_label.global_position.y
		var gear_numeric_y: float = hub.mod_numeric_label.global_position.y
		_check(hub.gear_detail_scroll.get_child(0).size.y <= hub.gear_detail_scroll.size.y, "all %s option rows fit without scrolling" % gear_id)
		for mod_id in RunProfile.GEAR_AFFIXES[gear_id]:
			hub.profile.slotted_mods[gear_id] = mod_id
			hub._refresh()
			await process_frame
			_check(absf(hub.mod_behavior_label.global_position.y - gear_behavior_y) < 0.5 and absf(hub.mod_numeric_label.global_position.y - gear_numeric_y) < 0.5, "long option descriptions preserve equipment detail layout: %s" % mod_id)
			hub._preview_mod(mod_id)
			_check(hub.mod_preview_label.text.begins_with(RunProfile.affix_description(mod_id)) and hub.mod_preview_label.text.contains(RunProfile.affix_source(mod_id)), "compact option keeps the full %s description in its preview" % mod_id)
	hub.profile.slotted_mods = {"W_ECHO": "ECHO_WISP"}
	_check(hub.growth_buttons.size() == PermanentGrowthCatalog.IDS.size(), "all ten attack, defense and mobility growth choices appear in the preparation screen")
	hub.tabs.current_tab = 2
	hub.profile.currency = 100
	hub._refresh()
	await process_frame
	var growth_scroll: ScrollContainer = hub.growth_tabs.get_child(0)
	var growth_y: float = hub.growth_buttons.WISP.global_position.y
	var power: Button = hub.growth_buttons.POWER
	power.grab_focus()
	for rank in 2:
		power.pressed.emit()
		await process_frame
		_check(growth_scroll.scroll_vertical == 0 and absf(hub.growth_buttons.WISP.global_position.y - growth_y) < 0.5, "growth rank text changes do not shift the other category rows: rank %d / scroll %d / y %.1f → %.1f" % [rank + 1, growth_scroll.scroll_vertical, growth_y, hub.growth_buttons.WISP.global_position.y])
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
