extends SceneTree

var failures := 0
func _initialize() -> void: call_deferred("_run")
func _frames(count: int) -> void:
	for i in count: await physics_frame
func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)
func _save_bytes() -> Dictionary:
	var snapshot := {}
	for prefix in ["user://loop_conquest_profile", "user://loop_conquest_1d_unlocks"]:
		for suffix in ["_a.json", "_b.json"]:
			var path: String = prefix + suffix
			snapshot[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	return snapshot

func _run() -> void:
	# Read-only guard: never seed, overwrite or remove a real player's saves.
	var original_saves := _save_bytes()
	var scene = load("res://game/canal_city_trial.tscn").instantiate()
	# Retain direct coverage of the original alpha comparison.
	scene.overhead_occlusion_enabled = false
	root.add_child(scene)
	current_scene = scene
	await _frames(4)
	_check(scene.camera.size == 9.0 and scene.player.move_speed_multiplier == 1.12 and scene.player.dash_distance_multiplier == 1.16, "v25 camera and movement baseline preserved")
	_check(scene.terrain.map_size == Vector2(7200, 4800), "authoring-layout v2 scale retained")
	_check(scene.actors.size() == 1 and scene.growth.growth_ended, "starts scenery-only with progression disabled")
	_check(scene.growth.unlocks.save_prefix != "user://loop_conquest_1d_unlocks", "trial never reads the live progression prefix")
	for point in [scene.CityTerrain.ENTRY, scene.CityTerrain.MARKET, scene.CityTerrain.WAREHOUSE, scene.CityTerrain.WATERFRONT, scene.CityTerrain.SLUICE]:
		_check(scene.navigation.is_open(point, 30), "landmark is unobstructed: %s" % point)
		_check(scene.navigation.find_path(scene.CityTerrain.ENTRY, point).size() > 0, "connected landmark route: %s" % point)
	for bridge in scene.CityTerrain.BRIDGES:
		_check(scene.navigation.is_open(bridge.get_center(), 30), "bridge is a real dry opening")
	_check(not scene.navigation.is_open(Vector2(2200, 2200), 30), "canal blocks movement")
	_check(not scene.navigation.is_open(Vector2(490, 350), 30), "shop body blocks movement")
	_check(not scene.clear_attack(Vector2(2100, 1920), Vector2(2100, 2500)), "water blocks combat")
	_check(scene.clear_attack(Vector2(1400, 1920), Vector2(1400, 2500)), "bridge permits combat")
	_check(scene.building_visuals.size() == scene.terrain.buildings.size(), "every building collision record has a visual cluster")
	# The new facing shop row cannot close the market selling lane or its
	# alternate connections to the east quarter and cargo quay.
	for point in [Vector2(2500, 1570), Vector2(3020, 1060), Vector2(5500, 1510), scene.CityTerrain.WAREHOUSE]:
		_check(scene.navigation.is_open(point, 30) and scene.navigation.find_path(scene.CityTerrain.MARKET, point).size() > 0, "market/cargo connections remain open: %s" % point)
	# Compatibility ignores GeometryInstance transparency. Check the actual
	# alpha-material path and its restoration, not that unsupported property.
	for point in [scene.CityTerrain.ENTRY, scene.CityTerrain.MARKET, scene.CityTerrain.WATERFRONT]:
		scene.teleport(point)
		await _frames(3)
		await process_frame
		await process_frame
		var faded_count := 0
		for item in scene.building_visuals + scene.landmark_visuals:
			for mesh in item.root.get_children():
				if mesh is MeshInstance3D and mesh.material_override.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
					faded_count += 1
					_check(mesh.material_override.albedo_color.a <= 0.2, "foreground architecture gives clear actor sight")
		_check(faded_count > 0, "foreground facade/gate fades at the real checkpoint")
	scene.overview = true
	await _frames(3)
	await process_frame
	await process_frame
	for item in scene.building_visuals + scene.landmark_visuals:
		for mesh in item.root.get_children():
			if mesh is MeshInstance3D:
				_check(mesh.material_override == mesh.get_meta("solid_material"), "overview restores solid architecture without changing collision")
	scene.overview = false
	# The east market enemy sits behind a new shop from the camera while the
	# player does not. Its visible attack area needs the same protection.
	scene.teleport(scene.CityTerrain.MARKET)
	scene.combat_enabled = true
	scene._spawn_enemy_at(Vector2(2480, 1690), TrainingEnemy.Role.FRAGMENT, 100.0)
	await _frames(3)
	await process_frame
	await process_frame
	var east_shop: Dictionary = scene.building_visuals.filter(func(item): return item.area.position == Vector2(2360, 1720))[0]
	_check(east_shop.root.get_child(0).material_override.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "on-screen enemy occluder fades even when it does not cover the player")
	scene.set_combat_enabled(false)
	await _frames(3)
	await process_frame
	await process_frame
	_check(east_shop.root.get_child(0).material_override.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "enemy-only fade restores after combat clears")
	scene.teleport(scene.CityTerrain.ENTRY)
	await _frames(3)
	for point in scene.ENCOUNTERS:
		_check(scene.navigation.is_open(point, 30), "limited enemy point stays off water/buildings")
		scene.navigation.find_path(point, scene.CityTerrain.MARKET)
	scene.set_combat_enabled(true)
	await _frames(66)
	_check(scene.actors.size() == 9, "limited eight enemies, no ambient spawner")
	scene.growth.gain_xp(100)
	_check(scene.growth.xp == 0 and scene.growth.unlocks.generation == 0, "trial cannot award XP or persist unlocks")
	scene.set_combat_enabled(false)
	await _frames(3)
	_check(scene.actors.size() == 1 and get_nodes_in_group("enemy_bolts").is_empty() and get_nodes_in_group("enemy_zones").is_empty(), "scenery toggle clears enemies and combat residue")
	# A real enemy may be freed before the visual dictionary cleanup tick.
	# Both trial loops must validate it before inspecting its script type.
	var expired = scene._spawn_enemy_at(Vector2(2700, 1550), TrainingEnemy.Role.FRAGMENT, 100.0)
	expired.free()
	scene.combat_enabled = true
	scene._process(0.0)
	scene._physics_process(0.0)
	scene.set_combat_enabled(false)
	await _frames(3)
	_check(scene.actors.size() == 1, "canal visibility and simulation safely clear a freed actor")
	# A 150-unit rear towpath leaves real grid space as well as player space.
	# The initial 70-unit gap admitted the player but stranded enemy navigation.
	scene.teleport(Vector2(1660, 1925))
	for action in ["move_right", "move_down"]: Input.action_press(action)
	await _frames(70)
	for action in ["move_right", "move_down"]: Input.action_release(action)
	await _frames(2)
	_check(scene.player.position.x > 2000 and scene.navigation.find_path(scene.player.position, scene.CityTerrain.MARKET).size() > 0, "physical market rear-lane travel stays connected to pursuit navigation")
	_check(scene.navigation.find_path(Vector2(2530, 1960), scene.CityTerrain.MARKET).size() > 0, "east shop rear edge is not a player-only safe pocket")
	# Actual input and physics: walk across the western bridge, then back.
	scene.teleport(Vector2(1400, 1850))
	for action in ["move_left", "move_down"]: Input.action_press(action)
	await _frames(145)
	for action in ["move_left", "move_down"]: Input.action_release(action)
	await _frames(2)
	_check(scene.player.position.y > 2500, "physical actor crosses bridge southward")
	for action in ["move_right", "move_up"]: Input.action_press(action)
	await _frames(145)
	for action in ["move_right", "move_up"]: Input.action_release(action)
	await _frames(2)
	_check(scene.player.position.y < 1950, "physical actor returns across bridge")
	scene.teleport(Vector2(2200, 1920))
	for action in ["move_left", "move_down"]: Input.action_press(action)
	await _frames(50)
	for action in ["move_left", "move_down"]: Input.action_release(action)
	_check(scene.player.position.y < 1975, "actual movement cannot enter water")
	# Six unmodified chasers traverse the same bridge as the player. No new AI.
	scene.teleport(Vector2(1400, 2790))
	scene.player.hurt_immunity = 1000.0
	for companion in scene.growth.wisps: companion.set_physics_process(false)
	var crowd: Array = []
	for i in 6:
		crowd.append(scene._spawn_enemy_at(Vector2(1290 + (i % 3) * 100, 1850 - (i / 3) * 90), TrainingEnemy.Role.FRAGMENT, 100.0))
	await _frames(780)
	var crossed := 0
	for enemy in crowd:
		if enemy.position.y > 2450: crossed += 1
	_check(crossed == 6, "all six existing chasers cross bridge without getting stuck")
	scene.set_combat_enabled(false)
	await _frames(2)
	var elapsed: float = scene.trial_elapsed
	scene._set_paused(true)
	await _frames(3)
	_check(scene.trial_elapsed == elapsed, "pause freezes simulation")
	scene._set_paused(false)
	_check(_save_bytes() == original_saves, "trial leaves live profile/unlock bytes and absence unchanged")
	scene._return_to_camp()
	await _frames(5)
	_check(current_scene != null and current_scene.get("preparation") != null, "trial returns to real camp flow")
	_check(_save_bytes() == original_saves, "return to camp preserves all live save bytes")
	current_scene.preparation._depart_canal_trial()
	await _frames(5)
	_check(current_scene != null and current_scene.get("combat_enabled") == false, "camp dev entry starts a fresh scenery trial")
	_check(_save_bytes() == original_saves, "reentering trial preserves all live save bytes")
	current_scene.queue_free()
	await _frames(2)
	print("PASS: canal-city isolation, shared terrain, traversal and limited combat" if failures == 0 else "FAIL: %d canal-city checks" % failures)
	quit(1 if failures else 0)
