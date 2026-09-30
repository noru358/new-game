extends SceneTree
## Deterministic input-driven traversal at 60 physics ticks/sec, not human play.
var failed := false
func _initialize() -> void: call_deferred("_run")
func _release() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "dash"]: Input.action_release(action)
func _move(direction: Vector2) -> void:
	var input := direction.normalized().rotated(PI / 4.0)
	Input.action_press("move_left", maxf(0, -input.x))
	Input.action_press("move_right", maxf(0, input.x))
	Input.action_press("move_up", maxf(0, -input.y))
	Input.action_press("move_down", maxf(0, input.y))
func _leg(scene, target: Vector2, dash: bool) -> Dictionary:
	var path: PackedVector2Array = scene.navigation.find_path(scene.player.position, target)
	if path.is_empty(): return {"ok": false, "seconds": 0.0, "distance": 0.0}
	path.append(target)
	var cursor := 0
	var ticks := 0
	var distance := 0.0
	var old: Vector2 = scene.player.position
	while scene.player.position.distance_to(target) > 15.0 and ticks < 12000:
		while cursor < path.size() - 1 and scene.player.position.distance_to(path[cursor]) < 35.0: cursor += 1
		var next := cursor
		while next < path.size() - 1 and scene.navigation.has_clear_path(scene.player.position, path[next + 1]): next += 1
		cursor = next
		var direction: Vector2 = path[cursor] - scene.player.position
		_move(direction)
		if dash and direction.length() > 180 and scene.player.dash_charges > 0 and scene.player.dash_time <= 0:
			var event := InputEventAction.new()
			event.action = "dash"
			event.pressed = true
			Input.parse_input_event(event)
			event = InputEventAction.new()
			event.action = "dash"
			event.pressed = false
			Input.parse_input_event(event)
		await physics_frame
		ticks += 1
		distance += old.distance_to(scene.player.position)
		old = scene.player.position
	_release()
	await physics_frame
	return {"ok": ticks < 12000, "seconds": ticks / 60.0, "distance": snappedf(distance, 1.0), "end": str(scene.player.position)}
func _run() -> void:
	var scene = load("res://game/canal_city_trial.tscn").instantiate()
	root.add_child(scene)
	for i in 4: await physics_frame
	var results: Array = []
	for dash in [false, true]:
		for route in [
			{"name": "entry_to_market", "points": [scene.CityTerrain.ENTRY, scene.CityTerrain.MARKET]},
			{"name": "market_to_waterfront", "points": [scene.CityTerrain.MARKET, scene.CityTerrain.WATERFRONT]},
			{"name": "sightseeing_return_loop", "points": [scene.CityTerrain.WATERFRONT, scene.CityTerrain.SLUICE, scene.CityTerrain.ENTRY, Vector2(2000, 4200), Vector2(1400, 2750), scene.CityTerrain.MARKET, scene.CityTerrain.WATERFRONT]}
		]:
			scene.teleport(route.points[0])
			scene.player.dash_charges = scene.player.dash_max_charges
			scene.player.dash_cooldown = 0
			for i in 3: await physics_frame
			var seconds := 0.0
			var distance := 0.0
			for i in range(1, route.points.size()):
				var result: Dictionary = await _leg(scene, route.points[i], dash)
				seconds += result.seconds
				distance += result.distance
				if not result.ok:
					printerr("FAIL: traversal stuck ", route.name, " at ", result.end)
					failed = true
					break
			var result := {"route": route.name, "dash": dash, "seconds": snappedf(seconds, 0.01), "ground_distance": distance}
			results.append(result)
			print("MEASURE: ", JSON.stringify(result))
	var output := OS.get_environment("CANAL_MEASURE_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify({"method": "60Hz physics input driven navigation-shortest paths; return loop via authored waypoints, no viewing dwell, no enemies; not human exploration time", "measurements": results}, "  "))
	quit(1 if failed else 0)
