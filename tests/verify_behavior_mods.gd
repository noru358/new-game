extends SceneTree

const PREFIX := "user://verify_behavior_mods_profile"
const UNLOCKS := "user://verify_behavior_mods_unlocks"
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	var profile := RunProfile.new()
	profile.save_prefix = PREFIX
	profile.load_state()
	_check(profile.settle("behavior-temple", "SUCCESS", 200) and profile.settle("behavior-jungle", "SUCCESS", 200, RunProfile.JUNGLE_REGION), "both equipment paths can be unlocked")
	_check(profile.buy_gear("W_FLOW") and profile.buy_gear("W_ECHO") and profile.buy_gear("A_EMBER"), "all three gear pieces can be owned")
	profile.owned_mods.assign(["RIPPLE", "ECHO_WISP", "EMBER_STRIKE"])
	_check(profile.slot_mod("W_FLOW", "RIPPLE") and profile.slot_mod("W_ECHO", "ECHO_WISP") and profile.slot_mod("A_EMBER", "EMBER_STRIKE"), "each behavior option fits only its own gear")
	_check(profile.equip("W_FLOW") and profile.equip("A_EMBER"), "flow and accessory can be prepared together")
	for mod_id in ["RIPPLE", "ECHO_WISP", "EMBER_STRIKE"]:
		_check(RunProfile.affix_kind(mod_id) == "behavior", "new combat effects appear under behavior options")
	_check(RunProfile.affix_kind("HEAVY") == "numeric" and RunProfile.affix_kind("BRIGHT") == "numeric", "existing numeric options remain available")
	var scene: Node3D = load("res://game/hybrid_region.tscn").instantiate()
	scene.profile_save_prefix = PREFIX
	scene.growth_save_prefix = UNLOCKS
	root.add_child(scene)
	await physics_frame
	await physics_frame
	_check(scene.player.flow_wave_enabled and scene.ember_strike_mod_enabled, "slotted flow and accessory behavior reach the live run")
	scene.teleport(Vector2(2500, 1050))
	var direct := _target(scene, Vector2(2580, 1050))
	var nearby := _target(scene, Vector2(2660, 1050))
	scene.player.attack_path_filter = Callable()
	scene.player.flow_weave_ready = true
	scene.player.facing = Vector2.RIGHT
	scene.player._start_attack()
	scene.player._hit_enemies(scene.player._attack_spec(1))
	_check(direct.health < 1000.0 and nearby.health < 1000.0 and scene.player.flow_wave_used, "enhanced basic hit adds one nearby wave outside its normal reach")
	var nearby_after: float = nearby.health
	scene.player._hit_enemies(scene.player._attack_spec(1))
	_check(is_equal_approx(nearby.health, nearby_after), "wave cannot repeat during the same swing")
	var normal_reach: float = scene.player._attack_spec(2).radius
	var normal_angle: float = scene.player._attack_spec(2).angle
	scene._on_wisp_hit(direct)
	_check(scene.player.ember_followup_timer > 0.0, "wisp impact opens a short follow-up window")
	scene.player._start_attack()
	_check(scene.player.ember_followup_attack and scene.player.ember_followup_timer == 0.0 and scene.player._attack_spec(2).radius > normal_reach and scene.player._attack_spec(2).angle > normal_angle, "the next basic swing consumes the wisp link and changes its reach and arc")
	scene.player._start_attack()
	_check(not scene.player.ember_followup_attack, "wisp link does not stay on later swings")
	scene.queue_free()
	await physics_frame
	_check(profile.equip("W_ECHO"), "saved loadout switches to the finisher weapon")
	var echo_scene: Node3D = load("res://game/hybrid_region.tscn").instantiate()
	echo_scene.profile_save_prefix = PREFIX
	echo_scene.growth_save_prefix = UNLOCKS
	root.add_child(echo_scene)
	await physics_frame
	await physics_frame
	_check(echo_scene.echo_wisp_mod_enabled and echo_scene.player.echo_finisher_enabled, "slotted finisher behavior reaches the next run")
	echo_scene.teleport(Vector2(2500, 1050))
	var boss_target := _target(echo_scene, Vector2(2600, 1050))
	var companion: WispCompanion = echo_scene.growth.wisps[0]
	companion.global_position = Vector2(2460, 1050)
	companion.target_visibility_filter = func(_candidate: Node2D) -> bool: return true
	echo_scene.player.set_combo_rank(2)
	echo_scene.player.gather_target_global = Vector2(2565, 1050)
	echo_scene.player.next_combo_step = 4
	echo_scene.player.facing = Vector2.RIGHT
	echo_scene.player._start_attack()
	var fired_before: int = companion.shots_fired
	echo_scene.player._hit_enemies(echo_scene.player._attack_spec(4))
	_check(boss_target.health < 1000.0 and companion.shots_fired == fired_before + 1, "fourth-hit impact fires one bonus wisp projectile")
	echo_scene._on_player_attack_landed(boss_target.position, Vector2.RIGHT, 4, true)
	_check(companion.shots_fired == fired_before + 1, "multiple fourth-hit targets cannot multiply the bonus projectile")
	echo_scene.queue_free()
	await physics_frame
	_cleanup()
	if failures == 0: print("Behavior mod verification passed: bounded gear options and three live combat links")
	quit(1 if failures else 0)


func _target(scene: Node3D, point: Vector2) -> TrainingEnemy:
	var enemy := TrainingEnemy.new()
	enemy.max_health = 1000.0
	enemy.health = 1000.0
	enemy.position = point
	scene.simulation.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _cleanup() -> void:
	for prefix in [PREFIX, UNLOCKS]:
		for suffix in ["_a.json", "_b.json"]:
			var path := ProjectSettings.globalize_path(prefix + suffix)
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
