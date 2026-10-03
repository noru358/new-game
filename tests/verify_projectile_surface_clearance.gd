extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var scene = load("res://game/jungle_pass.tscn").instantiate()
	scene.profile_save_prefix = "user://projectile_surface_fixture"
	root.add_child(scene)
	current_scene = scene
	for i in 4: await physics_frame
	var shot := Node2D.new()
	var start := Vector2(3230, 1180)
	var target := Vector2(3500, 1180)
	scene.shot_height_data[shot] = [start, scene.terrain.height_at(start), scene.terrain.height_at(target), start.distance_to(target)]
	var checks := 0
	var failures := 0
	for x in range(3230, 4101, 10):
		var point := Vector2(x, 1180)
		scene.shot_motion[shot] = [point - Vector2(2, 0), point]
		var rendered: Vector3 = scene._shot_world_point(shot, point)
		checks += 1
		if rendered.y < (scene.terrain.height_at(point) + 55.0) * 0.01 - 0.001:
			printerr("FAIL: uphill visual clearance ", point)
			failures += 1
	var flat := Vector2(4700, 900)
	scene.shot_height_data[shot] = [flat, 480.0, 480.0, 500.0]
	if not is_equal_approx(scene._shot_world_point(shot, flat + Vector2(120, 0)).y, 5.35): failures += 1
	var low := Vector2(500, 1200)
	scene.shot_height_data[shot] = [low, 160.0, 0.0, 400.0]
	if not is_equal_approx(scene._shot_world_point(shot, low + Vector2(200, 0)).y, 1.35): failures += 1
	scene.shot_height_data.erase(shot)
	scene.shot_motion.erase(shot)
	shot.free()
	scene.queue_free()
	for i in 3: await process_frame
	print("Projectile visual surface: ", checks + 2, " checks, ", failures, " failures")
	quit(1 if failures else 0)
