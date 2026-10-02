extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", note)
func _run() -> void:
	var scene = load("res://game/deep_wetland_trial.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 4: await physics_frame
	check(scene.growth.growth_ended, "no XP or unlock progression")
	check(scene.growth.unlocks.save_prefix == "user://deep_wetland_trial_unused_unlocks", "separate trial prefix")
	check(scene.actors.size() == 9, "player and eight place-bound existing-role enemies")
	check(scene.dormant_place_enemies.size() == 8, "distant groups wait at their places")
	for spec in scene.PLACE_ENCOUNTERS:
		check(scene.navigation.is_open(spec[0], 30), "encounter on dry ground")
		check(not scene.navigation.find_path(scene.Wetland.ENTRY, spec[0]).is_empty(), "encounter reachable")
	check(scene.camera.size == 9.0, "existing camera scale")
	for points in [scene.Wetland.WAYPOINTS, scene.Wetland.SIDE_ROUTE]:
		for p in points:
			check(scene.navigation.is_open(p, 30), "open route point %s" % p)
			check(scene.navigation.find_path(scene.Wetland.ENTRY, p).size() > 1 or p == scene.Wetland.ENTRY, "reachable point %s" % p)
	for water in scene.terrain.water_areas:
		check(not scene.navigation.is_open(water.get_center(), 30), "blocked deep water")
	check(not scene.clear_attack(Vector2(1950, 960), Vector2(2850, 960)), "water/face does not permit cross-wall shots")
	check(scene.terrain.height_at(scene.Wetland.ENTRY) == 0, "flat authored movement surface")
	var level: int = scene.growth.level
	var xp: int = scene.growth.xp
	scene._on_enemy_defeated(null)
	check(scene.growth.level == level and scene.growth.xp == xp, "trial kill grants no XP")
	scene.teleport(scene.Wetland.PROCESSION)
	scene._physics_process(0.0)
	var remaining: int = scene.dormant_place_enemies.size()
	check(remaining < 8 and remaining > 0, "nearby place activates without waking entire field")
	scene.teleport(scene.Wetland.ENTRY)
	scene._physics_process(0.0)
	check(scene.dormant_place_enemies.size() <= remaining, "retreat does not put active enemies back to sleep")
	scene._set_paused(true)
	check(paused, "pause works")
	scene._set_paused(false)
	scene.queue_free()
	for i in 3: await process_frame
	print("Wetland: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
