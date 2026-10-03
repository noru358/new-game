extends SceneTree
const RouteTerrain = preload("res://game/jungle_route_terrain.gd")
const OriginalTerrain = preload("res://game/jungle_pass_terrain.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _run() -> void:
	var old = OriginalTerrain.new()
	var scene = load("res://game/jungle_pass.tscn").instantiate()
	scene.profile_save_prefix = "user://jungle_route_verify_profile"
	scene.growth_save_prefix = "user://jungle_route_verify_unlocks"
	root.add_child(scene)
	await physics_frame
	scene.set_physics_process(false)
	scene.player.set_physics_process(false)
	for companion in scene.growth.wisps: companion.set_physics_process(false)
	await physics_frame
	await physics_frame
	check(scene.terrain is RouteTerrain, "actual scene mounts route data")
	check(scene.terrain.map_size == old.map_size and scene.terrain.plateaus == old.plateaus and scene.terrain.ramps == old.ramps and scene.terrain.gate_routes == old.gate_routes, "map area, elevations, ramps and existing route triggers retained")
	check(scene.terrain.wall_areas.size() == old.wall_areas.size(), "same obstacle count")
	var changed := 0
	for i in old.wall_areas.size():
		if old.wall_areas[i] != scene.terrain.wall_areas[i]:
			changed += 1
			var moved_parapet: bool = old.wall_areas[i].area == RouteTerrain.OLD_PARAPET and scene.terrain.wall_areas[i].area == RouteTerrain.RIVER_REMNANT
			var moved_tree: bool = old.wall_areas[i].area.get_center() == RouteTerrain.FOREGROUND_TREE and scene.terrain.wall_areas[i].area.get_center() == RouteTerrain.BACKGROUND_TREE and old.wall_areas[i].area.size == scene.terrain.wall_areas[i].area.size and old.wall_areas[i].height == scene.terrain.wall_areas[i].height
			check(moved_parapet or moved_tree, "only authorized parapet and foreground tree move; tree size and height retained")
	check(changed == 2 and scene.terrain.water_areas.size() == old.water_areas.size() + 1, "two placement moves and one actual lower river surface")
	check(scene.terrain.route_canopy_points.size() == OriginalTerrain.CANOPY_POINTS.size() and not scene.terrain.route_canopy_points.has(RouteTerrain.FOREGROUND_TREE) and scene.terrain.route_canopy_points.has(RouteTerrain.BACKGROUND_TREE), "same fully opaque canopy assets relocated with trunk collision")
	check(scene.terrain.route_reed_points.size() == 24 and RouteTerrain.ROCK_EDGE_POINTS.size() == 10 and RouteTerrain.RIVER_ROOT_POINTS.size() == 3, "same reed, edge-stone and root budgets; grouped rather than multiplied")
	for point in scene.terrain.route_reed_points + RouteTerrain.ROCK_EDGE_POINTS + RouteTerrain.RIVER_ROOT_POINTS:
		check(Rect2(2760, 1550, 1600, 700).has_point(point), "cluster placement remains within approved bank/ascent slice")
	check(not scene.navigation.is_open(RouteTerrain.RIVER_REMNANT.get_center(), scene.ACTOR_CLEARANCE) and not scene.navigation.is_open(RouteTerrain.LOW_RIVER.get_center(), scene.ACTOR_CLEARANCE), "ruin and water are real collision blockers")
	check(scene.navigation.is_open(RouteTerrain.OLD_PARAPET.get_center(), scene.ACTOR_CLEARANCE), "former bridge parapet leaves a real opening")
	check(not scene.clear_attack(Vector2(3080, 1900), Vector2(3310, 1900)), "new bank remnant affects actual attack sight")
	check(not scene.clear_attack(Vector2(2600, 2330), Vector2(4200, 2330)), "visible lower river uses an actual water collision body, outside the existing cliff edges")
	for point in [Vector2(2590, 1770), Vector2(2820, 1930), Vector2(2960, 2100), Vector2(3010, 2050), Vector2(3010, 1760), Vector2(3310, 2080), Vector2(3410, 1790), Vector2(4180, 1770), Vector2(4520, 1160), scene.temple_section.boss_point, scene.region_layout().ENTRY_TRIGGER.get_center()]:
		check(scene.navigation.is_open(point, scene.ACTOR_CLEARANCE) and scene.navigation.find_path(scene.start_point, point).size() > 1 and scene.navigation.find_path(point, scene.start_point).size() > 1, "entry, both bypasses, destination and existing hidden entrance retain round trips: " + str(point))
	var north: PackedVector2Array = scene.navigation.find_path(Vector2(2910, 1890), Vector2(3240, 1740))
	var south: PackedVector2Array = scene.navigation.find_path(Vector2(2910, 1890), Vector2(3240, 2050))
	check(north.size() > 1 and south.size() > 1, "two approaches pass opposite sides of the low remnant")
	check(scene._route_role_weights(Vector2(3010, 2050)) == [35.0, 15.0, 25.0, 15.0, 10.0] and scene._route_role_weights(Vector2(2850, 1140)) == [25.0, 45.0, 10.0, 15.0, 5.0], "random role weights untouched; rejected lamp replacement stays rejected")
	var landmark = scene.get_node("JungleRiverRemnant")
	check(landmark.get_meta("source_wall").area == RouteTerrain.RIVER_REMNANT, "worked stone reads the same collision footprint")
	check(landmark.get_meta("places") == RouteTerrain.PLACES and landmark.get_meta("max_floor_lift") <= 2.55, "three existing-space places use low dressing, not new terrain heights or labels")
	for place in RouteTerrain.PLACES:
		check(scene.navigation.is_open(place.point, scene.ACTOR_CLEARANCE) and scene.navigation.find_path(scene.start_point, place.point).size() > 1, "three place centers preserve open traversal")
	for point in [Vector2(3470, 1740), Vector2(3500, 1750), Vector2(3470, 2110)]:
		check(scene.navigation.is_open(point, scene.ACTOR_CLEARANCE), "relocated north tree does not seal either adjacent approach")
	for mesh in landmark.get_children():
		check(mesh.material_override.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "landmark remains fully opaque")
	scene.queue_free()
	await process_frame
	await process_frame
	print("Jungle route: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
