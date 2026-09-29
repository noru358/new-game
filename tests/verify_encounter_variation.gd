extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)
func _run() -> void:
	for path in ["res://game/hybrid_region.tscn", "res://game/jungle_pass.tscn"]:
		var scene = load(path).instantiate()
		scene.profile_save_prefix = "user://verify_encounter_profile"
		scene.growth_save_prefix = "user://verify_encounter_unlocks"
		root.add_child(scene)
		await process_frame
		var actual := 0.0
		var baseline := 0.0
		for second in 300:
			scene.run_time = float(second) + 0.5
			actual += scene._spawn_rate()
			baseline += 0.60 if second < 45 else 0.85 if second < 120 else 1.10 if second < 200 else 1.40
			var phase: Dictionary = scene._encounter_phase()
			if not phase.is_empty():
				var total := 0.0
				for weight in phase.weights: total += weight
				check(is_equal_approx(total, 100.0), "role weights sum to 100")
		check(is_equal_approx(actual, baseline), "pressure and recovery preserve five-minute scheduled spawn budget")
		scene.run_time = 140.0
		check(scene._encounter_phase().name.contains("원거리") and scene._spawn_rate() > 1.1, "middle wave shifts role and pressure")
		scene.run_time = 160.0
		check(scene._spawn_rate() < 1.1, "pressure is followed by recovery")
		scene.boss_spawned = true
		check(scene._encounter_phase().is_empty() and is_equal_approx(scene._spawn_rate(), 0.25), "boss phase has no extra wave pressure")
		scene.queue_free()
		await process_frame
	print("encounter variation: ", failures, " failures")
	quit(1 if failures else 0)
