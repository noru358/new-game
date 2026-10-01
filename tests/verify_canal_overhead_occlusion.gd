extends SceneTree
## Focused two-landmark verification. Optional real-render pairs and normal-speed
## local passage inputs; no house rewrite, progression, or performance acceptance.
const Candidate = preload("res://game/canal_overhead_occlusion.gd")
var scene
var candidate
var failures := 0
var checks := 0
var output := ""
var captures: Array = []
var routes: Array = []
var held: Dictionary = {}

class Driver extends Node:
	var fixture
	func _process(delta: float) -> void: fixture.candidate.update(fixture.scene, delta)

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	output = OS.get_environment("CANAL_OVERHEAD_OUTPUT")
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	scene = load("res://game/canal_city_trial.tscn").instantiate()
	# Independent fixture owns its candidate if a later scene mount adds this flag.
	for property in scene.get_property_list():
		if property.name == "overhead_occlusion_enabled": scene.set(property.name, false)
	root.add_child(scene)
	current_scene = scene
	for i in 5: await process_frame
	scene.set_process(false)
	scene.set_physics_process(false)
	scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
	var barriers: Array = scene.terrain.barriers().duplicate(true)
	var camera_size: float = scene.camera.size
	var original_saves := _save_bytes()
	candidate = Candidate.new()
	candidate.install(scene)
	_check(candidate.entries.size() == 2, "exactly gate and sluice overhead groups are selected")
	for entry in candidate.entries:
		_check(entry.root.has_node("TiledRoof"), "authored tiled roof remains in " + String(entry.root.name))
		for part in entry.parts:
			_check(part.mesh.position.y + part.mesh.get_aabb().position.y > 2.0, "all controlled meshes are above separate opaque piers")
			_check(part.returning.albedo_color == part.solid.albedo_color and part.returning.vertex_color_use_as_albedo == part.solid.vertex_color_use_as_albedo, "return material preserves plain or vertex-color source")
	for house in scene.building_visuals:
		_check(not candidate.owns(house.root), "house remains on legacy authored path")
	var gate: Dictionary = candidate.entries[0]
	var sluice: Dictionary = candidate.entries[1]
	for sample in [[gate, Vector2(6200, 4000), Vector2(6770, 4045)], [sluice, Vector2(6600, 750), Vector2(6650, 1500)]]:
		var entry: Dictionary = sample[0]
		scene.teleport(sample[1])
		candidate.update(scene, 1.0 / 120)
		_check(entry.cleared and entry.parts.all(func(p): return not p.mesh.visible), "actor ray removes overhead meshes immediately: " + String(entry.root.name))
		scene.teleport(sample[2])
		candidate.update(scene, 0.2)
		_check(entry.cleared, "short departure does not flicker restored roof")
		scene.teleport(sample[1])
		var count: int = entry.transitions
		candidate.update(scene, 0.1)
		_check(entry.transitions == count, "return inside hold does not trigger another transition")
		scene.teleport(sample[2])
		candidate.update(scene, 0.36)
		candidate.update(scene, 0.2)
		_check(not entry.cleared and entry.parts.all(func(p): return p.mesh.visible and p.mesh.material_override == p.solid), "complete original roof/material restores after clear interval")
		_check(scene.navigation.is_open(sample[1], 30) and scene.navigation.find_path(sample[1], sample[2]).size() > 0, "existing passage through separate piers stays open")
	# A real enemy and its ordinary attack warning remain visible under the gate.
	scene.teleport(Vector2(6630, 4045))
	scene.combat_enabled = true
	var enemy = scene._spawn_enemy_at(Vector2(6200, 4000), TrainingEnemy.Role.BEAST, 100)
	enemy.set_physics_process(false)
	enemy.warning_time = 0.55
	enemy.locked_direction = enemy.position.direction_to(scene.player.position)
	scene._process(0.0)
	candidate.update(scene, 0.02)
	_check(gate.cleared and scene.warning_vertex_count > 0, "enemy-only roof coverage clears while its attack warning remains drawn")
	scene.actors[enemy].hide()
	candidate.update(scene, 0.6)
	_check(not gate.cleared, "hidden enemy cannot keep gate roof removed")
	scene.set_combat_enabled(false)
	scene.teleport(Vector2(6200, 4000))
	candidate.update(scene, 0.02)
	scene.overview = true
	candidate.update(scene, 0.02)
	_check(not gate.cleared and gate.alpha == 1.0, "overview resets pending removals and restores the exact complete silhouette")
	scene.overview = false
	if not output.is_empty():
		for size in [Vector2i(1280, 720), Vector2i(960, 540)]:
			root.size = size
			root.content_scale_size = Vector2i(1280, 720)
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
			await process_frame
			for sample in [["gate-behind", Vector2(6200, 4000)], ["gate-clear", Vector2(6770, 4045)], ["sluice-behind", Vector2(6600, 750)], ["sluice-clear", Vector2(6650, 1500)], ["house-baseline-kept", Vector2(2480, 1690)]]:
				await _capture_pair(sample[0], sample[1])
	# Real ordinary player input through each local passage; only initial placement
	# switches between the distant gate and sluice sites.
	scene.set_process(true)
	scene.set_physics_process(true)
	scene.simulation.process_mode = Node.PROCESS_MODE_INHERIT
	var driver := Driver.new()
	driver.fixture = self
	driver.process_priority = 100
	root.add_child(driver)
	scene.teleport(Vector2(6200, 4000))
	for point in [Vector2(6400, 4045), Vector2(6630, 4045), Vector2(6200, 4000), Vector2(6770, 4045)]: await _walk(point)
	await create_timer(0.6).timeout
	_check(not candidate.entries[0].cleared, "moving gate exit restores overhead group")
	scene.teleport(Vector2(6600, 750))
	for point in [Vector2(6710, 760), Vector2(6650, 1120), Vector2(6650, 800), Vector2(6650, 1500)]: await _walk(point)
	await create_timer(0.6).timeout
	_check(not candidate.entries[1].cleared, "moving sluice exit restores overhead group")
	_check(scene.terrain.barriers() == barriers and scene.camera.size == camera_size, "all original barriers and camera preserved")
	_check(_save_bytes() == original_saves, "ordinary save slots remain unchanged")
	var entries: Array = candidate.entries.duplicate()
	candidate.restore()
	for entry in entries:
		_check(entry.parts.all(func(p): return p.mesh.visible and p.mesh.material_override == p.solid), "candidate disable restores original roof colors/visibility")
	if not output.is_empty():
		var report := {"checks": checks, "failures": failures, "routes": routes, "captures": captures, "time_scale": Engine.time_scale, "source": FileAccess.get_sha256("res://game/canal_overhead_occlusion.gd"), "scope": "Two overhead landmark groups. Houses retain baseline whole-building alpha; their tall box walls lack an authored low cut cap. Frozen before/after renders separate from ordinary-input local passages. No human preference or performance acceptance."}
		var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "  ") + "\n")
	driver.queue_free()
	scene.queue_free()
	await process_frame
	await process_frame
	await _verify_native_mount()
	print("Canal overhead occlusion: ", checks, " checks; ", failures, " failures; ", routes.size(), " local passage goals")
	quit(1 if failures else 0)

func _verify_native_mount() -> void:
	var native = load("res://game/canal_city_trial.tscn").instantiate()
	if native.get("overhead_occlusion") == null:
		native.free()
		return
	_check(native.overhead_occlusion_enabled, "production trial enables the tested overhead policy")
	root.add_child(native)
	current_scene = native
	for i in 3: await process_frame
	native.set_process(false)
	native.set_physics_process(false)
	native.simulation.process_mode = Node.PROCESS_MODE_DISABLED
	native.teleport(Vector2(6200, 4000))
	native._process(0.02)
	var gate: Dictionary = native.overhead_occlusion.entries[0]
	_check(gate.cleared and gate.parts.all(func(p): return not p.mesh.visible), "native scene immediately removes obstructing gate overhead")
	native.overhead_occlusion_enabled = false
	native._process(0.02)
	_check(gate.parts.all(func(p): return p.mesh.visible) and gate.parts.any(func(p): return p.mesh.material_override.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA), "baseline toggle restores meshes and invalidates the old fade cache")
	native.overhead_occlusion_enabled = true
	native._process(0.02)
	gate = native.overhead_occlusion.entries[0]
	_check(gate.cleared, "native candidate safely re-enters after legacy comparison")
	native.teleport(Vector2(6770, 4045))
	native._process(0.6)
	_check(not gate.cleared and gate.parts.all(func(p): return p.mesh.visible and p.mesh.material_override == p.solid), "native departure restores the original complete roof")
	native.queue_free()
	await process_frame

func _capture_pair(label: String, point: Vector2) -> void:
	for variant in ["baseline", "candidate"]:
		candidate.restore()
		scene.teleport(point)
		for item in scene.building_visuals + scene.landmark_visuals: item.root.remove_meta("fade_state")
		scene._process(0.0)
		if variant == "candidate": candidate.update(scene, 0.6)
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		_check(frame != null and not frame.is_empty(), "actual rendered frame exists")
		var filename := "%s-%dx%d-%s.png" % [variant, root.size.x, root.size.y, label]
		frame.save_png(output.path_join(filename))
		captures.append(filename)

func _walk(goal: Vector2) -> void:
	var started := Time.get_ticks_usec()
	while scene.player.position.distance_to(goal) > 8.0 and Time.get_ticks_usec() - started < 12000000:
		await physics_frame
		var path: PackedVector2Array = scene.navigation.find_path(scene.player.position, goal)
		var direction: Vector2 = scene.player.position.direction_to(path[1] if path.size() >= 2 else goal)
		var input: Vector2 = direction.rotated(-scene.player.input_rotation)
		_action("move_left", maxf(0, -input.x)); _action("move_right", maxf(0, input.x))
		_action("move_up", maxf(0, -input.y)); _action("move_down", maxf(0, input.y))
	for action in ["move_left", "move_right", "move_up", "move_down"]: _action(action, 0)
	var reached: bool = scene.player.position.distance_to(goal) <= 8.0
	routes.append({"goal": [goal.x, goal.y], "passed": reached})
	_check(reached, "actual input reaches local passage goal " + str(goal))
	await physics_frame

func _action(action: String, strength: float) -> void:
	if is_equal_approx(float(held.get(action, 0)), strength): return
	held[action] = strength
	var event := InputEventAction.new()
	event.action = action
	event.pressed = strength > 0
	event.strength = strength
	Input.parse_input_event(event)

func _save_bytes() -> Dictionary:
	var result := {}
	for prefix in ["user://loop_conquest_profile", "user://loop_conquest_1d_unlocks"]:
		for suffix in ["_a.json", "_b.json"]:
			var path: String = prefix + suffix
			result[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	return result
