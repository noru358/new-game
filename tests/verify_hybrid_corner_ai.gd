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
	var pursuer: TrainingEnemy
	for actor in scene.actors:
		if actor is TrainingEnemy:
			actor.set_physics_process(false)
			if pursuer == null:
				pursuer = actor
	scene.player.hurt_immunity = 1000.0
	# These contacts used to pick a waypoint on the other side of the cliff
	# and run into its corner forever, despite a reachable stone connection.
	for pair in [
		[Vector2(1200, 1518), Vector2(1290, 1650)],
		[Vector2(1190, 1650), Vector2(1290, 1430)],
		[Vector2(1385, 1518), Vector2(1290, 1430)]
	]:
		scene.teleport(pair[1])
		pursuer.position = pair[0]
		pursuer.velocity = Vector2.ZERO
		pursuer.knockback = Vector2.ZERO
		pursuer.stagger_time = 0.0
		pursuer.navigation_path.clear()
		pursuer.navigation_repath_time = 0.0
		var path: PackedVector2Array = scene.navigation.find_path(pursuer.position, scene.player.position)
		_check(path.size() > 2 and scene.navigation.has_clear_path(pursuer.position, path[0]), "first waypoint is reachable at %s" % pair[0])
		pursuer.set_physics_process(true)
		await _frames(600)
		pursuer.set_physics_process(false)
		_check(pursuer.position.distance_to(scene.player.position) < 45.0, "enemy routes around corner and reaches stone path from %s (ended %s)" % [pair[0], pursuer.position])
	scene.queue_free()
	await _frames(3)
	if failures == 0:
		print("Hybrid corner AI verification passed: three cliff contacts route through the stepping stones")
	quit(1 if failures else 0)
