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
	var by_role: Dictionary = {}
	for actor in scene.actors:
		if actor is TrainingEnemy:
			actor.set_physics_process(false)
			by_role[actor.role] = by_role.get(actor.role, 0) + 1
			_check(actor.projectile_parent == scene.simulation and actor.collision_radius == scene.ACTOR_CLEARANCE, "hybrid enemies use hidden 2D projectiles and matching clearance")
	_check(by_role.get(TrainingEnemy.Role.FRAGMENT, 0) == 3 and by_role.get(TrainingEnemy.Role.LAMP, 0) == 2 and by_role.get(TrainingEnemy.Role.BEAST, 0) == 1 and by_role.get(TrainingEnemy.Role.ZONE, 0) == 1 and by_role.get(TrainingEnemy.Role.SUPPORT, 0) == 1, "all five accepted enemy roles are present")
	scene.growth.apply_card("U_CHAIN")
	scene.growth.apply_card("U_CHAIN")
	_check(scene.player.combo_limit() == 4, "growth cards enable the full four-hit combo")
	for step in [3, 4]:
		scene.player.attack_step = step
		scene.player.attack_elapsed = 0.1
		scene.player.attack_direction = Vector2.RIGHT
		scene._draw_attack()
		_check(scene.attack_mesh.get_surface_count() > 0, "hit %d has an airborne attack mesh" % step)
	scene.player.attack_step = 0
	var lamp: TrainingEnemy
	var zone_caster: TrainingEnemy
	var beast: TrainingEnemy
	var support: TrainingEnemy
	var fragment: TrainingEnemy
	for actor in scene.actors:
		if actor is TrainingEnemy:
			match actor.role:
				TrainingEnemy.Role.LAMP: lamp = actor
				TrainingEnemy.Role.ZONE: zone_caster = actor
				TrainingEnemy.Role.BEAST: beast = actor
				TrainingEnemy.Role.SUPPORT: support = actor
				TrainingEnemy.Role.FRAGMENT: fragment = actor
	_check(lamp != null and zone_caster != null and beast != null and support != null and fragment != null, "each role can be inspected")
	scene.teleport(Vector2(2200, 1100))
	lamp.position = Vector2(2100, 1100)
	lamp.locked_direction = Vector2.RIGHT
	lamp.warning_time = 0.3
	scene._draw_enemy_warnings(1.0)
	_check(scene.warning_mesh.get_surface_count() > 0 and not scene.warning_visual.material_override.no_depth_test, "ranged warning is visible but obeys terrain depth")
	lamp.warning_time = 0.0
	var health_before: float = scene.player.health
	lamp._fire_bolt()
	var bolts := get_nodes_in_group("enemy_bolts")
	_check(bolts.size() == 1 and bolts[0].get_parent() == scene.simulation, "enemy projectile stays in the hidden simulation plane")
	await _frames(35)
	_check(scene.player.health < health_before, "3D-presented ranged projectile retains its 2D hit")
	scene.player.hurt_immunity = 0.0
	scene.teleport(Vector2(1175, 840))
	zone_caster.position = Vector2(1130, 840)
	var blocked_zone := EnemyZone.new()
	blocked_zone.setup(zone_caster, scene.player)
	blocked_zone.damage_path_filter = scene.clear_attack
	blocked_zone.warning_time = 0.0
	scene.simulation.add_child(blocked_zone)
	blocked_zone.position = zone_caster.position
	health_before = scene.player.health
	await _frames(3)
	_check(scene.player.health == health_before, "zone damage cannot pass through a cliff in hybrid combat")
	blocked_zone.queue_free()
	support.position = fragment.position + Vector2(80, 0)
	_check(fragment._has_support_aura(), "support enemy still strengthens nearby allies")
	beast.warning_time = 0.2
	beast.locked_direction = Vector2.RIGHT
	scene._draw_enemy_warnings(1.0)
	_check(scene.warning_mesh.get_surface_count() > 0, "charging enemy gets a 3D warning")
	scene.queue_free()
	await _frames(3)
	if failures == 0:
		print("Hybrid roles verification passed: four-hit growth, five roles, depth-tested warnings, bolt hit, blocked zone and support")
	quit(1 if failures else 0)
