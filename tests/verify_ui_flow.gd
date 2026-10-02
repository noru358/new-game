extends SceneTree
## Isolated fixtures only. Test mounts helpers without owning shared scenes.
const Prepare = preload("res://game/departure_preparation_presenter.gd")
const Hud = preload("res://game/run_flow_hud_presenter.gd")
var checks := 0
var failures := 0
func _initialize(): call_deferred("_run")
func check(value: bool, detail: String):
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", detail)
func _run():
	print("UI flow fixture userdata: ", OS.get_user_data_dir())
	for dimensions in [Vector2i(960, 540), Vector2i(1280, 720)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await _preparation(dimensions)
		await _camp_back(dimensions)
		root.content_scale_size = Vector2i(1280, 720)
		for region in ["temple", "jungle"]: await _hud(region, dimensions)
	print("UI flow: %d checks, %d failures, %s" % [checks, failures, DisplayServer.get_name()])
	quit(1 if failures else 0)
func _preparation(dimensions: Vector2i):
	_erase("user://flow_hub_%d" % dimensions.x)
	var scene = load("res://game/hub.tscn").instantiate()
	scene.profile_save_prefix = "user://flow_hub_%d" % dimensions.x
	scene.growth_save_prefix = scene.profile_save_prefix + "_growth"
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var before: Dictionary = scene.profile._snapshot()
	var presenter = scene.get_node_or_null("DeparturePreparationPresenter")
	check(presenter != null, "real preparation mounts new presenter")
	if presenter == null: await _release(scene); return
	await process_frame
	await process_frame
	check(scene.profile._snapshot() == before, "preparation mounting is read-only")
	_check_layout(presenter.summary, dimensions)
	check(not scene.supply_buy_button.is_visible_in_tree() and not scene.canal_trial_button.is_visible_in_tree(), "optional purchases and development entry absent from departure")
	check(not scene.currency_label.visible and not scene.progress_label.is_visible_in_tree(), "currency and reward detail absent from departure")
	await _tab(scene, 1)
	check(scene.tabs.current_tab == 1, "equipment tab remains accessible by mouse")
	await _tab(scene, 2)
	check(scene.tabs.current_tab == 2, "growth tab remains accessible by mouse")
	scene.open_section(0)
	presenter.refresh()
	check(scene.start_button.visible and not scene.start_button.disabled, "one existing departure action remains available")
	check(scene.jungle_region_button.disabled, "fresh jungle remains locked")
	scene.selected_region_id = RunProfile.JUNGLE_REGION
	scene._refresh()
	presenter.refresh()
	check(scene.start_button.disabled and presenter.gate_reason.text.contains("첫 성공"), "locked departure shows exact reason")
	scene.selected_region_id = RunProfile.TEMPLE_REGION
	scene.profile.load_error = true
	scene._refresh()
	presenter.refresh()
	check(scene.start_button.disabled and scene.status_label.text.contains("저장"), "load error blocks departure near action")
	scene.profile.load_error = false
	scene.profile.currency = 100
	scene.profile.owned_outpost_ids.append(RunProfile.TEMPLE_REGION)
	scene._select_gear("W_FLOW")
	scene._gear_action()
	presenter.refresh()
	check(scene.profile.owned_gear.has("W_FLOW") and scene.profile.equipped_weapon == "W_START", "buy creates ownership without equipping")
	check(presenter.weapon.text.contains("기본 마력장") and not presenter.weapon.text.contains("흐름의 마력장"), "owned-only weapon absent from applied loadout")
	scene._gear_action()
	presenter.refresh()
	check(scene.profile.equipped_weapon == "W_FLOW" and presenter.weapon.text.contains("흐름의 마력장"), "explicit equip updates loadout")
	var bank: int = scene.profile.currency
	for i in 3:
		await _tab(scene, 0)
		await _tab(scene, 1)
	check(scene.profile.currency == bank and scene.profile.equipped_weapon == "W_FLOW", "repeated shortcut does not buy/equip")
	scene.open_section(0)
	await process_frame
	await process_frame
	_check_layout(presenter.summary, dimensions)
	await _tab(scene, 1)
	scene.gear_list_scroll.ensure_control_visible(scene.supply_buy_button)
	await _click(scene.supply_buy_button)
	check(scene.profile.supply_count == 1 and scene.profile.currency == bank - RunProfile.SUPPLY_COST, "moved supply purchase remains accessible and costs exactly once")
	check(scene.profile.supply_selected, "supply purchase retains existing selection rule")
	scene.gear_list_scroll.ensure_control_visible(scene.supply_toggle_button)
	await _click(scene.supply_toggle_button)
	check(not scene.profile.supply_selected, "moved supply choice remains accessible")
	var supply_bank: int = scene.profile.currency
	for i in 2: await _click(scene.supply_toggle_button)
	check(not scene.profile.supply_selected and scene.profile.currency == supply_bank, "repeated supply selection changes no currency")
	await _click(scene.supply_toggle_button)
	await _tab(scene, 3)
	check(scene.canal_trial_button.is_visible_in_tree() and scene.progress_label.is_visible_in_tree(), "reward and developer paths survive in supplementary tab")
	await _tab(scene, 0)
	presenter.refresh()
	check(presenter.supply_summary.visible and presenter.supply_summary.text.contains("사용"), "selected supply exception shown on departure")
	await _capture("preparation-%d" % dimensions.x)
	await _release(scene)
func _camp_back(dimensions: Vector2i):
	var scene = load("res://game/travel_camp.tscn").instantiate()
	scene.profile_save_prefix = "user://flow_camp_%d" % dimensions.x
	scene.growth_save_prefix = scene.profile_save_prefix + "_growth"
	root.add_child(scene)
	current_scene = scene
	await process_frame
	check(scene.preparation.get_node_or_null("DeparturePreparationPresenter") != null, "real camp mounts preparation presenter")
	scene.preparation.show()
	await process_frame
	await _key(KEY_ESCAPE)
	check(not scene.preparation.visible and not scene.settings_panel.is_open(), "camp Back closes preparation without opening settings")
	scene.preparation.show()
	await process_frame
	var footer = scene.preparation.start_button.get_parent()
	var back: Button
	for item in footer.get_children():
		if item is Button and item.text.begins_with("야영지로 돌아가기"): back = item
	check(back != null, "existing camp Back action survives")
	await _click(back)
	check(not scene.preparation.visible, "camp mouse Back closes preparation")
	await _release(scene)
func _hud(region: String, dimensions: Vector2i):
	var scene = load("res://game/jungle_pass.tscn" if region == "jungle" else "res://game/hybrid_region.tscn").instantiate()
	scene.profile_save_prefix = "user://flow_%s_%d" % [region, dimensions.x]
	scene.growth_save_prefix = scene.profile_save_prefix + "_growth"
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene.set_physics_process(false)
	scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
	scene._set_paused(false)
	scene._update_hud()
	scene._update_run_hud()
	var before: Dictionary = scene.profile._snapshot()
	var presenter = scene.get_node_or_null("RunFlowHudPresenter")
	check(presenter != null, "real region mounts new HUD")
	if presenter == null: await _release(scene); return
	await process_frame
	await process_frame
	check(scene.profile._snapshot() == before, "HUD mounting is read-only")
	check(not scene.run_hud.visible and not scene.temple_section.section_hud.visible, "one destination readout replaces duplicates")
	check(presenter.objective.text.is_empty() and not presenter.objective.visible and not presenter.help.visible, "free exploration has no permanent goal or control help")
	check(presenter.boss_clock.visible and presenter.boss_clock.text.begins_with("보스까지"), "boss countdown remains visible during free exploration")
	for item in presenter.passive_controls:
		check(item.mouse_filter == Control.MOUSE_FILTER_IGNORE and item.focus_mode == Control.FOCUS_NONE, "HUD input transparent")
		if item.visible: check(Rect2(0,0,1280,720).encloses(item.get_global_rect()), "HUD fits scaled canvas")
	for label in [presenter.health, presenter.mobility, presenter.objective, presenter.progress, presenter.help]:
		check(label.get_line_count() <= label.get_visible_line_count(), "all HUD text visible")
	scene.growth.unlock_notice = "이동 베기 영구 습득 · Space"
	scene.profile.recovered_backup = true
	presenter.refresh()
	check(presenter.notice.text.contains("영구 습득") and presenter.notice.text.contains("복구"), "unlock and recovery notifications survive")
	scene.temple_section.boss_ready = true
	scene.temple_section._update_hud()
	presenter.refresh()
	check(not presenter.objective.text.contains("보스까지") and (presenter.objective.text.contains("성소") or presenter.objective.text.contains("관문")), "section ready state replaces countdown")
	scene.temple_section.in_garden = true
	scene.temple_section.garden_message = "보상을 저장하지 못했습니다 · 실패"
	scene.temple_section._update_hud()
	presenter.refresh()
	check(presenter.notice.text.contains("실패"), "garden save failure never hidden")
	presenter._process(8.0)
	check(presenter.notice.text.contains("실패"), "save failure persists until resolved")
	scene.temple_section.in_garden = false
	scene.temple_section.garden_message = ""
	scene.temple_section._update_hud()
	await _key(KEY_ESCAPE)
	check(paused and scene.pause_menu.visible, "Esc pauses")
	var clock: float = scene.run_time
	await create_timer(0.05, true).timeout
	check(scene.run_time == clock, "pause freezes runtime")
	await _key(KEY_ESCAPE)
	check(not paused and not scene.pause_menu.visible, "Esc resumes")
	await _key(KEY_TAB)
	check(scene.overview, "map opens")
	await _key(KEY_TAB)
	check(not scene.overview, "map returns")
	await _key(KEY_G)
	check(scene.retreat_overlay.visible and paused, "retreat modal opens")
	await _key(KEY_ESCAPE)
	check(not scene.retreat_overlay.visible and not paused, "back cancels retreat")
	scene.growth.unlock_notice = ""
	scene.profile.recovered_backup = false
	scene._spawn_now(scene.temple_section.boss_point, TrainingEnemy.Role.BEAST, true)
	scene.temple_section.boss_active = true
	scene.temple_section.boss_entered = true
	scene.boss.phase = 2
	scene.boss.recovery_time = 0.6
	scene.teleport(scene.temple_section.boss_point + Vector2(180, 180))
	scene._update_run_hud()
	scene.temple_section._update_hud()
	presenter.refresh()
	check(not presenter.boss_title.visible and scene.boss_health_bar.visible and presenter.objective.text.contains(scene.boss_name), "single boss identity above HP replaces encounter rules")
	check(presenter.objective.get_global_rect().end.y < scene.boss_health_bar.get_global_rect().position.y, "single boss identity and HP never overlap")
	presenter._process(8.0)
	check(not presenter.notice.visible, "resolved transient notices expire and do not republish")
	check(not presenter.progress.text.contains("화폐"), "combat progression omits currency")
	await _capture("combat-%s-%d" % [region, dimensions.x])
	await _release(scene)
func _tab(scene: Control, index: int):
	await process_frame
	var bar: TabBar = scene.tabs.get_tab_bar()
	await _click_point(bar.global_position + bar.get_tab_rect(index).get_center())
func _click(control: Control):
	await process_frame
	await process_frame
	await _click_point(control.get_global_rect().get_center())
func _click_point(point: Vector2):
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = motion.position
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	event.button_mask = 0
	root.push_input(event, true)
	await process_frame
func _erase(prefix: String):
	for stem in [prefix, prefix + "_growth"]:
		for suffix in ["_a.json", "_b.json"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(stem + suffix))
func _key(code: Key):
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
func _check_layout(control: Control, dimensions: Vector2i):
	check(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(control.get_global_rect()), "preparation summary fits actual viewport")
	for item in control.get_children():
		if item is Label and item.is_visible_in_tree(): check(item.get_line_count() <= item.get_visible_line_count(), "preparation text visible")
func _capture(tag: String):
	if DisplayServer.get_name() == "headless": return
	var folder := OS.get_environment("UI_FLOW_CAPTURE_DIR")
	if folder.is_empty(): return
	DirAccess.make_dir_recursive_absolute(folder)
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder.path_join(tag + ".png")) == OK, "native UI capture saved")
func _release(scene: Node):
	paused = false
	scene.queue_free()
	await process_frame
	await process_frame
