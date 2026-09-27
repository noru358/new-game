extends SceneTree

const PROFILE_PREFIX := "user://verify_boss_encounter_profile"
const UNLOCK_PREFIX := "user://verify_boss_encounter_unlocks"
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	var scene: Node3D = load("res://game/hybrid_region.tscn").instantiate()
	scene.profile_save_prefix = PROFILE_PREFIX
	scene.growth_save_prefix = UNLOCK_PREFIX
	root.add_child(scene)
	await physics_frame
	await physics_frame
	scene.teleport(Vector2(2350, 800))
	scene._spawn_now(scene.player.position + Vector2(220, 0), TrainingEnemy.Role.BEAST, true)
	scene.player.set_physics_process(false)
	scene.player.hurt_immunity = 1000.0
	scene.paused = true
	var boss: GateBoss = scene.boss
	for i in 600: await physics_frame
	_check(is_instance_valid(boss) and boss.attacks_started >= 3 and boss.attacks_fired >= 2, "live physics boss keeps attacking in a ten-second stationary encounter")
	_check(boss.warning_time >= 0.0 and boss.charge_time >= 0.0 and boss.shock_warning >= 0.0, "live boss state remains valid across multiple cycles")
	var started_before: int = boss.attacks_started
	var fired_before: int = boss.attacks_fired
	boss.take_hit(300.0, Vector2.RIGHT, false)
	for i in 600: await physics_frame
	_check(boss.phase == 2 and boss.attacks_started >= started_before + 2 and boss.attacks_fired >= fired_before + 2, "second phase keeps using its faster attacks in live physics")
	scene.queue_free()
	await process_frame
	_cleanup()
	if failures == 0: print("Boss encounter verification passed: repeated attacks in both live-physics phases")
	quit(1 if failures else 0)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _cleanup() -> void:
	for prefix in [PROFILE_PREFIX, UNLOCK_PREFIX]:
		for suffix in ["_a.json", "_b.json"]:
			var path := ProjectSettings.globalize_path(prefix + suffix)
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
