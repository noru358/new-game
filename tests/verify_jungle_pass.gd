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
	_check(scene.terrain.map_size == Vector2(5600, 2400) and scene.region_id == RunProfile.JUNGLE_REGION, "second region uses its own map and progress ID")
	for point in [Vector2(1410, 1180), Vector2(2180, 420), Vector2(2640, 1120), Vector2(2870, 1970), Vector2(4520, 1160)]:
		_check(scene.navigation.is_open(point, scene.ACTOR_CLEARANCE) and scene.navigation.find_path(scene.player.position, point).size() >= 2, "ridge, detours and gate remain reachable from the entry")
	_check(scene.navigation.is_open(Vector2(3750, 1700), scene.ACTOR_CLEARANCE) and scene.navigation.find_path(Vector2(3420, 1700), Vector2(4700, 1700)).size() >= 2, "southern gate ramp gives a second reachable entrance")
	_check(scene.terrain.ramps[3].kind == "gate_stairs" and scene.terrain.ramps[4].kind == "rock_path", "gate entrances have distinct authored surfaces")
	_check(scene.terrain.height_at(Vector2(2640, 1120)) == 240.0 and scene.terrain.height_at(Vector2(4520, 1160)) == 480.0, "the cliff and gate are visibly elevated")
	scene.teleport(Vector2(3330, 1130))
	await physics_frame
	_check(scene.gate_route_encounter == "stairs" and scene._active_enemy_count() == 2, "main stair approach calls its two sentries from the upper landing")
	scene.teleport(Vector2(3330, 1690))
	await physics_frame
	_check(scene.gate_route_encounter == "stairs" and scene._active_enemy_count() == 2, "the other approach does not stack a second encounter in one run")
	scene.run_time = 270.0
	scene._update_run_hud()
	_check(scene.run_hud.text.contains("관문 상단에 수호자 출현 예정"), "gate boss location is announced thirty seconds early")
	var gate_spawn: Vector2 = scene._choose_spawn_point(true)
	_check(gate_spawn.x == 4700.0 and gate_spawn.distance_to(scene.player.position) > 350.0, "warden appears in the authored gate court instead of near the player")
	scene.run_time = 299.99
	await physics_frame
	await physics_frame
	_check(scene.boss_announced, "five-minute timer announces the fixed gate spawn")
	for i in 85: await physics_frame
	_check(scene.boss_spawned and scene.boss.position.x == 4700.0 and scene.boss.position.distance_to(scene.player.position) > 350.0, "five-minute spawn uses the gate position in the live run")
	_check(scene.boss is JungleWarden and scene.boss.max_health == 760.0, "jungle boss has a separate behavior and scale")
	scene.player.hurt_immunity = 1000.0
	scene.boss.set_physics_process(false)
	_check(scene.boss._beast_velocity(0.01) == Vector2.ZERO and not scene.boss.engaged, "guardian holds the gate until the player approaches")
	scene.teleport(scene.boss.position + Vector2(200, 0))
	scene.boss._beast_velocity(0.01)
	_check(scene.boss.sweep_warning > 0.0, "jungle guardian starts with a lateral sweep warning")
	scene.boss.take_hit(1000.0, Vector2.RIGHT, true)
	await physics_frame
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
