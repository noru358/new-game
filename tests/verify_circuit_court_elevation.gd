extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _run() -> void:
	var scene = load("res://game/temple_circuit_run.tscn").instantiate()
	scene.profile_save_prefix = "user://court_elevation_%d" % Time.get_ticks_usec()
	scene.growth_save_prefix = scene.profile_save_prefix + "_unlocks"
	root.add_child(scene)
	for i in 4: await physics_frame
	scene.set_physics_process(false)
	var environment = preload("res://game/temple_circuit_environment.gd")
	for point in environment.FAR_BANK_GROVES:
		for i in 12:
			var test_point: Vector2 = point + Vector2.from_angle(TAU * float(i) / 12.0) * 85
			var blocked_water := false
			for water in scene.terrain.water_areas:
				if water.has_point(test_point): blocked_water = true
			check(blocked_water, "far-bank root footprint stays in existing water")
	var paving = scene.temple_sanctuary_root.get_node("ReclaimedCourtMasonry/CourtAndStairCourses")
	var vertices: PackedVector3Array = paving.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var court: Rect2 = scene.terrain.plateaus[0].area.grow(-5)
	var peak := 0.0
	for vertex in vertices:
		if court.has_point(Vector2(vertex.x, vertex.z) / 0.01): peak = maxf(peak, vertex.y)
	var shadow = scene.actors[scene.player].get_node("Shadow")
	var shadow_bottom: float = 1.2 + shadow.position.y - shadow.mesh.height * 0.5
	check(peak < shadow_bottom - 0.0005, "new court paving remains below the actual shadow cylinder")
	var mapped_walls := 0
	for wall in scene.terrain.wall_areas:
		if wall.get("circuit_masonry", false):
			check(scene.minimap._wall_visible(wall, scene.display_bounds()), "replacement masonry keeps its minimap obstacle")
			mapped_walls += 1
	check(mapped_walls == 6, "all six existing masonry footprints remain represented")
	check(scene.terrain.height_at(Vector2(2450, 2100)) == 120, "central court is a low raised place")
	check(scene.terrain.height_at(Vector2(3400, 2080)) == 0, "water route stays at ground level")
	for pair in [[Vector2(1670, 2275), 60.0], [Vector2(2340, 1400), 60.0], [Vector2(3060, 2390), 60.0]]:
		check(is_equal_approx(scene.terrain.height_at(pair[0]), pair[1]), "ramp midpoint interpolates continuously")
		check(scene.navigation.is_open(pair[0], 30), "broad ramp midpoint is physically open")
		check(not scene.navigation.find_path(scene.start_point, pair[0]).is_empty(), "each raised-court approach connects to entry")
	check(not scene.clear_attack(Vector2(2100, 2850), Vector2(2100, 2700)), "closed south cliff cannot be attacked through")
	check(scene.clear_attack(Vector2(1640, 2280), Vector2(1940, 2280)), "west stairs retain a clear continuous attack path")
	scene.teleport(Vector2(2450, 2100))
	for i in 3: await physics_frame
	check(is_equal_approx(scene.terrain.world_point(scene.player.position).y, 1.2), "player ground placement follows raised court")
	print("Circuit court elevation: ", failures, " failures")
	scene.queue_free()
	for i in 3: await process_frame
	quit(1 if failures else 0)
