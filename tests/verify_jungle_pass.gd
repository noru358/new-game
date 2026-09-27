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
	_check(scene.terrain.height_at(Vector2(2640, 1120)) == 240.0 and scene.terrain.height_at(Vector2(4520, 1160)) == 480.0, "the cliff and gate are visibly elevated")
	scene._spawn_now(scene.player.position + Vector2(220, 0), TrainingEnemy.Role.BEAST, true)
	_check(scene.boss is JungleWarden and scene.boss.max_health == 760.0, "jungle boss has a separate behavior and scale")
	scene.player.hurt_immunity = 1000.0
	scene.boss.set_physics_process(false)
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
