extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _run() -> void:
	var scene = load("res://game/temple_circuit_run.tscn").instantiate()
	scene.profile_save_prefix = "user://batch_trial_%d" % Time.get_ticks_usec()
	scene.growth_save_prefix = scene.profile_save_prefix + "_unlocks"
	root.add_child(scene)
	for i in 4: await physics_frame
	scene.set_physics_process(false)
	var growth: RunGrowth = scene.growth
	check(not growth.choice_batch_trial_enabled, "ordinary candidate remains unbatched by default")
	growth.choice_batch_trial_enabled = true
	for i in 6:
		growth.gain_xp(growth.next_xp())
		check(growth.choosing, "first six levelups open immediately")
		while growth.choosing: growth.choose_index(0)
	check(growth.points_spent == 6 and growth.choice_windows_opened == 6, "six introductory choices preserved")
	scene.player.health = 30
	growth.gain_xp(growth.next_xp())
	check(not growth.choosing and growth.pending_choices == 1, "seventh point waits for a pair")
	check(is_equal_approx(scene.player.health, 50), "level heal is immediate, not delayed until cards")
	growth.gain_xp(growth.next_xp())
	check(growth.choosing and growth.pending_choices == 2, "eighth point opens one two-choice window")
	check(is_equal_approx(scene.player.health, 70), "second level heals exactly once")
	growth.choose_index(0)
	check(growth.choosing and paused, "first selection keeps the same modal open")
	growth.choose_index(0)
	check(not growth.choosing and not paused and growth.choice_windows_opened == 7, "two points use one interruption")
	check(growth.points_spent == 8 and growth.points_earned == 8 and is_equal_approx(scene.player.health, 70), "selection adds no extra heal or points")
	growth.gain_xp(growth.next_xp())
	paused = true
	growth._process(30)
	check(not growth.choosing and growth.choice_batch_wait == 0, "ordinary pause does not spend batch wait")
	paused = false
	growth._process(growth.CHOICE_BATCH_MAX_WAIT)
	check(growth.choosing and growth.pending_choices == 1, "sparse XP flushes lone point at active-time limit")
	growth.choose_index(0)
	growth.gain_xp(growth.next_xp())
	growth.flush_pending_choices()
	check(growth.choosing, "boss boundary can flush a pending point")
	growth.choose_index(0)
	check(growth.pending_choices == 0 and growth.points_spent == 10, "all earned points accounted for")
	growth.gain_xp(growth.next_xp())
	growth.end_run()
	growth._process(30)
	check(not growth.choosing, "run ending never reopens a pending card")
	paused = false
	scene.queue_free()
	for i in 3: await process_frame
	print("Choice interruption batching: ", failures, " failures; opt-in only")
	quit(1 if failures else 0)
