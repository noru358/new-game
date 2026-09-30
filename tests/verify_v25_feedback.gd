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
	_check(scene.growth.xp_bar.visible and scene.growth.xp_bar.position.y > scene.growth.hud.position.y and scene.build_summary_label.position.x > scene.growth.xp_bar.position.x + scene.growth.xp_bar.size.x, "XP number and progress bar are visible without covering card summary")
	scene.growth.gain_xp(2)
	_check(scene.growth.xp_bar.value == 2.0 and scene.growth.hud.text.contains("경험치 2 / 8"), "visible XP changes with a real award")
	var player_scale_before: Vector3 = scene.actors[scene.player].get_node("Body").scale
	scene.player.attack_step = 4
	scene._process(0.016)
	_check(scene.actors[scene.player].get_node("Body").scale == player_scale_before, "fourth attack does not enlarge the player in either view mode")
	_check(is_equal_approx(scene._spawn_rate(), 0.90) and scene.MAX_ENEMIES == 72, "early ambient rate and headroom grow by 50 percent")
	scene.run_time = 200.0
	_check(is_equal_approx(scene._spawn_rate(), 2.10), "late ambient rate also grows by 50 percent")
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
