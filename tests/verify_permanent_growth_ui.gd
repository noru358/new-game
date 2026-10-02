extends SceneTree
## Run on the integrated ten-item catalog and hub mount, using fixture slots only.
var checks := 0
var failures := 0
var catalog: Script

func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func run():
	catalog = load("res://game/permanent_growth_catalog.gd")
	if catalog == null:
		printerr("Requires the integrated permanent-growth catalog and hub mount")
		quit(1)
		return
	for size in [Vector2i(960, 540), Vector2i(1280, 720)]: await inspect(size)
	check(checks >= 800, "all integrated catalog fixtures executed")
	print("Permanent growth UI: %d checks, %d failures, %s" % [checks, failures, DisplayServer.get_name()])
	quit(1 if failures else 0)

func inspect(size: Vector2i):
	root.size = size
	root.content_scale_size = size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var hub = load("res://game/hub.tscn").instantiate()
	var prefix := "user://growth_ui_%d_%d" % [size.x, Time.get_ticks_usec()]
	hub.profile_save_prefix = prefix
	hub.growth_save_prefix = prefix + "_unlocks"
	root.add_child(hub)
	current_scene = hub
	await process_frame
	await process_frame
	check(hub.growth_buttons.size() == 10, "ten existing growth choices mounted")
	await tab(hub.tabs, 2)
	check(hub.tabs.current_tab == 2, "growth tab mouse access")
	var groups: TabContainer = hub.growth_tabs
	hub.profile.currency = 1000
	hub.unlocks.lifetime_levelups = 0
	hub._refresh()
	for id in ["SLASH", "SLASH_POWER", "FINISH"]:
		var button: Button = hub.growth_buttons[id]
		check(button.disabled, id + " stays locked before actual unlock")
		check(button.text.contains("1회" if id != "FINISH" else "3회"), id + " exact unlock requirement")
	hub.unlocks.lifetime_levelups = 3
	for rank in range(6):
		for id in catalog.IDS: hub.profile.growth_ranks[id] = rank
		hub._refresh()
		for group_index in range(groups.get_tab_count()):
			await tab(groups, group_index)
			check(groups.current_tab == group_index, "growth category mouse access")
			var scroll := groups.get_child(group_index) as ScrollContainer
			for id in catalog.IDS:
				var button: Button = hub.growth_buttons[id]
				if not scroll.is_ancestor_of(button): continue
				scroll.ensure_control_visible(button)
				await process_frame
				await process_frame
				check(scroll.get_global_rect().encloses(button.get_global_rect()), "%s rank%d reachable in %d" % [id, rank, size.x])
				check(button.size.y + 0.5 >= button.get_minimum_size().y, id + " wrapped text fits button")
				check(button.text.contains("%d/5" % rank), id + " current rank and cap")
				check(button.text.contains(catalog.display_value(id, rank)), id + " actual catalog current effect")
				if rank < 5:
					check(button.text.contains(catalog.display_value(id, rank + 1)) and button.text.contains("→"), id + " actual next effect")
					check(button.text.contains("구매 %d" % RunProfile.GROWTH_COST[rank]), id + " next price")
					check(not button.disabled, id + " available while affordable")
				else:
					check(button.disabled and button.text.contains("최대") and not button.text.contains("구매"), id + " maximum has no sixth-stage price")
	# Real mouse and keyboard purchases at the newly supported stages.
	await tab(groups, 1)
	var recovery: Button = hub.growth_buttons.RECOVERY
	hub.profile.growth_ranks.RECOVERY = 2
	hub.profile.currency = 1000
	hub._refresh()
	var scroll := groups.get_child(1) as ScrollContainer
	scroll.ensure_control_visible(recovery)
	await process_frame
	await click(recovery.get_global_rect().get_center())
	check(hub.profile.growth_ranks.RECOVERY == 3 and hub.profile.currency == 940, "mouse buys exactly next stage and catalog price")
	hub.profile.growth_ranks.RECOVERY = 4
	hub._refresh()
	recovery.grab_focus()
	await process_frame
	await key(KEY_ENTER)
	check(hub.profile.growth_ranks.RECOVERY == 5 and hub.profile.currency == 800, "keyboard buys fifth stage for 140")
	var saved: Dictionary = hub.profile._snapshot()
	await key(KEY_ENTER)
	await click(recovery.get_global_rect().get_center())
	check(hub.profile._snapshot() == saved, "repeated activation at max does not spend or save")
	hub.profile.load_error = true
	hub._refresh()
	check(hub.growth_buttons.values().all(func(b): return b.disabled), "storage failure blocks every growth choice")
	hub.profile.load_error = false
	for id in catalog.IDS: hub.profile.growth_ranks[id] = 4
	hub._refresh()
	await tab(groups, 0)
	if DisplayServer.get_name() != "headless":
		var folder := OS.get_environment("GROWTH_UI_CAPTURE_DIR")
		if not folder.is_empty():
			DirAccess.make_dir_recursive_absolute(folder)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder.path_join("growth-%d.png" % size.x))
	hub.queue_free()
	await process_frame
	var camp = load("res://game/travel_camp.tscn").instantiate()
	camp.profile_save_prefix = prefix + "_camp"
	camp.growth_save_prefix = prefix + "_camp_unlocks"
	root.add_child(camp)
	current_scene = camp
	await process_frame
	camp.preparation.show()
	camp.preparation.open_section(2)
	await process_frame
	check(camp.preparation.tabs.current_tab == 2, "camp opens existing growth route")
	await key(KEY_ESCAPE)
	check(not camp.preparation.visible and not camp.settings_panel.is_open() and not paused, "Escape closes growth route and returns to camp")
	camp.queue_free()
	await process_frame
	for stem in [prefix, prefix + "_unlocks"]:
		for suffix in ["_a.json", "_b.json"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(stem + suffix))

func tab(container: TabContainer, index: int):
	await process_frame
	var bar := container.get_tab_bar()
	await click(bar.global_position + bar.get_tab_rect(index).get_center())

func click(point: Vector2):
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	event.button_mask = 0
	root.push_input(event, true)
	await process_frame

func key(code: Key):
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame
