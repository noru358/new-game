extends SceneTree
## Replay observed level-up timestamps, not combat. No claim of wall-time savings.
var report_path := ""
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var input := OS.get_environment("CHOICE_TRACE_INPUT")
	if input.is_empty() or not FileAccess.file_exists(input):
		printerr("FAIL: CHOICE_TRACE_INPUT must name an existing synthetic journey report")
		quit(1)
		return
	var source = JSON.parse_string(FileAccess.get_file_as_string(input))
	var trace: Array = source.runs[0].card_choices
	var result := []
	for batched in [false, true]:
		var scene = load("res://game/temple_circuit_run.tscn").instantiate()
		scene.profile_save_prefix = "user://trace_replay_%d_%s" % [Time.get_ticks_usec(), str(batched)]
		scene.growth_save_prefix = scene.profile_save_prefix + "_unlocks"
		root.add_child(scene)
		for i in 3: await physics_frame
		scene.set_physics_process(false)
		scene.growth.set_process(false)
		var growth: RunGrowth = scene.growth
		growth.choice_batch_trial_enabled = batched
		growth.rng.seed = 250
		var simulated := 0.0
		var index := 0
		var deadline: float = source.runs[0].diagnostics.active_seconds + 0.1
		while simulated < deadline:
			simulated += 0.05
			growth._process(0.05)
			while index < trace.size() and simulated >= float(trace[index].active_seconds):
				growth.gain_xp(growth.next_xp())
				index += 1
			if simulated >= 241.2: growth.flush_pending_choices()
			while growth.choosing: growth.choose_index(0)
		growth.flush_pending_choices()
		while growth.choosing: growth.choose_index(0)
		result.append({"batched": batched, "replayed_levels": index, "points_earned": growth.points_earned, "points_spent": growth.points_spent, "pending": growth.pending_choices, "modal_interruptions": growth.choice_windows_opened, "same_click_count": growth.points_spent, "active_trace_seconds": deadline, "source_run": 1, "combat_replayed": false, "wall_time_savings_measured": false})
		paused = false
		scene.queue_free()
		for i in 3: await process_frame
	print("CHOICE_TRACE_REPLAY ", JSON.stringify(result))
	quit()
