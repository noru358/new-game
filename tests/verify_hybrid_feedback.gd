extends SceneTree

var failures := 0

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://game/hybrid_height.tscn").instantiate()
	root.add_child(scene)
	await _frames(4)
	scene.wisp.set_physics_process(false)
	for actor in scene.actors:
		if actor is TrainingEnemy:
			actor.set_physics_process(false)
	_check(is_equal_approx(scene.camera.size, scene.COMBAT_CAMERA_SIZE) and scene.camera.size < 14.4, "combat view uses the closer camera")
	_check(scene.player.move_speed_multiplier > 1.0 and scene.player.dash_distance_multiplier > 1.0, "hybrid combat has faster travel")
	var strike: Dictionary = scene.player._attack_spec(1)
	_check(strike.active > 0.08 and strike.windup + strike.active + strike.recovery < 0.25, "slash remains hittable for a visible beat without slowing the combo")
	scene.teleport(Vector2(1080, 1000))
	scene.player.attack_step = 1
	scene.player.attack_elapsed = 0.10
	scene.player.attack_direction = Vector2.RIGHT
	scene._draw_attack()
	_check(scene.attack_mesh.get_surface_count() > 0, "active attack has a visible filled mesh")
	var vertices: PackedVector3Array = scene.attack_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var lowest := INF
	var highest := -INF
	var furthest := 0.0
	for vertex in vertices:
		lowest = minf(lowest, vertex.y / HybridTerrain.SCALE)
		highest = maxf(highest, vertex.y / HybridTerrain.SCALE)
		furthest = maxf(furthest, Vector2(vertex.x, vertex.z).distance_to(scene.player.position * HybridTerrain.SCALE) / HybridTerrain.SCALE)
	var ground_height: float = scene.terrain.height_at(scene.player.position)
	_check(lowest >= ground_height + 69.9 and highest <= ground_height + 90.1, "attack stays in the air at fixed elevations, even near changing terrain (ground %.2f, min %.2f, max %.2f)" % [ground_height, lowest, highest])
	_check(furthest >= strike.radius + scene.ACTOR_CLEARANCE and furthest <= strike.radius + scene.ACTOR_CLEARANCE + 2.1, "visible reach includes the enemy body radius used by melee")
	_check(not scene.attack_visual.material_override.no_depth_test, "terrain depth hides the air slash behind a cliff")
	var slash_origin: Vector2 = scene.player.position
	scene._draw_attack_at(slash_origin, strike.windup + strike.active * 0.30, Vector2.RIGHT)
	var earlier: PackedVector3Array = scene.attack_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	scene._draw_attack_at(slash_origin, strike.windup + strike.active * 0.42, Vector2.RIGHT)
	var later: PackedVector3Array = scene.attack_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	_check(earlier[earlier.size() - 1].distance_to(later[later.size() - 1]) > 0.01, "blade motion advances between physics ticks")
	scene.actor_motion[scene.player] = [Vector2(1000, 1000), Vector2(1040, 1000)]
	_check(scene._render_position(scene.player, 0.5).is_equal_approx(Vector2(1020, 1000)), "actor presentation interpolates between physics positions")
	scene.teleport(Vector2(1120, 840))
	scene.player.attack_direction = Vector2.RIGHT
	scene._draw_attack()
	_check(scene._attack_reach(0.0, strike.radius + scene.ACTOR_CLEARANCE) < 40.0 and scene.attack_mesh.get_surface_count() > 0, "bright reach stops at the cliff while the airborne slash remains")
	scene.player.attack_step = 0
	scene.teleport(Vector2(1180, 840))
	scene.wisp.set_physics_process(true)
	await _frames(12)
	Input.action_press("move_left")
	Input.action_press("move_up")
	var stable_wall_visual := true
	for i in 75:
		await physics_frame
		if scene.terrain.height_at(scene.player.position) != 320.0 or scene.terrain.height_at(scene.wisp.position) != 320.0:
			stable_wall_visual = false
		if absf(scene.actors[scene.player].position.y - 3.2) > 0.01:
			stable_wall_visual = false
	Input.action_release("move_left")
	Input.action_release("move_up")
	scene.wisp.set_physics_process(false)
	_check(stable_wall_visual, "player and wisp keep a stable level while pressed against a cliff")
	_check(scene.player.get_node("CollisionShape2D").shape.radius == scene.ACTOR_CLEARANCE and scene.player.position.x >= 1185.0, "actor collision keeps the sprite clear of the terrace side")
	scene.teleport(Vector2(1250, 840))
	var pursuer: TrainingEnemy
	for actor in scene.actors:
		if actor is TrainingEnemy:
			pursuer = actor
			break
	pursuer.position = Vector2(1127, 840)
	pursuer.velocity = Vector2.ZERO
	pursuer.knockback = Vector2.ZERO
	pursuer.navigation_path.clear()
	pursuer.navigation_repath_time = 0.0
	pursuer.set_physics_process(true)
	var path: PackedVector2Array = scene.navigation.find_path(pursuer.position, scene.player.position)
	_check(path.size() > 2 and scene.navigation.has_clear_path(pursuer.position, path[0]), "route starts on enemy's reachable side of the cliff")
	var reached_ramp := false
	for i in 850:
		await physics_frame
		if pursuer.position.y > 915.0:
			reached_ramp = true
	_check(reached_ramp and pursuer.position.distance_to(scene.player.position) < 130.0, "enemy uses nearby ramp to reach upper-floor player (at %s, distance %.1f, reached ramp %s, route %s)" % [pursuer.position, pursuer.position.distance_to(scene.player.position), reached_ramp, path])
	scene.teleport(Vector2(1290, 1390))
	scene.player.hurt_immunity = 1000.0
	pursuer.position = Vector2(1290, 1840)
	pursuer.velocity = Vector2.ZERO
	pursuer.knockback = Vector2.ZERO
	pursuer.navigation_path.clear()
	pursuer.navigation_repath_time = 0.0
	await _frames(290)
	_check(scene.terrain.height_at(pursuer.position) == 160.0 and pursuer.position.distance_to(scene.player.position) < 90.0, "enemy ascends connected stone path to upper-floor player")
	scene.queue_free()
	await _frames(3)
	if failures == 0:
		print("Hybrid feedback verification passed: camera, air slash reach, mobility, wall clearance and both cliff detours")
	quit(1 if failures else 0)
