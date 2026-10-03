extends SceneTree

const PREFIX := "user://verify_jungle_pass_profile"
const UNLOCKS := "user://verify_jungle_pass_unlocks"
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	var profile := RunProfile.new()
	profile.save_prefix = PREFIX
	profile.load_state()
	_check(profile.settle("temple-clear", "SUCCESS", 0), "first region can unlock the pass")
	var scene: Node3D = load("res://game/jungle_pass.tscn").instantiate()
	scene.profile_save_prefix = PREFIX
	scene.growth_save_prefix = UNLOCKS
	root.add_child(scene)
	await physics_frame
	await physics_frame
	for point in scene.enemy_points:
		_check(scene.navigation.is_open(point, scene.ACTOR_CLEARANCE + 6.0) and scene.navigation.find_path(scene.start_point, point).size() >= 2, "authored practice spawn is clear and connected: " + str(point))
	_check(scene.display_bounds() == Rect2(0, 0, 5600, 2400) and scene.region_id == RunProfile.JUNGLE_REGION, "second region uses its own map and progress ID")
	for point in [Vector2(1410, 1180), Vector2(1640, 265), Vector2(2180, 420), Vector2(2640, 1120), Vector2(2180, 2120), Vector2(3010, 1850), Vector2(3410, 1790), Vector2(4520, 1160)]:
		_check(scene.navigation.is_open(point, scene.ACTOR_CLEARANCE) and scene.navigation.find_path(scene.player.position, point).size() >= 2, "ridge, detours and gate remain reachable from the entry")
	_check(scene.navigation.is_open(Vector2(3750, 1760), scene.ACTOR_CLEARANCE) and scene.navigation.find_path(Vector2(3410, 1790), Vector2(4700, 1700)).size() >= 2, "lower canyon bridge reaches a separate gate entrance")
	_check(scene.terrain.ramps[3].kind == "gate_stairs" and scene.terrain.ramps[4].kind == "rock_path" and scene.terrain.ramps[6].kind == "broken_bridge", "causeway and canyon have distinct terrain and ascent")
	_check(scene.terrain.rock_ledge_areas.size() == 3 and scene.terrain.gate_routes.stairs.entry.position.x < 2700.0 and scene.terrain.gate_routes.rocks.entry.position.x < 2700.0, "the fork begins on the ridge and the cliff path has three broad rock ledges")
	var cross_path: PackedVector2Array = scene.navigation.find_path(Vector2(3100, 1200), Vector2(3100, 1850))
	var cross_distance := 0.0
	for i in range(cross_path.size() - 1): cross_distance += cross_path[i].distance_to(cross_path[i + 1])
	_check(cross_distance > 650.0 and cross_distance < 1400.0, "the middle slope reconnects upper and lower routes without a cliff shortcut")
	_check(scene.terrain.height_at(Vector2(2640, 1120)) == 240.0 and scene.terrain.height_at(Vector2(3010, 1850)) == 80.0 and scene.terrain.height_at(Vector2(4520, 1160)) == 480.0, "the two approaches actually use different walking elevations")
	for area in scene.terrain.surface_areas(scene.terrain.plateaus[1]):
		_check(not area.has_point(Vector2(2890, 1300)), "upper plateau does not visually cover descending connector")
	for y in range(1190, 1741, 20):
		_check(scene.navigation.is_open(Vector2(2890, y), scene.ACTOR_CLEARANCE), "new connecting slope has full player clearance")
		_check(absf(scene.terrain.height_at(Vector2(2890, y)) - scene.terrain.height_at(Vector2(2890, y + 1))) < 1.0, "connecting slope has no elevation seam")
	_check(scene.navigation.find_path(Vector2(2890, 1700), Vector2(3030, 2090)).size() > 1, "expanded riverbank clearing reachable")
	_check(not scene.navigation.is_open(Vector2(2860, 930), scene.ACTOR_CLEARANCE), "broken parapet constricts the direct route")
	scene.teleport(Vector2(2590, 1130))
	await physics_frame
	_check(scene.gate_route_encounter == "stairs" and scene._active_enemy_count() == 2, "main stair route starts with its own two-sentry encounter")
	scene.teleport(Vector2(4180, 1770))
	await physics_frame
	_check(scene.gate_route_crest_triggered and scene._active_enemy_count() == 4, "switching from the direct route to the river route still triggers its gate-top encounter")
	scene.teleport(Vector2(2590, 1770))
	await physics_frame
	_check(scene.gate_route_encounter == "stairs" and scene._active_enemy_count() == 4, "the other approach does not stack another route's encounters in one run")
	scene.run_time = scene.BOSS_TIME - 30.0
	scene._update_run_hud()
	_check(scene.run_hud.text.contains("관문 상단에 수호자 출현 예정"), "gate boss location is announced thirty seconds early")
	var gate_spawn: Vector2 = scene.temple_section.boss_point
	_check(scene.temple_section.boss_area.has_point(gate_spawn) and gate_spawn.distance_to(scene.player.position) > 350.0, "warden appears in the authored gate court instead of near the player")
	scene.run_time = scene.BOSS_TIME - 0.01
	await physics_frame
	await physics_frame
	_check(scene.boss_announced, "four-minute timer announces the fixed gate spawn")
	for i in 85: await physics_frame
	_check(scene.boss_spawned and scene.temple_section.boss_area.has_point(scene.boss.position) and scene.boss.position.distance_to(scene.player.position) > 350.0, "four-minute spawn uses the gate position in the live run")
	_check(scene.boss is JungleWarden and scene.boss.max_health == 2000.0, "jungle boss has a separate behavior and scale")
	scene.player.hurt_immunity = 1000.0
	scene.boss.set_physics_process(false)
	_check(scene.boss._beast_velocity(0.01) == Vector2.ZERO and not scene.boss.engaged, "guardian holds the gate until the player approaches")
	scene.teleport(scene.boss.position + Vector2(200, 0))
	scene.temple_section.tick(0.0)
	scene.boss.attack_cooldown = 0.0
	scene.boss._beast_velocity(0.01)
	_check(scene.boss.sweep_warning > 0.0, "jungle guardian starts with a lateral sweep warning")
	scene.boss.take_hit(scene.boss.max_health * 2.0, Vector2.RIGHT, true)
	await physics_frame
	_check(scene.run_ended and scene.profile.jungle_owned and not scene.result_overlay.visible, "second region settles before its finish animation completes")
	await create_timer(0.9).timeout
	_check(scene.run_ended and scene.end_result == "SUCCESS" and scene.profile.jungle_owned and scene.result_text.text.contains("관문 통과"), "second region settles its own first clear and reward")
	paused = false
	scene.queue_free()
	await process_frame
	_cleanup()
	if failures == 0: print("Jungle pass verification passed: routes, distinct boss and region settlement")
	quit(1 if failures else 0)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _cleanup() -> void:
	for prefix in [PREFIX, UNLOCKS]:
		for suffix in ["_a.json", "_b.json"]:
			var path := ProjectSettings.globalize_path(prefix + suffix)
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
