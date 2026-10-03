extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _run() -> void:
	var scene = load("res://game/jungle_south_circuit.tscn").instantiate()
	scene.profile_save_prefix = "user://south_circuit_fixture_%d" % Time.get_ticks_usec()
	scene.growth_save_prefix = scene.profile_save_prefix + "_unlocks"
	root.add_child(scene)
	for i in 5: await physics_frame
	scene.set_physics_process(false)
	var paving = scene.get_node("SouthernRiverPlaces/TransitCourt")
	var vertices: PackedVector3Array = paving.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for vertex in vertices:
		var point := Vector2(vertex.x, vertex.z) / 0.01
		check(vertex.y <= (scene.terrain.height_at(point) + 0.71) * 0.01, "new southern paving follows actual terrain below shadow bottom")
	check(scene.player.arena_bounds == scene.SouthLayout.MAIN_BOUNDS, "candidate adds southern play bounds")
	check(scene.profile.temple_owned and scene.growth.unlocks.lifetime_levelups == 6, "explicit isolated development access, not a fresh campaign")
	for route in [scene.SouthTerrain.SOUTH_ROUTE, scene.SouthTerrain.RIDGE_RETURN]:
		for point in route:
			check(scene.navigation.is_open(point, 30), "south route is open at %s" % point)
			check(not scene.navigation.find_path(scene.start_point, point).is_empty(), "south route connects to original entry at %s" % point)
	check(scene.navigation.find_path(scene.start_point, scene.SouthLayout.FIELD_ENTRY).is_empty(), "new southern bounds cannot bypass hidden-field entrance")
	check(is_equal_approx(scene.terrain.height_at(Vector2(3010, 2450)), 40), "bank descent bridges old80-height riverbank to new ground")
	check(scene.navigation.is_open(Vector2(3560, 2620), 30), "landing over water is truly walkable")
	check(not scene.navigation.find_path(scene.start_point, Vector2(3560, 2620)).is_empty(), "landing has a real entry path")
	check(scene.terrain.height_at(Vector2(3560, 2620)) == 40, "landing has a physical raised surface")
	check(not scene.navigation.is_open(Vector2(3800, 2620), 30), "river beyond the landing remains blocked")
	check(not scene.navigation.is_open(Vector2(3000, 3000), 30), "river remains visible blocked water")
	scene.temple_section.enter_garden()
	check(scene.player.arena_bounds == scene.SouthLayout.FIELD_BOUNDS, "existing hidden area remains separate")
	scene.temple_section.leave_garden()
	check(scene.player.arena_bounds == scene.SouthLayout.MAIN_BOUNDS, "return restores expanded main bounds")
	check(scene.BOSS_TIME == 240 and scene.temple_section.boss_point == Vector2(4750, 850), "existing boss timing and destination unchanged")
	scene.run_time = 240.0
	scene.teleport(scene.temple_section.retry_point)
	scene.temple_section.tick(0.0)
	scene.temple_section.tick(1.3)
	check(is_instance_valid(scene.boss) and scene.boss is JungleWarden and scene.temple_section.boss_active, "actual original jungle boss engages in the expanded scene")
	if is_instance_valid(scene.boss): scene.boss.take_hit(10000, Vector2.RIGHT, false)
	scene._physics_process(0.0)
	check(scene.run_ended and scene.end_result == "SUCCESS" and scene.profile.jungle_owned and not scene.settlement_pending, "isolated candidate retains existing clear settlement")
	var generation: int = scene.profile.generation
	scene._finish_run("SUCCESS")
	check(scene.profile.generation == generation, "duplicate candidate settlement stays idempotent")
	var restored := RunProfile.new()
	restored.save_prefix = scene.profile_save_prefix
	restored.load_state()
	check(not restored.load_error and restored.jungle_owned, "candidate clear survives its separate profile reload")
	print("Jungle southern circuit: ", failures, " failures; expanded geometry candidate only")
	scene.queue_free()
	paused = false
	for i in 3: await process_frame
	quit(1 if failures else 0)
