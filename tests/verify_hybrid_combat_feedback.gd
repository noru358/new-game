extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _run() -> void:
	var scene = load("res://game/hybrid_height.tscn").instantiate()
	scene.growth_save_prefix = "user://verify_hybrid_combat_feedback"
	root.add_child(scene)
	await _frames(3)
	for companion in scene.growth.wisps:
		companion.set_physics_process(false)
	var lamp: TrainingEnemy
	var fragment: TrainingEnemy
	for actor in scene.actors:
		if actor is TrainingEnemy:
			actor.set_physics_process(false)
			if actor.role == TrainingEnemy.Role.LAMP and lamp == null: lamp = actor
			if actor.role == TrainingEnemy.Role.FRAGMENT and fragment == null: fragment = actor
	_check(lamp != null and fragment != null, "lamp and fragment are available")
	lamp.position = Vector2(930, 1550)
	scene.actor_motion[lamp] = [lamp.position, lamp.position]
	lamp.locked_direction = Vector2.DOWN
	lamp.warning_time = 0.3
	scene._draw_enemy_warnings(1.0)
	var vertices: PackedVector3Array = scene.warning_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var min_y := INF
	var max_y := -INF
	for vertex in vertices:
		min_y = minf(min_y, vertex.y)
		max_y = maxf(max_y, vertex.y)
	_check(max_y - min_y < 0.04 and vertices.size() > 0, "magic shot warning stays in parallel air planes across a ramp and ledge")
	lamp.position = Vector2(1080, 850)
	scene.actor_motion[lamp] = [lamp.position, lamp.position]
	lamp.locked_direction = Vector2.RIGHT
	scene._draw_enemy_warnings(1.0)
	vertices = scene.warning_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var max_x := -INF
	for vertex in vertices: max_x = maxf(max_x, vertex.x)
	_check(max_x <= 11.5 and not scene.warning_visual.material_override.no_depth_test, "magic shot warning stops at the wall and respects terrain depth")
	lamp.warning_time = 0.0
	var zone := EnemyZone.new()
	zone.setup(lamp, scene.player)
	zone.position = Vector2(1100, 850)
	zone.set_physics_process(false)
	scene.simulation.add_child(zone)
	scene._draw_enemy_warnings(1.0)
	vertices = scene.warning_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	min_y = INF
	max_y = -INF
	var min_radius := INF
	var max_radius := 0.0
	for vertex in vertices:
		min_y = minf(min_y, vertex.y)
		max_y = maxf(max_y, vertex.y)
		var radius: float = Vector2(vertex.x, vertex.z).distance_to(zone.position * HybridTerrain.SCALE)
		min_radius = minf(min_radius, radius)
		max_radius = maxf(max_radius, radius)
	_check(max_y - min_y < 0.04 and max_radius > 0.91 and min_radius > 0.80, "zone warning keeps a regular radius and level plane beside a wall")
	_check(not scene._ring_segment_clear(zone.position, 0.0, TAU / 48.0, EnemyZone.RADIUS), "blocked ring sectors are omitted instead of compressed")
	zone.queue_free()
	await _frames(2)
	scene.teleport(Vector2(1300, 850))
	var bolt := EnemyBolt.new()
	bolt.setup(Vector2.RIGHT, 240.0, 12.0)
	bolt.visual_origin = Vector2(1080, 850)
	scene.simulation.add_child(bolt)
	bolt.position = bolt.visual_origin
	bolt.set_physics_process(false)
	await _frames(2)
	var before_wall: Vector3 = scene._shot_world_point(bolt, Vector2(1148, 850))
	var after_wall: Vector3 = scene._shot_world_point(bolt, Vector2(1152, 850))
	_check(absf(after_wall.y - before_wall.y) < 0.08, "magic projectile keeps a smooth airborne height through a terrain boundary")
	bolt.queue_free()
	await _frames(2)
	scene.teleport(Vector2(920, 1640))
	fragment.position = Vector2(920, 1530)
	fragment.set_physics_process(true)
	fragment.stagger_time = 1.0
	var start: Vector2 = fragment.position
	scene.player.set_combo_rank(2)
	scene.player.next_combo_step = 3
	scene.player.facing = Vector2.UP
	scene.player._start_attack()
	await _frames(7)
	_check(fragment.gathering and fragment.gather_target.y > start.y, "third hit starts a pull down the connected slope")
	scene._draw_enemy_warnings(1.0)
	_check(scene.warning_mesh.get_surface_count() > 0, "third hit shows its airborne pull tether and destination")
	await _frames(9)
	_check(fragment.position.y > start.y + 28.0 and scene.terrain.height_at(fragment.position) < scene.terrain.height_at(start), "third hit visibly pulls across a traversable height change")
	fragment.set_physics_process(false)
	fragment.position = Vector2(1120, 850)
	var constrained: Vector2 = scene.player._constrain_gather(fragment, Vector2(1210, 850))
	_check(constrained.x <= 1121.0, "pull destination stays on the enemy's side of a cliff wall")
	scene.queue_free()
	await _frames(2)
	if failures == 0:
		print("Hybrid combat feedback verification passed: planar warnings, regular blocked ring, slope pull, wall-safe gather")
	quit(1 if failures else 0)
