extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _frames(count: int) -> void:
	for i in count: await physics_frame

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _walk(direction: Vector2, count: int, player: SandboxPlayer, dash := false) -> void:
	var screen := direction.rotated(PI / 4.0)
	var actions: Array[String] = []
	if screen.x > 0.1: actions.append("move_right")
	if screen.x < -0.1: actions.append("move_left")
	if screen.y > 0.1: actions.append("move_down")
	if screen.y < -0.1: actions.append("move_up")
	for action in actions: Input.action_press(action)
	if dash:
		player.dash_charges = 2
		player.dash_requested = true
	await _frames(count)
	for action in actions: Input.action_release(action)
	await _frames(2)

func _run() -> void:
	var scene = load("res://game/hybrid_height.tscn").instantiate()
	root.add_child(scene)
	await _frames(4)
	scene.wisp.set_physics_process(false)
	var enemies: Array = []
	for actor in scene.actors:
		if actor is TrainingEnemy:
			actor.set_physics_process(false)
			enemies.append(actor)
	scene.player.hurt_immunity = 1000.0
	_check(scene.terrain.height_at(Vector2(300, 300)) == 0 and scene.terrain.height_at(Vector2(700, 700)) == 160 and scene.terrain.height_at(Vector2(1300, 1000)) == 320, "lowland, courtyard and terrace have distinct heights")
	_check(is_equal_approx(scene.terrain.height_at(Vector2(930, 350)), 80) and is_equal_approx(scene.terrain.height_at(Vector2(1000, 1000)), 240), "both levels interpolate continuously on ramps")
	for route in [[Vector2(930, 1850), Vector2.UP, 120], [Vector2(930, 150), Vector2.DOWN, 100], [Vector2(2200, 1180), Vector2.LEFT, 100]]:
		scene.teleport(route[0])
		await _walk(route[1], route[2], scene.player)
		_check(is_equal_approx(scene.terrain.height_at(scene.player.position), 160), "front, back and side entries reach courtyard: %s" % route[0])
	_check(scene.terrain.surface_name(Vector2(1290, 1640)) == "디딤돌" and is_equal_approx(scene.terrain.height_at(Vector2(1290, 1640)), 80.0), "stepping stones share the same single-surface height data")
	scene.teleport(Vector2(1290, 1840))
	await _walk(Vector2.UP, 90, scene.player)
	_check(scene.terrain.height_at(scene.player.position) == 160.0, "stepping stones provide a second walkable connection to the courtyard")
	scene.teleport(Vector2(1290, 1640))
	await _walk(Vector2.RIGHT, 30, scene.player, true)
	_check(scene.player.position.x < 1370.0, "stepping-stone side stops a dash into the cliff")
	scene.teleport(Vector2(780, 1000))
	await _walk(Vector2.RIGHT, 140, scene.player)
	_check(is_equal_approx(scene.terrain.height_at(scene.player.position), 320), "terrace reached through actual ramp")
	_check(scene.actors[scene.player].position.distance_to(scene.terrain.world_point(scene.player.position)) < 0.01, "3D feet track simulated position and sampled elevation")
	for edge in [[Vector2(1530, 1000), Vector2.RIGHT], [Vector2(1370, 860), Vector2.UP], [Vector2(1370, 1140), Vector2.DOWN], [Vector2(1210, 850), Vector2.LEFT]]:
		scene.teleport(edge[0])
		await _walk(edge[1], 30, scene.player, true)
		_check(scene.terrain.height_at(scene.player.position) == 320, "dash cannot exit terrace through cliff: %s" % edge[1])
	scene.teleport(Vector2(720, 1580))
	await _walk(Vector2.UP, 50, scene.player)
	_check(scene.player.position.y > 1500 and scene.terrain.height_at(scene.player.position) == 0, "walking cannot climb courtyard side wall")
	var target: TrainingEnemy = enemies[0]
	for enemy in enemies: enemy.health = 0
	target.health = 100
	target.max_health = 100
	scene.teleport(Vector2(1130, 840))
	target.position = Vector2(1175, 840)
	await _frames(3)
	scene.player.attack_direction = Vector2.RIGHT
	scene.player.hit_targets.clear()
	scene.player.attack_step = 1
	scene.player._hit_enemies(scene.player._attack_spec(1))
	_check(target.health == 100, "melee cannot strike through vertical cliff")
	scene.wisp.position = scene.player.position
	_check(scene.wisp._visible_aim_point(target).is_empty(), "wisp cannot aim through cliff")
	var constrained: Vector2 = scene._constrain_wisp(target.position)
	_check(constrained.x < 1150.0 and constrained.distance_to(scene.player.position) < scene.player.position.distance_to(target.position), "companion remains on player's side of cliff without snapping to player")
	var shot := WispProjectile.new()
	shot.setup(Vector2.RIGHT, 620, 520, 10)
	scene.simulation.add_child(shot)
	shot.position = scene.player.position
	await _frames(15)
	_check(target.health == 100 and not is_instance_valid(shot), "projectile stops at cliff without hitting enemy beyond")
	scene.teleport(Vector2(1020, 1000))
	target.position = Vector2(1120, 1000)
	await _frames(3)
	scene.player.hit_targets.clear()
	scene.player.attack_step = 1
	scene.player.attack_direction = Vector2.RIGHT
	scene.player._hit_enemies(scene.player._attack_spec(1))
	_check(target.health < 100, "melee works between different heights on connected ramp")
	var previous_health := target.health
	scene.wisp.position = Vector2(990, 1000)
	scene.wisp.fire_cooldown = 0
	scene.wisp.set_physics_process(true)
	await _frames(65)
	_check(target.health < previous_health and scene.wisp.shots_fired > 0, "wisp finds camera-visible target and hits along ramp")
	scene.wisp.set_physics_process(false)
	scene.player.attack_step = 0
	scene.teleport(Vector2(930, 750))
	target.position = Vector2(930, 170)
	target.knockback = Vector2.ZERO
	target.stagger_time = 0
	target.navigation_path.clear()
	target.navigation_repath_time = 0
	target.set_physics_process(true)
	await _frames(150)
	_check(target.position.y > 350 and scene.terrain.height_at(target.position) > 60, "existing 2D enemy navigation ascends northern ramp")
	scene._set_paused(true)
	var paused_position := target.position
	await _frames(10)
	_check(target.position == paused_position, "pause freezes simulation")
	scene._set_paused(false)
	scene.queue_free()
	await _frames(3)
	if failures == 0: print("Hybrid height verification passed: four ramps, stepping stones, terrace/walking/dash barriers, melee, wisp targeting/projectiles, pursuit, visual height and pause")
	quit(1 if failures else 0)
