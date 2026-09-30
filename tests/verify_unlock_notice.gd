extends SceneTree

const PROFILE := "user://verify_unlock_notice_profile"
const UNLOCKS := "user://verify_unlock_notice_unlocks"
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _scene():
	var scene = load("res://game/hybrid_region.tscn").instantiate()
	scene.profile_save_prefix = PROFILE
	scene.growth_save_prefix = UNLOCKS
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
	scene.growth.rng.seed = 286
	return scene


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


func _cleanup() -> void:
	for prefix in [PROFILE, UNLOCKS]:
		for suffix in ["_a.json", "_b.json"]:
			var path := ProjectSettings.globalize_path(prefix + suffix)
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)


func _run() -> void:
	_cleanup()
	var scene = await _scene()
	var growth: RunGrowth = scene.growth
	scene.player.health = 10.0
	growth.gain_xp(8)
	_check(growth.choosing and not growth.unlock_notice_label.visible, "first level has no premature permanent-card notice")
	await _key(KEY_1)
	_check(growth.points_spent == 1 and not growth.choosing and not paused, "1 key still selects and resumes")
	growth.gain_xp(10)
	_check(growth.unlock_notice_label.visible and growth.unlock_notice_label.text.contains("여우불 분화"), "lifetime milestone 2 announces the newly unlocked card")
	_check(growth.unlock_notice_label.text.contains("영구 카드 해금") and growth.unlock_notice_label.text.contains("직접 선택해야 이번 런에 적용"), "notice distinguishes permanent availability from this run's applied cards")
	_check(not growth.card_ranks.has("S_WISP_COUNT") and growth.wisps.size() == 1, "unlock announcement does not equip the card")
	var health: float = scene.player.health
	var points := growth.points_earned
	var notice := growth.unlock_notice_label.text
	await _click(growth.reroll_button)
	_check(growth.rerolls_left == 0 and growth.unlock_notice_label.text == notice, "mouse reroll preserves the announcement without duplicating it")
	_check(scene.player.health == health and growth.points_earned == points, "reroll changes neither healing nor earned points")
	await _key(KEY_2)
	_check(growth.points_spent == 2 and not growth.choosing and not paused, "2 key still selects and resumes")
	growth.gain_xp(growth.next_xp())
	_check(not growth.unlock_notice_label.visible and growth.unlock_notice_label.text.is_empty(), "next non-milestone choice clears the previous notice")
	await _key(KEY_3)
	_check(growth.points_spent == 3 and not growth.choosing and not paused, "3 key still selects and resumes")
	growth.gain_xp(growth.next_xp())
	_check(growth.unlock_notice_label.text.contains("회전 불꽃") and not growth.unlock_notice_label.text.contains("여우불 분화"), "milestone 4 announces only its new card")
	await _click(growth.choice_buttons[0])
	_check(growth.points_spent == 4 and not growth.choosing and not paused, "card mouse click still selects and resumes")
	growth.gain_xp(growth.next_xp())
	_check(not growth.unlock_notice_label.visible, "milestone 5 does not repeat an old unlock")
	growth.choose_index(0)
	growth.gain_xp(growth.next_xp())
	_check(growth.unlock_notice_label.text.contains("연쇄 불꽃") and not growth.unlock_notice_label.text.contains("회전 불꽃"), "milestone 6 announces only chain")
	growth.choose_index(0)
	scene.queue_free()
	await process_frame
	# The persisted lifetime milestones must not reappear in a later run.
	scene = await _scene()
	growth = scene.growth
	growth.gain_xp(8)
	_check(growth.unlocks.lifetime_levelups == 7 and not growth.unlock_notice_label.visible, "reloaded profile does not announce already unlocked cards")
	growth.choose_index(0)
	scene.queue_free()
	await process_frame
	_cleanup()
	scene = await _scene()
	growth = scene.growth
	scene.player.health = 10.0
	growth.gain_xp(78)
	_check(growth.level == 7 and growth.points_earned == 6 and growth.pending_choices == 6 and growth.choice_windows_opened == 1, "overflow retains six rewards in one immediate choice window")
	for name in ["여우불 분화", "회전 불꽃", "연쇄 불꽃"]:
		_check(growth.unlock_notice_label.text.count(name) == 1, "overflow lists every new permanent card once: " + name)
	_check(is_equal_approx(scene.player.health, 100.0), "overflow still applies clipped healing immediately")
	notice = growth.unlock_notice_label.text
	growth.gain_xp(2)
	_check(growth.unlock_notice_label.text == notice, "another XP award in the same window preserves all notices")
	await _capture_if_requested(growth)
	while growth.choosing:
		growth.choose_index(0)
		if growth.choosing:
			_check(growth.unlock_notice_label.text == notice and growth.rerolls_left == 1, "sequential choices preserve the notice and reset the existing reroll allowance")
	_check(growth.points_spent == 6 and growth.unlocks.lifetime_levelups == 6 and is_equal_approx(scene.player.health, 100.0), "sequential choices do not duplicate growth or healing")
	paused = true
	growth.gain_xp(growth.next_xp())
	_check(not growth.unlock_notice_label.visible, "later choice does not repeat overflow notices")
	await _key(KEY_1)
	_check(paused and not growth.choosing, "choice completion preserves an existing pause")
	paused = false
	growth.gain_xp(growth.next_xp())
	root.focus_exited.emit()
	await _key(KEY_1)
	_check(paused and scene.paused, "focus loss still requires manual resume")
	scene._set_paused(false)
	scene.queue_free()
	await process_frame
	_cleanup()
	scene = await _scene()
	growth = scene.growth
	for amount in [18, 26, 34]: growth.gain_xp(amount)
	for name in ["여우불 분화", "회전 불꽃", "연쇄 불꽃"]:
		_check(growth.unlock_notice_label.text.count(name) == 1, "separate XP awards accumulate milestones within the open window: " + name)
	_check(growth.choice_windows_opened == 1 and growth.pending_choices == 6, "separate overflow awards do not reopen the modal")
	while growth.choosing: growth.choose_index(0)
	scene.queue_free()
	await process_frame
	_cleanup()
	print("Unlock notice verification: ", failures, " failures")
	quit(1 if failures else 0)


func _capture_if_requested(growth: RunGrowth) -> void:
	var destination := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): destination = argument.trim_prefix("--capture-dir=")
	if destination.is_empty(): return
	_check(DisplayServer.get_name() != "headless", "screenshots require a real renderer")
	if DisplayServer.get_name() == "headless": return
	# Long descriptions and all three notices exercise the largest content case.
	growth.current_choices.assign(["S_WISP_FOLLOWUP", "S_WISP_SWEEP", "S_WISP_REPLY"])
	for id in growth.current_choices: growth.card_ranks[id] = 1
	growth._refresh_choices()
	for resolution in [Vector2i(960, 540), Vector2i(1280, 720)]:
		root.size = resolution
		root.content_scale_size = Vector2i(1280, 720)
		for frame in 4: await process_frame
		await RenderingServer.frame_post_draw
		var label := growth.unlock_notice_label
		_check(label.get_line_count() == 2 and label.get_global_rect().end.y < growth.choice_buttons[0].global_position.y, "notice stays within two lines above cards at " + str(resolution))
		for button in growth.choice_buttons:
			_check(button.get_minimum_size().y <= button.size.y and button.get_global_rect().end.y < growth.reroll_button.global_position.y, "long card stays clear of reroll at " + str(resolution))
		var path := destination.path_join("unlock-notice-%dx%d.png" % [resolution.x, resolution.y])
		var screenshot := root.get_texture().get_image()
		_check(screenshot.get_size() == resolution and screenshot.save_png(path) == OK, "rendered screenshot saved at requested resolution: " + path)
