extends SceneTree
## Uses real settlement, failed writes, retry callbacks, and scene input.
## Combat values are fixtures; this is not a normal-run or balance test.

const Presenter = preload("res://game/run_result_presenter.gd")
const CASES := ["temple_first", "jungle_first", "repeat_option", "repeat_equipped", "death", "retreat", "save_retry"]
var checks := 0
var failures := 0
var capture_dir := ""

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _run() -> void:
	var normal_before := _normal_slots()
	capture_dir = OS.get_environment("RESULT_CLARITY_CAPTURE_DIR")
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	for dimensions in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = dimensions
		root.content_scale_size = Vector2i(1280, 720)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		for sample in CASES:
			await _case(sample, dimensions)
		await _corrupt_startup(dimensions)
	check(_normal_slots() == normal_before, "regular profile/unlock slots preserve bytes or absence")
	print("Result clarity: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _case(sample: String, dimensions: Vector2i) -> void:
	var tag := "%s-%dx%d" % [sample, dimensions.x, dimensions.y]
	var stem := "user://verify_result_clarity_" + tag
	_erase(stem)
	var profile := RunProfile.new()
	profile.save_prefix = stem
	profile.currency = 75
	if sample == "jungle_first" or sample.begins_with("repeat"):
		profile.owned_outpost_ids.append(RunProfile.TEMPLE_REGION)
	if sample.begins_with("repeat"):
		profile.owned_mods.assign(RunProfile.REGION_MODS[RunProfile.TEMPLE_REGION])
		profile.owned_mods.erase("WEAVE" if sample == "repeat_equipped" else "EMBER_STEP")
		if sample == "repeat_equipped":
			profile.owned_gear["W_FLOW"] = true
			profile.equipped_weapon = "W_FLOW"
	check(profile._commit(profile._snapshot()), tag + " fixture profile saves")
	var scene = load("res://game/jungle_pass.tscn" if sample == "jungle_first" else "res://game/hybrid_region.tscn").instantiate()
	scene.profile_save_prefix = stem
	scene.growth_save_prefix = stem + "_growth"
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene._set_paused(false)
	scene.set_process(false)
	scene.set_physics_process(false)
	scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
	if not scene.result_overlay.has_node("ResultQuit"):
		for child in scene.result_overlay.get_children():
			if child is Button and child.text == "게임 종료": child.name = "ResultQuit"
	scene.run_time = 305.5
	scene.kills = 67
	scene.run_currency = 111
	var result := "DEFEAT" if sample == "death" else "RETREAT" if sample == "retreat" else "SUCCESS"
	var expected_award := 55 if result == "DEFEAT" else 88 if result == "RETREAT" else 131 if sample.begins_with("repeat") else 161
	var generation: int = scene.profile.generation
	if sample == "save_retry":
		# A stale prior receipt must never leak into a failed settlement.
		scene.profile.last_award = 999
		scene.profile.last_first_clear = true
		scene.profile.last_mod_award = "WEAVE"
		scene.profile.save_prefix = "user://verify_result_absent_%d/profile" % Time.get_ticks_usec()
	scene._finish_run(result)
	if result == "RETREAT":
		check(scene.result_overlay.visible and scene.ending_remaining == 0, tag + " retreat keeps immediate result timing")
	else:
		check(not scene.result_overlay.visible and is_equal_approx(scene.ending_remaining, 0.8), tag + " non-retreat keeps 0.8-second ending")
		scene._process(0.79)
		check(not scene.result_overlay.visible, tag + " result stays hidden before ending completes")
		scene._process(0.02)
		check(scene.result_overlay.visible and scene.ending_remaining == 0, tag + " result appears after existing ending")
	if sample == "temple_first" and not scene.has_node("RunResultPresenter"):
		await _capture(tag + "-before")
	_present(scene)
	await process_frame
	await process_frame
	var ui = scene.get_node("RunResultPresenter")
	_assert_layout(scene, ui, tag)
	check(scene.result_text.visible == false and ui.heading.is_visible_in_tree(), tag + " visible presenter replaces only legacy text")
	if sample == "save_retry":
		check(scene.settlement_pending and scene.profile.currency == 75 and scene.profile.generation == generation, tag + " failed settlement does not credit memory")
		check(scene.replay_button.disabled and scene.retry_button.visible and not scene.retry_button.disabled, tag + " failure blocks camp and keeps retry actionable")
		check(ui.award_value.text == "정산 저장 대기" and not ui.award_caption.text.contains("저장 완료 ·") and ui.breakdown.text.contains("미확정"), tag + " visible reward is explicitly unconfirmed")
		check(ui.outcome_details.text.contains("미저장 화폐가 사라집니다") and not ui.outcome_details.text.contains("구매 가능"), tag + " visible warning replaces all unlock claims")
		await _capture(tag + "-pending")
		await _key(KEY_R)
		await _click(scene.replay_button)
		check(current_scene == scene, tag + " keyboard and disabled mouse return remain blocked")
		await _click(scene.retry_button)
		_present(scene)
		check(scene.settlement_pending and scene.profile.currency == 75, tag + " failed mouse retry preserves uncredited state")
		scene.profile.save_prefix = stem
		scene.retry_button.grab_focus()
		await _key(KEY_ENTER)
		_present(scene)
		check(not scene.settlement_pending and scene.profile.currency == 75 + expected_award, tag + " focused Enter retries actual settlement once")
		check(not scene.replay_button.disabled and not scene.retry_button.visible and ui.award_value.text == "+161" and ui.award_caption.text.contains("저장 완료"), tag + " retry replaces pending visuals with confirmed banked award")
		await _capture(tag + "-recovered")
		var retry_generation: int = scene.profile.generation
		for i in 2: await _click(scene.retry_button)
		check(scene.profile.currency == 75 + expected_award and scene.profile.generation == retry_generation, tag + " repeated clicks at the now-hidden retry target cannot double-credit")
	else:
		check(not scene.settlement_pending and scene.profile.last_award == expected_award and scene.profile.currency == 75 + expected_award, tag + " authoritative net settlement is unchanged")
		check(ui.award_value.text == "+%d" % expected_award and ui.bank_total.text.ends_with(str(75 + expected_award)), tag + " visible net award and bank total use committed profile values")
		check(ui.breakdown.text.contains("획득 111") and ui.breakdown.text.contains("손실 %d" % scene.profile.last_lost), tag + " visible breakdown keeps earned and loss distinct")
		if sample.ends_with("first"):
			var gear: String = RunProfile.REGION_GEAR[scene.region_id]
			check(ui.outcome_details.text.contains(RunProfile.gear_name(gear)) and ui.outcome_details.text.contains("구매 가능 (%d 화폐)" % RunProfile.GEAR_COST[gear]), tag + " first clear names the exact newly available gear and price")
			check(not scene.profile.owned_gear.has(gear) and scene.profile.equipped_weapon == "W_START" and ui.next_action.text.contains("구매 → 장착"), tag + " availability never claims ownership or automatic equip")
			check(ui.outcome_details.text.contains("정글 절벽 관문") == (sample == "temple_first"), tag + " only temple first clear shows its newly available next region")
		elif sample.begins_with("repeat"):
			var mod_id: String = scene.profile.last_mod_award
			var gear := RunProfile.gear_for_affix(mod_id)
			check(ui.outcome_heading.text.contains(RunProfile.gear_name(gear)) and ui.outcome_details.text.contains(RunProfile.affix_description(mod_id)), tag + " visible repeat reward preserves full gear-specific affix text")
			check(ui.next_action.text.contains("구매·장착") == (sample == "repeat_option"), tag + " option next action respects actual gear ownership")
			if sample == "repeat_option":
				scene.profile.owned_gear[gear] = true
				check(Presenter.result_data(scene).next_action.contains("장착 후") and not Presenter.result_data(scene).next_action.contains("구매"), tag + " owned but unequipped option points to equip without a second purchase")
				scene.profile.owned_gear.erase(gear)
		else:
			check(not ui.outcome_details.text.contains("구매 가능") and ui.next_action.text.contains("다시 출정"), tag + " ordinary result offers preparation without false unlocks")
		await _capture(tag + "-after")
	var banked: int = scene.profile.currency
	var saved_generation: int = scene.profile.generation
	for i in 3:
		scene._retry_settlement()
		scene._finish_run(result)
		scene._show_result()
		_present(scene)
	check(scene.profile.currency == banked and scene.profile.generation == saved_generation, tag + " repeated retry/finish/presentation cannot duplicate credit")
	var disk := RunProfile.new()
	disk.save_prefix = stem
	disk.load_state()
	check(not disk.load_error and disk.currency == banked and disk.last_run_id == scene.run_id, tag + " confirmed result survives disk reload")
	if sample == "save_retry":
		await _click(scene.replay_button)
		await process_frame
		check(current_scene != scene and not paused, tag + " restored return mouse action reaches camp")
		if current_scene != null: current_scene.queue_free()
	elif sample == "temple_first":
		await _key(KEY_R)
		await process_frame
		check(current_scene != scene and not paused, tag + " confirmed result keeps keyboard R return to camp")
		if current_scene != null: current_scene.queue_free()
	else:
		scene.queue_free()
	paused = false
	await process_frame
	await process_frame
	_erase(stem)

func _present(scene) -> void:
	check(scene.has_node("RunResultPresenter"), "integrated _show_result mounted presenter")
	if scene.has_node("RunResultPresenter"):
		var ui = scene.get_node("RunResultPresenter")
		var expected := Presenter.result_data(scene)
		check(ui.award_value.text == expected.award_value and ui.outcome_details.text == expected.outcome_details, "integrated show/retry refreshed visible labels without test assistance")

func _assert_layout(scene, ui, tag: String) -> void:
	for label in ui.labels:
		check(label.is_visible_in_tree() and label.get_line_count() <= label.get_visible_line_count(), tag + " visible label has no clipped lines: " + label.name)
		check(Rect2(0, 0, 1280, 720).encloses(label.get_global_rect()), tag + " label remains in canvas: " + label.name)
		check(label.mouse_filter == Control.MOUSE_FILTER_IGNORE and label.focus_mode == Control.FOCUS_NONE, tag + " text cannot intercept controls: " + label.name)
	check(not ui.outcome_details.get_global_rect().intersects(ui.next_action.get_global_rect()), tag + " details and next action stay separate")
	check(not ui.next_action.get_global_rect().intersects(scene.retry_button.get_global_rect()), tag + " next action leaves retry button clear")
	check(not scene.replay_button.get_global_rect().intersects(scene.result_overlay.get_node("ResultQuit").get_global_rect()), tag + " return and quit targets do not overlap")

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func _click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func _capture(label: String) -> void:
	if capture_dir.is_empty(): return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(not image.is_empty(), "actual GL capture " + label)
	if not image.is_empty(): check(image.save_png(capture_dir.path_join(label + ".png")) == OK, "saved capture " + label)

func _erase(stem: String) -> void:
	for prefix in [stem, stem + "_growth"]:
		for suffix in ["_a.json", "_b.json"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(prefix + suffix))

func _normal_slots() -> Dictionary:
	var records := {}
	for stem in ["user://loop_conquest_profile", "user://loop_conquest_1d_unlocks"]:
		for suffix in ["_a.json", "_b.json"]:
			var path: String = stem + suffix
			records[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
	return records

func _corrupt_startup(dimensions: Vector2i) -> void:
	var stem := "user://verify_result_corrupt_%d" % dimensions.x
	_erase(stem)
	for suffix in ["_a.json", "_b.json"]:
		var file := FileAccess.open(stem + suffix, FileAccess.WRITE)
		file.store_string("{invalid fixture")
		file.close()
	var scene = load("res://game/hybrid_region.tscn").instantiate()
	scene.profile_save_prefix = stem
	scene.growth_save_prefix = stem + "_growth"
	root.add_child(scene)
	current_scene = scene
	await process_frame
	check(scene.profile.load_error and scene.result_overlay.visible and scene.result_text.visible and scene.result_text.text.contains("기록과 정상 백업"), "startup corrupt-save warning retains its original visible text")
	check(not scene.has_node("RunResultPresenter") and scene.save_folder_button.visible and scene.replay_button.disabled, "startup recovery controls bypass run-result presentation")
	scene.queue_free()
	paused = false
	await process_frame
	await process_frame
	_erase(stem)
