extends "res://tests/sample_run_baseline.gd"
## Same live-input passage for baseline/candidate. Frozen boss warning comparisons
## are a separate stage. Neither is human acceptance or a normal progression run.
const Candidate = preload("res://game/temple_occlusion_candidate.gd")
var candidate
var output := ""
var variant := "baseline"
var native_driver := false
var stage := "setup"
var route_checks: Array = []
var transitions: Array = []
var prior_states: Dictionary = {}
var traces: Array = []
var captures: Array = []
var elapsed := 0.0
var error := ""
var guard: Dictionary = {}
var source_hashes: Dictionary = {}

class ComparisonDriver extends Node:
	var fixture
	func _process(delta: float) -> void:
		if fixture.candidate != null and not fixture.native_driver: fixture.candidate.update(fixture.scene, delta)
		fixture._observe(delta)

func _run() -> void:
	output = OS.get_environment("OCCLUSION_OUTPUT")
	var isolation := OS.get_environment("OCCLUSION_ISOLATION")
	if output.is_empty() or isolation.is_empty() or not OS.get_user_data_dir().begins_with(isolation + "/"):
		printerr("FAIL: explicit private output and user-data roots are required")
		quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg == "--candidate": variant = "candidate"
		if arg == "--native-candidate":
			variant = "candidate"
			native_driver = true
	root.size = Vector2i(960, 540) if OS.get_cmdline_user_args().has("--small") else Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	DirAccess.make_dir_recursive_absolute(output)
	for prefix in ["user://loop_conquest_profile", "user://loop_conquest_1d_unlocks"]:
		for suffix in ["_a.json", "_b.json"]:
			var path: String = prefix + suffix
			if FileAccess.file_exists(path):
				printerr("FAIL: fresh private save root required")
				quit(1)
				return
			if suffix == "_a.json":
				var file := FileAccess.open(path, FileAccess.WRITE)
				file.store_string("private occlusion-fixture ordinary-slot guard\n")
				file.close()
			guard[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
	for path in ["res://game/temple_occlusion_candidate.gd", "res://game/hybrid_region.gd", "res://game/hybrid_height.gd", "res://game/temple_environment_kit.gd", "res://game/temple_sanctuary_environment.gd", "res://game/temple_hybrid_terrain.gd", "res://game/gate_boss.gd", "res://game/player.gd", "res://tests/capture_temple_occlusion_candidate.gd"]:
		source_hashes[path] = FileAccess.get_sha256(path)
	Engine.time_scale = 1.0
	Engine.max_fps = 60
	scene = load("res://game/hybrid_region.tscn").instantiate()
	# This comparison owns its explicit baseline/candidate driver.
	if scene.get("temple_occlusion_candidate") != null:
		scene.temple_occlusion_candidate_enabled = native_driver
	scene.profile_save_prefix = "user://occlusion_capture_profile"
	scene.growth_save_prefix = "user://occlusion_capture_unlocks"
	root.add_child(scene)
	current_scene = scene
	for i in 5: await process_frame
	scene.rng.seed = 4001
	scene.growth.growth_ended = true
	scene.spawn_credit = -100000.0
	for actor in scene.actors.keys():
		if actor != scene.player: scene.temple_section._remove_actor(actor)
	if variant == "candidate":
		candidate = scene.temple_occlusion_candidate if native_driver else Candidate.new()
		if not native_driver: candidate.install(scene)
	var driver := ComparisonDriver.new()
	driver.fixture = self
	driver.process_priority = 100
	root.add_child(driver)
	scene.teleport(Vector2(3900, 1120))
	await create_timer(0.8).timeout
	await _capture("01-complete-approach")
	stage = "moving"
	for sample in [
		[Vector2(3940, 765), "02-threshold-behind"],
		[Vector2(3890, 740), "north-passage"],
		[Vector2(3940, 850), "near-clear"],
		[Vector2(3940, 815), "near-return"],
		[Vector2(3940, 850), "near-clear-again"],
		[Vector2(3940, 815), "03-return-within-hold"],
		[Vector2(3900, 895), "broad-boundary-in"],
		[Vector2(3900, 920), "broad-boundary-out"],
		[Vector2(3900, 895), "broad-boundary-in-2"],
		[Vector2(3900, 920), "broad-boundary-out-2"],
		[Vector2(3900, 895), "broad-boundary-in-3"],
		[Vector2(3900, 920), "broad-boundary-out-3"],
		[Vector2(4320, 1150), "04-arrival"],
		[Vector2(4770, 960), "05-remnant-behind"],
		[Vector2(4730, 910), "remnant-side"],
		[Vector2(4770, 960), "remnant-return"],
		[Vector2(4700, 1170), "remnant-clear"],
		[Vector2(4750, 1370), "06-full-sanctuary"],
		[Vector2(4320, 1150), "07-departure-restored"],
	]:
		await _walk(sample[0], sample[1])
		if not error.is_empty(): break
		if sample[1].begins_with("0"): await _capture(sample[1])
	_release()
	await create_timer(0.65).timeout
	stage = "frozen-warning"
	if error.is_empty():
		scene._spawn_now(scene.temple_section.BOSS_POINT, TrainingEnemy.Role.BEAST, true)
		scene.boss.set_physics_process(false)
		scene.boss.encounter_active = true
		scene.set_physics_process(false)
		for sample in [
			[Vector2(4350, 1180), "08-warning-player-front"],
			[Vector2(4770, 960), "09-warning-player-behind"],
		]:
			scene.teleport(sample[0])
			scene.boss.ring_warning = 0.55
			await create_timer(0.85).timeout
			await _capture(sample[1])
			scene.boss.ring_warning = 0
		scene.teleport(Vector2(4320, 1150))
		await create_timer(0.85).timeout
		await _capture("10-final-restored")
	await _finish()

func _walk(goal: Vector2, label: String) -> void:
	var started := Time.get_ticks_usec()
	while scene.player.position.distance_to(goal) > 5.0:
		await physics_frame
		if Time.get_ticks_usec() - started > 12000000:
			error = "route could not reach " + label
			break
		var path: PackedVector2Array = scene.navigation.find_path(scene.player.position, goal)
		var direction := Vector2.ZERO
		if path.size() >= 2:
			var index := 1
			while index < path.size() - 1 and scene.player.position.distance_to(path[index]) < 15: index += 1
			direction = scene.player.position.direction_to(path[index])
		elif scene.clear_attack(scene.player.position, goal):
			# Navigation collapses an already-reached grid cell to one point.
			# Finish the small open-cell movement through ordinary player input.
			direction = scene.player.position.direction_to(goal)
		var input: Vector2 = direction.rotated(-scene.player.input_rotation)
		_action("move_left", maxf(0, -input.x))
		_action("move_right", maxf(0, input.x))
		_action("move_up", maxf(0, -input.y))
		_action("move_down", maxf(0, input.y))
		traces.append([Engine.get_physics_frames(), scene.player.position.x, scene.player.position.y])
	var distance: float = scene.player.position.distance_to(goal)
	_release()
	await physics_frame
	route_checks.append({"label": label, "goal": [goal.x, goal.y], "distance": distance, "passed": distance <= 5.0})

func _states() -> Dictionary:
	var result := {}
	if candidate != null:
		for member in candidate.members: result[String(member.mesh.name)] = member.cut
	else:
		for group_root in [scene.temple_environment_root, scene.temple_sanctuary_root]:
			for mesh in group_root.get_children():
				if Candidate.BASE_HEIGHTS.has(String(mesh.name)):
					result[String(mesh.name)] = mesh.material_override.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA
	return result

func _observe(delta: float) -> void:
	elapsed += delta
	var states := _states()
	for label in states:
		if stage == "moving" and prior_states.has(label) and prior_states[label] != states[label]:
			transitions.append({"member": label, "cleared": states[label], "elapsed": elapsed, "position": [scene.player.position.x, scene.player.position.y]})
	prior_states = states

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	if frame == null or frame.is_empty():
		error = "actual graphical frame unavailable"
		return
	var filename := "%s-%dx%d-%s.png" % [variant, root.size.x, root.size.y, label]
	frame.save_png(output.path_join(filename))
	captures.append({"file": filename, "stage": stage, "position": [scene.player.position.x, scene.player.position.y], "states": _states(), "warning_vertices": scene.warning_vertex_count})

func _finish() -> void:
	_release()
	var preserved := true
	for path in guard:
		preserved = preserved and guard[path] == (FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent")
	for path in source_hashes: preserved = preserved and source_hashes[path] == FileAccess.get_sha256(path)
	var complete := error.is_empty() and preserved and route_checks.size() == 19
	for check in route_checks: complete = complete and check.passed
	var report := {"variant": variant, "size": [root.size.x, root.size.y], "engine": Engine.get_version_info().string,
		"fixture": "Normal-speed actual directional input through 19 temple passage/reversal points; no dash, attacks or ambient enemies. Frozen existing ring warning fixtures afterward. No human playtest, full progression, audio or performance acceptance. " + ("Native production scene owns candidate updates; fixture only observes." if native_driver else "Standalone candidate driver overrides the legacy comparison path."),
		"native_scene_driver": native_driver,
		"time_scale": Engine.time_scale, "elapsed": elapsed, "route_checks": route_checks,
		"transition_count": transitions.size(), "transitions": transitions, "movement_trace": traces,
		"captures": captures, "private_normal_slots_and_source_preserved": preserved,
		"source_sha256": source_hashes, "complete": complete, "error": error}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("OCCLUSION ", variant, " ", root.size, " complete=", complete, " transitions=", transitions.size(), " captures=", captures.size(), " error=", error)
	# Release comparison material/triangle resources before the engine exits.
	if candidate != null: candidate.restore()
	for child in root.get_children():
		child.set_process(false)
		child.queue_free()
	candidate = null
	scene = null
	await process_frame
	await process_frame
	quit(0 if complete else 1)
