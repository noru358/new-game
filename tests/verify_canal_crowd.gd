extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var city: Node3D = load("res://game/canal_city_trial.tscn").instantiate()
	root.add_child(city)
	await process_frame
	city.teleport(Vector2(5190, 3100))
	var crowd: Array[TrainingEnemy] = []
	for i in 5:
		crowd.append(city._spawn_enemy_at(Vector2(5120 + (i % 3) * 42, 1780 + (i / 3) * 55), TrainingEnemy.Role.FRAGMENT, 22.0))
	for frame in 720: await physics_frame
	var crossed := 0
	for enemy in crowd:
		if not is_instance_valid(enemy) or enemy.health <= 0: continue
		if enemy.global_position.y > 2720: crossed += 1
		for water in city.terrain.water_areas:
			_check(not water.has_point(enemy.global_position), "crowd remains out of canal")
	_check(crossed >= 3, "at least three enemies crossed the eastern bridge; actual=%d" % crossed)
	print("Canal crowd: %d/5 crossed eastern bridge, failures=%d" % [crossed, failures])
	city.queue_free()
	await process_frame
	quit(1 if failures else 0)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)
