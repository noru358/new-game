extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", note)
func _run() -> void:
	var scene = load("res://game/deep_wetland_field.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 4: await physics_frame
	check(scene.growth.growth_ended, "whole-field geography retains no-progression isolation")
	check(scene.actors.size() == 14, "13 place actors plus player")
	for route in scene._dry_routes():
		for point in route:
			check(scene.navigation.is_open(point, 30), "dry route point %s" % point)
			var path = scene.navigation.find_path(scene.Wetland.ENTRY, point)
			check(not path.is_empty() or point == scene.Wetland.ENTRY, "connected route point %s" % point)
			for i in range(1, path.size()):
				check(scene.navigation.has_clear_path(path[i-1], path[i]), "clear route segment")
	for spec in scene._place_encounters():
		check(scene.navigation.is_open(spec[0], 30), "place enemy not buried or in water")
		check(not scene.navigation.find_path(scene.Wetland.ENTRY, spec[0]).is_empty(), "enemy reachable")
	for basin in scene.terrain.water_areas:
		check(not scene.navigation.is_open(basin.get_center(), 30), "visible water remains blocked")
	check(not scene.navigation.has_clear_path(Vector2(4090, 1130), Vector2(4750, 1130)), "central pool creates two actual routes")
	scene.queue_free()
	for i in 3: await process_frame
	print("Wetland field: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
