extends SceneTree

var failures := 0
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)
func _run() -> void:
	var scene = load("res://game/hybrid_region.tscn").instantiate()
	scene.profile_save_prefix = "user://verify_growth_rewards_profile"
	scene.growth_save_prefix = "user://verify_growth_rewards_unlock"
	for prefix in [scene.profile_save_prefix, scene.growth_save_prefix]:
		for suffix in ["_a.json", "_b.json"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(prefix + suffix))
	root.add_child(scene)
	await process_frame
	var growth = scene.growth
	scene.player.health = 10.0
	growth.gain_xp(8)
	check(growth.choosing and growth.pending_choices == 1, "first level opens immediately")
	check(is_equal_approx(scene.player.health, 30.0) and scene.player.combo_limit() == 3, "healing and permanent combo happen before card selection")
	growth.reroll_choices()
	growth.choose_index(0)
	check(is_equal_approx(scene.player.health, 30.0) and not paused, "selection and reroll do not duplicate healing")
	growth.gain_xp(10)
	check(growth.choosing and growth.pending_choices == 1 and growth.choice_windows_opened == 2, "every level opens without waiting for a batch")
	growth.choose_index(0)
	growth.gain_xp(12 + 14 + 3)
	check(growth.level == 5 and growth.xp == 3 and growth.pending_choices == 2, "overflow XP preserves every point and remainder")
	var windows: int = growth.choice_windows_opened
	growth.rerolls_left = 0
	growth.choose_index(0)
	check(growth.choosing and growth.overlay.visible and paused and growth.pending_choices == 1, "overflow choices stay on the same paused screen")
	check(growth.rerolls_left == 1 and growth.choice_windows_opened == windows and not growth.last_choice_label.text.is_empty(), "next point resets reroll and displays applied effect without reopening")
	growth.choose_index(0)
	check(growth.points_earned == 4 and growth.points_spent == 4 and growth.unlocks.lifetime_levelups == 4, "logical levels and rewards counted once")
	for id in growth.CARDS: growth.card_ranks[id] = growth.CARDS[id].max
	scene.player.health = 10.0
	paused = true
	growth.gain_xp(growth.next_xp())
	check(paused and not growth.choosing and growth.pending_choices == 0 and growth.exhausted_points == 1, "exhausted pool preserves external pause and accounts for unused point")
	check(is_equal_approx(scene.player.health, 30.0), "exhausted pool does not heal twice")
	growth.card_ranks.clear()
	growth.selected_card_ranks.clear()
	growth.gain_xp(growth.next_xp())
	growth.choose_index(0)
	check(paused, "finishing choices restores preexisting pause")
	paused = false
	growth.gain_xp(growth.next_xp())
	root.focus_exited.emit()
	growth.choose_index(0)
	check(paused and scene.paused, "focus loss during selection requires manual resume")
	scene._set_paused(false)
	growth.gain_xp(growth.next_xp())
	var earned: int = growth.points_earned
	growth.end_run()
	growth.gain_xp(1000)
	check(paused and not growth.choose_index(0) and growth.points_earned == earned, "ended run cannot grant or spend rewards or resume")
	paused = false
	scene.queue_free()
	await process_frame
	print("growth rewards: ", failures, " failures")
	quit(1 if failures else 0)
