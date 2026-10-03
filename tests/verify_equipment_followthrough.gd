extends SceneTree
## Synthetic settlement funds/access, real Hub mouse/Enter callbacks and failed writes.
## No natural-run, clear, or human-readability claim. Use isolated userdata.
var checks := 0
var failures := 0
var capture_dir := ""
var baseline := false

func _initialize(): call_deferred("_run")
func check(ok: bool, detail: String):
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", detail)

func _run():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): capture_dir = argument.trim_prefix("--capture-dir=")
		if argument == "--baseline-capture": baseline = true
	if not capture_dir.is_empty():
		check(DisplayServer.get_name() != "headless", "native display required for requested captures")
		DirAccess.make_dir_recursive_absolute(capture_dir)
	print("Equipment followthrough userdata: ", OS.get_user_data_dir(), " · synthetic settlement fixtures")
	for dimensions in [Vector2i(960, 540), Vector2i(1280, 720)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		for medium in [false, true]: await _case(dimensions, medium)
	print("Equipment followthrough: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _case(dimensions: Vector2i, medium: bool):
	var tag := "%s-%d" % ["medium" if medium else "fresh", dimensions.x]
	var stem := "user://equipment_followthrough_%s_%d" % [tag, Time.get_ticks_usec()]
	var scene = load("res://game/travel_camp.tscn").instantiate()
	scene.profile_save_prefix = stem
	scene.growth_save_prefix = stem + "_growth"
	root.add_child(scene)
	current_scene = scene
	var hub = scene.preparation
	var ui = hub.get_node("DeparturePreparationPresenter")
	hub.show()
	scene._update_prompt() # Same visibility refresh as camp's ordinary E-open path.
	hub.open_section(0)
	await process_frame
	await process_frame
	check(hub.profile.currency == 0 and hub.profile.owned_gear.is_empty() and not hub.profile.temple_owned, tag + " starts genuinely fresh before fixture")
	check(not hub.currency_label.is_visible_in_tree() and not ui.purchase_explanation.is_visible_in_tree(), tag + " departure retains concise first page")
	if not medium: await _capture(tag + "-departure")
	# Minimal synthetic funds: retreat 30 pays24; first-clear0 pays50 and unlocks W_FLOW.
	check(hub.profile.settle(tag + "-fixture", "SUCCESS" if medium else "RETREAT", 0 if medium else 30), tag + " state-contract settlement fixture saves")
	hub._refresh()
	await _tab(hub, 1)
	var selection: Button = hub.weapon_button if medium else hub.accessory_button
	hub.gear_list_scroll.ensure_control_visible(selection)
	await process_frame
	await process_frame
	await _click(selection)
	var id := "W_FLOW" if medium else "A_EMBER"
	check(hub.selected_gear_id == id, tag + " real mouse selects exact gear")
	if not baseline:
		check(ui.purchase_explanation.get_index() + 1 == hub.gear_action_button.get_index(), tag + " reused line sits immediately above action")
		check(ui.purchase_explanation.text.contains("구매 뒤 별도 장착"), tag + " pre-purchase distinguishes ownership and equip")
	var before: Dictionary = hub.profile._snapshot()
	var bank: int = hub.profile.currency
	# Fail purchase via a nonexistent fixture-only directory; memory and CTA stay uncommitted.
	hub.profile.save_prefix = stem + "_missing/profile"
	await _action(hub)
	check(hub.profile._snapshot() == before and hub.status_label.text.contains("실패"), tag + " failed buy never grants ownership or changes bank")
	ui.refresh()
	check(hub.status_label.text.contains("실패"), tag + " presenter preserves authoritative failure notice")
	hub.profile.save_prefix = stem
	await _action(hub)
	check(hub.profile.owned_gear.has(id) and hub.profile.currency == bank - RunProfile.GEAR_COST[id], tag + " purchase costs once")
	check(hub.profile.equipped_weapon == "W_START" and hub.profile.equipped_accessory.is_empty(), tag + " purchase does not equip")
	if not baseline:
		check(hub.gear_action_button.text == RunProfile.gear_name(id) + " 장착" and ui.purchase_explanation.text.contains("아래 장착 버튼"), tag + " next CTA names the owned gear")
		_assert_action_layout(hub, ui, tag + " owned")
	await _capture(tag + "-owned")
	before = hub.profile._snapshot()
	hub.profile.save_prefix = stem + "_missing/profile"
	await _action(hub)
	check(hub.profile._snapshot() == before and hub.status_label.text.contains("실패"), tag + " failed equip never claims applied gear")
	if not baseline: check(ui.purchase_explanation.text.contains("보유 중"), tag + " failed equip keeps pending instruction")
	hub.profile.save_prefix = stem
	hub.gear_action_button.grab_focus()
	await _key(KEY_ENTER)
	check(hub.profile.equipped_weapon == id if medium else hub.profile.equipped_accessory == id, tag + " actual focused Enter equips")
	check(hub.profile.currency == bank - RunProfile.GEAR_COST[id], tag + " equip is free")
	if not baseline: check(ui.purchase_explanation.text == "장착됨 · 출정 탭에서 시작", tag + " committed equip points to existing departure tab")
	if not baseline: _assert_action_layout(hub, ui, tag + " equipped")
	await _capture(tag + "-equipped")
	var generation: int = hub.profile.generation
	before = hub.profile._snapshot()
	for repeat in 4: ui.refresh()
	check(hub.profile._snapshot() == before and hub.profile.generation == generation, tag + " presenter refresh performs no writes")
	# Existing repeated action semantics stay toggle-off/toggle-on; never rebuy.
	await _action(hub)
	await _action(hub)
	check(hub.profile.currency == bank - RunProfile.GEAR_COST[id] and hub.profile.owned_gear.has(id), tag + " repeated actions preserve bank and ownership")
	check(hub.profile.equipped_weapon == id if medium else hub.profile.equipped_accessory == id, tag + " existing repeated toggle behavior preserved")
	await _tab(hub, 0)
	check((ui.weapon.text if medium else ui.accessory.text).contains(RunProfile.gear_name(id)) and hub.start_button.is_visible_in_tree(), tag + " actual departure tab shows applied loadout and start")
	await _key(KEY_ESCAPE)
	check(not hub.visible and not scene.settings_panel.is_open(), tag + " back closes preparation without opening settings")
	scene.queue_free()
	await process_frame
	# A fresh scene reload is independent from a presenter refresh; not a process restart.
	var restarted = load("res://game/hub.tscn").instantiate()
	restarted.profile_save_prefix = stem
	restarted.growth_save_prefix = stem + "_growth"
	root.add_child(restarted)
	current_scene = restarted
	await process_frame
	check(restarted.profile.currency == bank - RunProfile.GEAR_COST[id] and restarted.profile.owned_gear.has(id), tag + " ordinary reload retains exact purchase ledger")
	check(restarted.profile.equipped_weapon == id if medium else restarted.profile.equipped_accessory == id, tag + " reload retains actual equipment")
	restarted.profile.load_error = true
	restarted._refresh()
	await process_frame
	check(restarted.gear_action_button.disabled and restarted.start_button.disabled and restarted.status_label.text.contains("저장"), tag + " existing save block gates survive")
	restarted.queue_free()
	paused = false
	await process_frame
	for prefix in [stem, stem + "_growth"]:
		for suffix in ["_a.json", "_b.json"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(prefix + suffix))

func _action(hub):
	hub.gear_list_scroll.ensure_control_visible(hub.gear_action_button)
	await process_frame
	await process_frame
	await _click(hub.gear_action_button)
func _assert_action_layout(hub, ui, tag):
	for control in [ui.purchase_explanation, hub.gear_action_button]:
		check(hub.gear_list_scroll.get_global_rect().encloses(control.get_global_rect()), tag + " line and action remain in visible scroll area")
	check(ui.purchase_explanation.get_line_count() <= ui.purchase_explanation.get_visible_line_count(), tag + " instruction lines do not clip")
	check(hub.gear_action_button.get_minimum_size().y <= hub.gear_action_button.size.y, tag + " named action fits button height")
	check(not ui.purchase_explanation.get_global_rect().intersects(hub.gear_action_button.get_global_rect()), tag + " instruction and button do not overlap")
func _tab(hub, index):
	await process_frame
	var bar: TabBar = hub.tabs.get_tab_bar()
	await _point(bar.global_position + bar.get_tab_rect(index).get_center())
func _click(control):
	await process_frame
	await process_frame
	await _point(control.get_global_rect().get_center())
func _point(point: Vector2):
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(event, true)
		await process_frame
	await process_frame
func _key(code):
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await process_frame
func _capture(tag):
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var capture := root.get_texture().get_image()
	check(capture.save_png(capture_dir.path_join(tag + ".png")) == OK, "native capture saved " + tag)
