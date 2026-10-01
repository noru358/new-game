extends SceneTree

const Sentries = preload("res://tests/jungle_river_sentries.gd")
const Fixture = preload("res://tests/jungle_river_fixture.gd")
var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _run() -> void:
	var expected := {
		"stairs-entry": [[Vector2(2890, 1100), TrainingEnemy.Role.BEAST], [Vector2(2960, 1180), TrainingEnemy.Role.LAMP]],
		"stairs-crest": [[Vector2(3970, 1010), TrainingEnemy.Role.BEAST], [Vector2(4020, 1330), TrainingEnemy.Role.LAMP]],
		"rocks-entry": [[Vector2(2820, 1930), TrainingEnemy.Role.ZONE], [Vector2(2960, 2100), TrainingEnemy.Role.FRAGMENT]],
		"rocks-crest": [[Vector2(4450, 1760), TrainingEnemy.Role.ZONE], [Vector2(4620, 1840), TrainingEnemy.Role.BEAST]],
	}
	var changed := 0
	for route in ["stairs", "rocks"]:
		for crest in [false, true]:
			var baseline := Sentries.entries(route, crest, false)
			var candidate := Sentries.entries(route, crest, true)
			check(baseline == expected[route + ("-crest" if crest else "-entry")], "baseline reproduces existing authored group")
			check(candidate.size() == baseline.size(), "same number of defenders")
			var rewards := [0, 0]
			for i in baseline.size():
				check(candidate[i][0] == baseline[i][0], "same position")
				if candidate[i][1] != baseline[i][1]:
					changed += 1
					check(route == "rocks" and not crest and candidate[i][0] == Sentries.RIVER_ENTRANCE and candidate[i][1] == TrainingEnemy.Role.LAMP, "only designated entrance changes to lamp")
				var old: Dictionary = TrainingEnemy.Definitions.ROLES[baseline[i][1]]
				var new: Dictionary = TrainingEnemy.Definitions.ROLES[candidate[i][1]]
				rewards[0] += new.xp - old.xp
				rewards[1] += new.currency - old.currency
			check(rewards == [0, 0], "exact group XP/currency budget preserved")
	check(changed == 1, "exactly one role replacement across all authored groups")
	# Real scene physics owns route entry, crest and no-stacking state.
	for enabled in [false, true]:
		var mounted := OS.get_cmdline_user_args().has("--require-mount")
		var scene = load("res://game/jungle_pass.tscn").instantiate() if mounted else Fixture.new()
		var flag := "river_sentry_trial_enabled" if mounted else "fixture_trial_enabled"
		check(scene.get(flag) != null, "fixture or integration mount is present")
		if scene.get(flag) == null:
			scene.free()
			continue
		scene.set(flag, enabled)
		scene.profile_save_prefix = "user://river_verify_%s_profile" % enabled
		scene.growth_save_prefix = "user://river_verify_%s_unlocks" % enabled
		root.add_child(scene)
		await physics_frame
		scene.spawn_credit = -100000.0
		scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
		check(scene._route_role_weights(Vector2(3010, 2050)) == [35.0, 15.0, 25.0, 15.0, 10.0] and scene._route_role_weights(Vector2(2850, 1140)) == [25.0, 45.0, 10.0, 15.0, 5.0], "existing random route weights preserved")
		check(scene.BOSS_TIME == 300.0 and scene.MAX_ENEMIES == 72, "existing time and spawn cap preserved")
		for point in [Vector2(2590, 1770), Sentries.RIVER_ENTRANCE, Vector2(3030, 2090), Vector2(3410, 1790), Vector2(4180, 1770), Vector2(4520, 1160)]:
			check(scene.navigation.is_open(point, scene.ACTOR_CLEARANCE) and scene.navigation.find_path(scene.start_point, point).size() > 1 and scene.navigation.find_path(point, scene.start_point).size() > 1, "entry, bypass, bridge and gate round trips remain open")
		scene.teleport(Vector2(2590, 1770))
		await physics_frame
		scene._tick_pending(1.0)
		check(scene.gate_route_encounter == "rocks" and scene._active_enemy_count() == 2, "river entrance schedules exactly two existing defenders")
		var counts := {}
		for actor in scene.actors:
			if actor is TrainingEnemy: counts[actor.role] = int(counts.get(actor.role, 0)) + 1
		check(counts.get(TrainingEnemy.Role.LAMP if enabled else TrainingEnemy.Role.ZONE, 0) == 1 and counts.get(TrainingEnemy.Role.FRAGMENT, 0) == 1, "actual spawned pair matches selected variant")
		scene.teleport(Vector2(2590, 1130))
		await physics_frame
		check(scene._active_enemy_count() == 2 and scene.gate_route_encounter == "rocks", "other entrance cannot stack a second pair")
		scene.teleport(Vector2(4180, 1770))
		await physics_frame
		scene._tick_pending(1.0)
		check(scene._active_enemy_count() == 4 and scene.gate_route_crest_triggered, "unchanged crest pair triggers once")
		scene.teleport(Vector2(2590, 1770))
		await physics_frame
		check(scene._active_enemy_count() == 4, "return trip cannot repeat the entrance reward")
		scene.queue_free()
		await process_frame
	print("Jungle river sentries: %d checks, %d failures; mount=%s" % [checks, failures, OS.get_cmdline_user_args().has("--require-mount")])
	quit(1 if failures else 0)
