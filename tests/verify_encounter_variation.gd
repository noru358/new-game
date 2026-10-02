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
		for second in int(scene.BOSS_TIME):
			scene.run_time = float(second) + 0.5
			actual += scene._spawn_rate()
			baseline += 0.90 if second < 45 else 1.275 if second < 120 else 1.65 if second < 200 else 2.10
			var phase: Dictionary = scene._encounter_phase()
			if not phase.is_empty():
				var total := 0.0
				for weight in phase.weights: total += weight
				check(is_equal_approx(total, 100.0), "role weights sum to 100")
		check(is_equal_approx(actual, baseline), "pressure and recovery preserve the four-minute scheduled spawn budget")
		scene.run_time = 140.0
		check(scene._spawn_rate() > 1.1, "middle wave preserves pressure increase")
		if path.ends_with("jungle_pass.tscn"):
			for sample in [
				{"point": Vector2(700, 1800), "weights": [55.0, 30.0, 0.0, 15.0, 0.0], "cue": "추격·돌진"},
				{"point": Vector2(2900, 1200), "weights": [25.0, 45.0, 10.0, 15.0, 5.0], "cue": "돌진·추격"},
				{"point": Vector2(2900, 1800), "weights": [35.0, 15.0, 25.0, 15.0, 10.0], "cue": "추격·원거리"},
				{"point": Vector2(1800, 1100), "weights": [40.0, 30.0, 10.0, 15.0, 5.0], "cue": "추격·돌진"}
			]:
				scene.player.position = sample.point
				check(scene._route_role_weights(sample.point) == sample.weights, "authored jungle spawn composition is unchanged")
				for second in [70.0, 140.0, 195.0]:
					scene.run_time = second
					check(scene._encounter_cue().contains(sample.cue) and scene._run_hud_text().contains(sample.cue), "jungle HUD describes authoritative incoming roles in each pressure phase")
					if sample.weights[2] == 0.0: check(not scene._encounter_cue().contains("원거리"), "forest cue never promises absent ranged spawns")
					if sample.weights[4] == 0.0: check(not scene._encounter_cue().contains("지원"), "forest cue never promises absent support spawns")
					scene.rng.seed = 4321
					var seen := [0, 0, 0, 0, 0]
					for draw in 500: seen[scene._roll_role()] += 1
					for role in 5:
						check((seen[role] == 0) == (sample.weights[role] == 0.0), "actual jungle role rolls respect the same nonzero role set")
		else:
			check(scene._encounter_cue().contains("원거리"), "temple retains its real timed ranged cue")
		scene.run_time = 160.0
		check(scene._spawn_rate() < 1.65, "pressure is followed by recovery")
		if path.ends_with("jungle_pass.tscn"):
			check(scene._encounter_cue().contains("합류 감소") and scene._encounter_cue().contains("남은 적"), "recovery cue describes fewer new spawns without claiming existing enemies vanished")
		scene.run_time = 140.0
		scene.temple_section.in_garden = true
		check(scene._spawn_rate() == 0.0 and scene._encounter_cue().is_empty(), "hidden fixed encounters never show ambient arrival cues")
		scene.temple_section.in_garden = false
		scene.boss_spawned = true
		check(scene._encounter_phase().is_empty() and scene._encounter_cue().is_empty() and is_equal_approx(scene._spawn_rate(), 0.25), "boss phase has no extra wave pressure")
		scene.queue_free()
		await process_frame
	print("encounter variation: ", failures, " failures")
	quit(1 if failures else 0)
