extends SceneTree

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node2D = load("res://game/temple_region.tscn").instantiate()
	root.add_child(scene)
	await _frames(3)
	var player: SandboxPlayer = scene.player
	var enemies: Node2D = scene.get_node("Enemies")
	for enemy in enemies.get_children():
		enemy.set_physics_process(false)
	scene.wisp.set_physics_process(false)
	_check(ProjectSettings.get_setting("application/run/main_scene") == "res://game/temple_region.tscn", "new region is the launch scene")
	_check(scene.REGION_SIZE == Vector2(3840, 2160) and player.arena_bounds.size == scene.REGION_SIZE, "scrolling region uses expanded actor bounds")
	_check(scene.camera.limit_right == 3840 and scene.camera.limit_bottom == 2160, "camera follows the expanded region")
	_check(scene.arena_navigation.grid_size == Vector2i(120, 68), "navigation covers the full region")
	_check(scene.arena_navigation.obstacles.size() == 11 and scene.arena_navigation.rectangular_obstacles.size() == 10, "pillars, water and walls share navigation")
	var growth_rect := Rect2(scene.growth.hud.position, scene.growth.hud.get_combined_minimum_size())
	var region_rect := Rect2(scene.region_label.position, scene.region_label.get_combined_minimum_size())
	_check(not growth_rect.intersects(region_rect), "region label stays clear of growth information")
	_check(scene.current_region_name(Vector2(700, 1000)) == "수변 마당" and scene.current_region_name(Vector2(1800, 1000)) == "사원 뜰" and scene.current_region_name(Vector2(2700, 1000)) == "회랑" and scene.current_region_name(Vector2(3150, 1000)) == "성소", "four spaces have separate identities")

	var clear_bridge: bool = scene.arena_navigation.has_clear_path(Vector2(1020, 410), Vector2(1020, 620))
	var blocked_water: bool = not scene.arena_navigation.has_clear_path(Vector2(600, 410), Vector2(600, 620))
	_check(clear_bridge and blocked_water, "water channel has a broad usable opening")
	var ray := PhysicsRayQueryParameters2D.create(Vector2(600, 410), Vector2(600, 620), 4)
	var water_hit := scene.get_world_2d().direct_space_state.intersect_ray(ray)
	_check(not water_hit.is_empty() and water_hit.collider is TempleBlock, "water collision matches navigation")
	_check(not scene.arena_navigation.find_path(Vector2(800, 300), Vector2(800, 1000)).is_empty(), "north bank connects through the crossing")
	_check(not scene.arena_navigation.has_clear_path(Vector2(3200, 1100), Vector2(3700, 1100)) and not scene.arena_navigation.find_path(Vector2(3200, 1100), Vector2(3700, 1100)).is_empty(), "sanctuary wall blocks shortcuts but leaves a route")
	for point in [Vector2(600, 800), Vector2(1600, 1050), Vector2(2250, 1800), Vector2(2750, 1080), Vector2(3150, 980), Vector2(1970, 300)]:
		_check(scene.can_spawn_at(point), "each region has a reachable spawn candidate at %s" % point)
	_check(not scene.can_spawn_at(Vector2(600, 500)) and not scene.can_spawn_at(player.global_position), "water and the player start are excluded from spawning")
	var chaser: TrainingEnemy = enemies.get_node("FragmentA")
	player.global_position = Vector2(600, 710)
	player.hurt_immunity = 100.0
	chaser.global_position = Vector2(600, 410)
	chaser.set_physics_process(true)
	await _frames(120)
	_check(absf(chaser.global_position.x - 600.0) > 80.0, "chaser moves toward a water crossing instead of pushing into the bank")
	chaser.set_physics_process(false)

	player.global_position = Vector2(3900, 2200)
	await _frames(2)
	_check(player.global_position.x <= 3815.0 and player.global_position.y <= 2135.0, "player stays within the full new map")
	for enemy in enemies.get_children():
		enemy.queue_free()
	await _frames(2)
	scene.remaining_enemies = 0
	scene._next_practice_wave()
	_check(enemies.get_child_count() == 8 and scene.remaining_enemies == 8, "repeat wave retains all enemy roles")
	for i in range(enemies.get_child_count()):
		var enemy: TrainingEnemy = enemies.get_child(i)
		_check(enemy.global_position == scene.ENEMY_POINTS[i] and enemy.arena_bounds.size == scene.REGION_SIZE, "repeat wave uses region positions and bounds")
	scene.queue_free()
	await _frames(3)
	if failed:
		printerr("1F verification failed")
		quit(1)
	else:
		print("1F verification passed: region identity, scrolling bounds, water crossing, walls, spawn areas, repeat wave")
		quit(0)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL: ", label)
