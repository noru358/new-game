extends SceneTree

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node2D = load("res://game/view_prototype.tscn").instantiate()
	root.add_child(scene)
	await _frames(3)
	var player: SandboxPlayer = scene.get_node("Player")
	var wisp: WispCompanion = scene.get_node("Wisp")
	var enemies: Node2D = scene.get_node("Enemies")
	player.hurt_immunity = 100.0
	wisp.set_physics_process(false)
	for enemy in enemies.get_children():
		enemy.set_physics_process(false)
		enemy.global_position = Vector2(2200, 1250)
	for prop in scene.view_props:
		var left: Vector2 = prop.global_position + Vector2(-100, 0)
		var right: Vector2 = prop.global_position + Vector2(100, 0)
		_check(not scene.arena_navigation.has_clear_path(left, right) and not scene.arena_navigation.find_path(left, right).is_empty(), "each ruin has a route around its footprint")

	var chaser: TrainingEnemy = enemies.get_node("FragmentE")
	player.global_position = Vector2(1360, 755)
	chaser.global_position = Vector2(1180, 755)
	_check(not scene.arena_navigation.has_clear_path(chaser.global_position, player.global_position), "ruin blocks direct pursuit")
	_check(not scene.arena_navigation.find_path(chaser.global_position, player.global_position).is_empty(), "route around ruin exists")
	chaser.set_physics_process(true)
	await _frames(300)
	_check(chaser.global_position.distance_to(player.global_position) < 72.0, "enemy routes around ruin instead of stopping behind it")
	chaser.set_physics_process(false)
	chaser.global_position = Vector2(2200, 1250)

	var moving: TrainingEnemy = enemies.get_node("FragmentF")
	wisp.global_position = Vector2(1180, 755)
	moving.global_position = Vector2(1320, 690)
	await _frames(2)
	_check(wisp._blocked_by_wall(moving.global_position), "ruin occludes enemy center")
	_check(not wisp._visible_aim_point(moving).is_empty() and wisp.find_target() == moving, "wisp acquires exposed edge of partially hidden enemy")

	player.global_position = Vector2(1150, 650)
	wisp.global_position = Vector2(1130, 650)
	moving.global_position = Vector2(1380, 650)
	await _frames(2)
	_check(wisp.find_target() == moving, "wisp acquires exposed enemy")
	var before := moving.health
	var shot := WispProjectile.new()
	shot.setup(Vector2.RIGHT, 620.0, 520.0, 6.5)
	shot.target = moving
	scene.add_child(shot)
	shot.global_position = wisp.global_position
	await _frames(3)
	moving.global_position.y += 43.0
	await _frames(36)
	_check(moving.health < before, "brief homing lands on enemy moving across original shot line")

	var growth: RunGrowth = scene.get_node("RunGrowth")
	for i in range(3):
		growth.apply_card("S_WISP_DAMAGE")
	_check(is_equal_approx(wisp.damage_multiplier, 1.55) and wisp.power_rank == 3, "three power ranks raise projectile damage and impact")
	moving.health = moving.max_health
	moving.global_position = Vector2(1350, 650)
	wisp._fire(moving)
	await _frames(25)
	_check(is_equal_approx(moving.health, moving.max_health - 15.5), "fully upgraded wisp hit deals increased damage")
	var strong_flash := false
	for flash in get_nodes_in_group("wisp_flashes"):
		if flash.power_rank == 3:
			strong_flash = true
	_check(strong_flash, "upgraded wisp hit creates stronger impact flash")
	growth.unlocks.lifetime_levelups = 4
	growth.apply_card("S_WISP_ORBIT")
	growth.apply_card("S_WISP_ORBIT")
	_check(is_equal_approx(wisp.orbit_damage, 7.0), "orbit rank two increases contact damage")
	scene.queue_free()
	await _frames(3)
	if failed:
		printerr("1D feedback verification failed")
		quit(1)
	else:
		print("1D feedback verification passed: obstacle routing, moving-target homing, upgraded wisp impact")
		quit(0)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL: ", label)
