extends SceneTree

const PREFIX := "user://verify_v25_feedback_profile"
const UNLOCKS := "user://verify_v25_feedback_unlocks"
var failures := 0

func _initialize() -> void: call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _run() -> void:
	var scene = load("res://game/jungle_pass.tscn").instantiate()
	scene.profile_save_prefix = PREFIX
	scene.growth_save_prefix = UNLOCKS
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
	var flow_progress: Label = scene.get_node("RunFlowHudPresenter").get("progress")
	_check(flow_progress.visible and flow_progress.text.contains("XP 0 / 8") and scene.growth.xp_bar.visible and scene.growth.xp_bar.position.y > flow_progress.position.y + flow_progress.size.y and scene.growth.xp_bar.position.y + scene.growth.xp_bar.size.y <= 720.0 and not scene.build_summary_label.visible, "XP number and thin progress bar remain visible below combat content")
	scene.growth.gain_xp(2)
	scene.get_node("RunFlowHudPresenter").refresh()
	_check(scene.growth.xp_bar.value == 2.0 and scene.growth.hud.text.contains("경험치 2 / 8") and flow_progress.text.contains("XP 2 / 8"), "visible XP changes with a real award")
	scene.player.attack_step = 4
	scene._process(0.016)
	_check(scene.actors[scene.player].get_node("Body").scale == Vector3.ONE, "fourth attack no longer enlarges the player")
	_check(is_equal_approx(scene._spawn_rate(), 0.90) and scene.MAX_ENEMIES == 72, "early ambient rate and headroom grow by 50 percent")
	scene.run_time = 200.0
	var late_pressure: float = scene._spawn_rate()
	scene.run_time = 220.0
	var late_recovery: float = scene._spawn_rate()
	_check(is_equal_approx(late_pressure, 2.625) and is_equal_approx(late_recovery, 1.575) and is_equal_approx((late_pressure + late_recovery) * 0.5, 2.10), "late ambient rate keeps the 50 percent density increase across its balanced pressure and recovery")
	_check(scene._route_role_weights(Vector2(900, 1000)) != scene._route_role_weights(Vector2(2900, 1100)) and scene._route_role_weights(Vector2(2900, 1100)) != scene._route_role_weights(Vector2(3000, 1950)), "forest, causeway and riverbank have different enemy compositions")
	var foreground := 0
	for wall in scene.terrain.wall_areas:
		if wall.get("foreground_edge", false):
			foreground += 1
			_check(wall.height <= 45.0 and wall.get("collidable", true), "foreground hidden wall is low but still blocks movement")
	_check(foreground >= 5, "hidden field has multiple cutaway foreground wall segments")
	_check(JunglePassTerrain.GATE_COLUMN_RISE <= 160.0 and scene.terrain.gate_columns[0].area.get_center().y < scene.temple_section.boss_area.position.y + 200.0, "gate arch is lowered and moved toward the arena edge")
	scene.queue_free()
	await process_frame
	for prefix in [PREFIX, UNLOCKS]:
		for suffix in ["_a.json", "_b.json"]:
			var path := ProjectSettings.globalize_path(prefix + suffix)
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	if failures == 0: print("V25 feedback verification passed: XP, attack size, density, route roles and sightlines")
	quit(1 if failures else 0)
