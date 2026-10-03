extends SceneTree
## Bounded entrance geometry/transition contracts; optional real-render regression.
## Synthetic fixed poses and frozen pressure, not a natural-play/visual-approval test.
## Render: isolated project userdata containing WaterfallVisibilityV48, then
## -- --capture-dir=<fresh absolute directory>. No runtime baseline switch is added.
const Layout = preload("res://game/jungle_grotto_layout.gd")
const OLD_RIMS := [Rect2(1240, 590, 150, 30), Rect2(1350, 430, 100, 390), Rect2(1240, 760, 150, 40), Rect2(1110, 440, 230, 110)]
const SIZES := [Vector2i(960, 540), Vector2i(1280, 720)]
const POSES := [
	{"name": "returned", "point": Vector2(1150, 700)},
	{"name": "before-entry", "point": Vector2(1245, 685)},
	# A legal location within the existing 0.8-second re-entry cooldown.
	{"name": "cooldown-edge", "point": Vector2(1310, 720)},
]
var checks := 0
var errors: Array[String] = []
var captures: Array[Dictionary] = []
var output := ""
var scene
var started := 0
var finished := false

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		errors.append(message)
		printerr("FAIL: ", message)

func _entrance_wall(wall: Dictionary) -> bool:
	return wall.get("discovery_id", "") == "JUNGLE_GROTTO" and wall.area.position.x < 1500.0

func _restore_old_rims(terrain) -> void:
	# Exact pre-fix geometry in this scene instance only; game source is untouched.
	terrain.wall_areas = terrain.wall_areas.filter(func(wall): return not _entrance_wall(wall))
	for area in OLD_RIMS:
		terrain.wall_areas.append({"area": area, "base": 0.0, "height": 185.0, "color": Color("41695b"), "discovery_id": "JUNGLE_GROTTO"})

func _contains(areas: Array, point: Vector2, clearance: float) -> bool:
	for area in areas:
		var d: Vector2 = (point - area.get_center()).abs()
		if d.x < area.size.x * 0.5 + clearance and d.y < area.size.y * 0.5 + clearance: return true
	return false

func _geometry_contract() -> void:
	var terrain = preload("res://game/jungle_south_circuit_terrain.gd").new()
	var areas: Array = []
	var visible_areas: Array = []
	var heights := {}
	for wall in terrain.wall_areas:
		if not _entrance_wall(wall): continue
		if wall.get("collidable", true): areas.append(wall.area)
		if wall.get("visual", true):
			visible_areas.append(wall.area)
			heights[wall.area] = wall.height
		check(wall.base == 0.0 and wall.color == Color("41695b"), "original opaque rim color/base")
	check(areas == OLD_RIMS, "exact original collider rectangles including unsplit eastern seam")
	check(visible_areas.size() == 5, "only one eastern visual footprint split")
	check(heights.get(Rect2(1240, 760, 150, 40), -1) == 21.0 and heights.get(Rect2(1350, 630, 100, 190), -1) == 21.0, "two permanent 21-unit near-side curbs")
	check(heights.get(Rect2(1350, 430, 100, 200), -1) == 185.0 and heights.get(OLD_RIMS[0], -1) == 185.0 and heights.get(OLD_RIMS[3], -1) == 185.0, "northern high silhouette retained")
	for x in range(1080, 1481, 5):
		for y in range(400, 851, 5):
			var visible_covered := false
			var old_covered := false
			for area in visible_areas:
				if area.has_point(Vector2(x, y)): visible_covered = true
			for area in OLD_RIMS:
				if area.has_point(Vector2(x, y)): old_covered = true
			check(visible_covered == old_covered, "rendered footprint exactly covers original blocked union")
			for clearance in [0.0, 30.0, 48.0]:
				check(_contains(areas, Vector2(x, y), clearance) == _contains(OLD_RIMS, Vector2(x, y), clearance), "unchanged entrance blocked union/clearance")
	check(Layout.RETURN_POINT == Vector2(1150, 700) and Layout.ENTRY_TRIGGER == Rect2(1250, 630, 100, 110), "authored return and trigger unchanged")

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			if not output.is_empty():
				printerr("FAIL: only one capture directory is allowed")
				quit(1)
				return
			output = argument.trim_prefix("--capture-dir=")
	if not output.is_empty():
		if not output.is_absolute_path() or not "WaterfallVisibilityV48" in OS.get_user_data_dir() or DisplayServer.get_name() == "headless" or RenderingServer.get_video_adapter_name().is_empty():
			printerr("FAIL: real renderer, fresh absolute output and isolated WaterfallVisibilityV48 userdata required")
			quit(1)
			return
		if DirAccess.dir_exists_absolute(output) and not DirAccess.get_files_at(output).is_empty():
			printerr("FAIL: existing evidence is never overwritten")
			quit(1)
			return
		if DirAccess.make_dir_recursive_absolute(output) != OK:
			printerr("FAIL: cannot create capture directory")
			quit(1)
			return
	started = Time.get_ticks_usec()
	Engine.time_scale = 1.0
	Engine.max_fps = 60
	_geometry_contract()
	for variant in ["baseline", "candidate"]:
		await _inspect(variant)
	if not output.is_empty():
		check(captures.size() == 12, "all baseline/candidate poses at both resolutions rendered")
	_finish()

func _inspect(variant: String) -> void:
	var stem := "user://waterfall_%s_%d" % [variant, Time.get_ticks_usec()]
	scene = load("res://game/jungle_south_circuit.tscn").instantiate()
	scene.profile_save_prefix = stem + "_profile"
	scene.growth_save_prefix = stem + "_growth"
	if variant == "baseline": _restore_old_rims(scene.terrain)
	root.add_child(scene)
	current_scene = scene
	scene.practice_mode = true
	scene.set_physics_process(false)
	scene.set_process(false)
	scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
	var section = scene.temple_section
	check(scene.camera.size == 9.0 and scene.camera_offset == Vector3(14, 13.864, 14), "unchanged authored combat camera")
	check(scene.terrain_mesh.material_override.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "terrain remains opaque")
	var expected_water := []
	var center: Vector2 = section.layout.ENTRY_TRIGGER.get_center()
	for offset in [Vector2(-75, 5), Vector2(40, -180), Vector2(40, 115), Vector2(-180, -195)]:
		expected_water.append({"point": center + offset, "depth": 1.25 if offset == Vector2(-75, 5) else 0.8})
	for point in [Vector2(7600, 1650), Vector2(8520, 1140)]:
		expected_water.append({"point": point, "depth": 0.8})
	var curtains := []
	for child in _descendants(section):
		if child is MeshInstance3D and child.mesh is BoxMesh and is_equal_approx(child.mesh.size.y, 1.8):
			curtains.append(child)
			var material = child.material_override
			check(material is StandardMaterial3D and material.albedo_color == Color(0.4, 0.82, 0.85, 0.55) and material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "authored water material retained")
	check(curtains.size() == 6, "all authored waterfall sheets retained, including nested helpers")
	check(curtains.filter(_authored_waterfall).size() == 6, "render selector recognizes exactly the six nested water sheets")
	for expected in expected_water:
		var matches := 0
		for curtain in curtains:
			if curtain.global_position.is_equal_approx(scene.terrain.world_point(expected.point, 100)):
				matches += 1
				check(curtain.mesh.size.is_equal_approx(Vector3(0.10, 1.8, expected.depth)), "authored water sheet dimensions retained")
		check(matches == 1, "exactly one water sheet at authored coordinate " + str(expected.point))
	for pose in POSES:
		check(scene.navigation.is_open(pose.point, scene.ACTOR_CLEARANCE), "actor never placed inside collision: " + pose.name)
		check(not scene.navigation.find_path(scene.start_point, pose.point).is_empty(), "local pose remains reachable: " + pose.name)
	var health: float = scene.player.health
	var run_id: String = scene.run_id
	var run_time: float = scene.run_time
	# Real trigger-driven transitions, twice, including the existing cooldown.
	for cycle in 2:
		_press_world(Layout.RETURN_POINT.direction_to(Layout.ENTRY_TRIGGER.get_center()))
		scene.teleport(Layout.ENTRY_TRIGGER.get_center())
		section.portal_cooldown = 0.0
		section.tick(0.0)
		check(section.in_garden and scene.player.position == Layout.FIELD_ENTRY, "actual entrance transition")
		scene.teleport(Layout.EXIT_TRIGGER.get_center())
		section.tick(0.4)
		check(section.in_garden, "exit honors portal cooldown")
		_release_input()
		section.tick(0.41)
		check(section.in_garden, "neutral teleport cannot bypass arrival latch after cooldown")
		_press_world(Layout.FIELD_ENTRY.direction_to(Layout.EXIT_TRIGGER.get_center()))
		section.tick(0.0)
		check(not section.in_garden and scene.player.position == Layout.RETURN_POINT, "actual exit restores authored return")
		check(scene.navigation.is_open(scene.player.position, scene.ACTOR_CLEARANCE), "returned actor collision-clear")
	_release_input()
	check(scene.player.health == health and scene.run_id == run_id and scene.run_time == run_time, "transitions preserve health/run identity/time")
	await create_timer(0.5).timeout # Finish the real transition shade before pixels.
	if not output.is_empty():
		for size in SIZES:
			root.size = size
			root.content_scale_size = Vector2i(1280, 720)
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
			for pose in POSES: await _capture(variant, size, pose)
	scene.queue_free()
	current_scene = null
	for i in 3: await process_frame
	scene = null

func _image() -> Image:
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func _difference(a: Image, b: Image) -> int:
	var count := 0
	for y in range(a.get_height() / 4, a.get_height() * 3 / 4):
		for x in range(a.get_width() / 3, a.get_width() * 2 / 3):
			var delta := a.get_pixel(x, y) - b.get_pixel(x, y)
			if absf(delta.r) + absf(delta.g) + absf(delta.b) > 0.04: count += 1
	return count

func _authored_waterfall(mesh: Node) -> bool:
	if not mesh is MeshInstance3D or not mesh.mesh is BoxMesh or not scene.temple_section.is_ancestor_of(mesh): return false
	var material = mesh.material_override
	return is_equal_approx(mesh.mesh.size.x, 0.10) and is_equal_approx(mesh.mesh.size.y, 1.8) and material is StandardMaterial3D and material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and material.albedo_color == Color(0.4, 0.82, 0.85, 0.55)

func _capture(variant: String, size: Vector2i, pose: Dictionary) -> void:
	scene.teleport(pose.point)
	# Fixed visibility poses include facing: the new portal deliberately turns
	# the player away on return, unlike v48. Pin the original right-facing
	# sprite for comparable geometry/water pixels. Actual return-facing and
	# ordinary-input traversal stay covered by verify_hidden_flow.
	scene.player.facing = Vector2.RIGHT
	scene._process(0.0)
	scene.camera.position = scene.terrain.world_point(pose.point, 35) + scene.camera_offset
	scene.camera.look_at(scene.terrain.world_point(pose.point, 35), Vector3.UP)
	var body: Sprite3D = scene.actors[scene.player].get_node("Body")
	check(not body.no_depth_test and body.alpha_cut == SpriteBase3D.ALPHA_CUT_DISCARD and body.modulate.a == 1.0, "ordinary opaque player depth, no bypass")
	check(scene.player.facing == Vector2.RIGHT and not body.flip_h, "fixed original right-facing visibility pose")
	var actor_error: float = scene.actors[scene.player].position.distance_to(scene.terrain.world_point(pose.point))
	var camera_error: float = scene.camera.position.distance_to(scene.terrain.world_point(pose.point, 35) + scene.camera_offset)
	check(actor_error < 0.001 and camera_error < 0.001, "fixed actor/camera synchronization")
	var meshes: Array[Node] = scene.find_children("*", "MeshInstance3D", true, false)
	var visibility: Array[bool] = []
	var waterfall: Array[bool] = []
	for mesh in meshes:
		visibility.append(mesh.visible)
		waterfall.append(_authored_waterfall(mesh))
	check(waterfall.count(true) == 6, "comparison isolates exactly the six original water sheets")
	var counts := {}
	var name := "%s-%d-%s" % [variant, size.x, pose.name]
	# Keep the original full-scene/bare comparison as diagnostics. Water-reference
	# preserves authored attenuation on both sides. The opaque-only/bare pair
	# isolates real stone/ramp occlusion without alpha/contrast threshold bias.
	# These are test-only captures; every original visibility is restored below.
	for mode in ["scenery", "bare", "water-reference", "opaque-only"]:
		for i in meshes.size():
			match mode:
				"scenery": meshes[i].visible = visibility[i]
				"bare": meshes[i].visible = false
				"water-reference": meshes[i].visible = visibility[i] and waterfall[i]
				"opaque-only": meshes[i].visible = visibility[i] and not waterfall[i]
		body.hide()
		var empty := await _image()
		body.show()
		var filled := await _image()
		check(not filled.is_empty() and filled.get_size() == size, "actual image dimensions")
		counts[mode] = _difference(filled, empty)
		check(empty.save_png(output.path_join(name + "-" + mode + "-empty.png")) == OK and filled.save_png(output.path_join(name + "-" + mode + "-body.png")) == OK, "save differential image pair")
	for i in meshes.size(): meshes[i].visible = visibility[i]
	var ratio := float(counts.scenery) / maxf(1.0, float(counts.bare))
	var water_ratio := float(counts.scenery) / maxf(1.0, float(counts["water-reference"]))
	var opaque_ratio := float(counts["opaque-only"]) / maxf(1.0, float(counts.bare))
	check(counts.bare >= 100 and counts["water-reference"] >= 100, "enough bare/water-reference body pixels for a valid measurement")
	var classification := "rim_fix_acceptance" if pose.name != "cooldown-edge" else "known_preexisting_ramp_occlusion"
	var adoption_pass := true
	var baseline := {}
	if variant == "candidate":
		if pose.name == "cooldown-edge":
			for entry in captures:
				if entry.variant == "baseline" and entry.width == size.x and entry.pose == pose.name: baseline = entry
			check(not baseline.is_empty(), "same-pose/resolution baseline exists for known ramp comparison")
			adoption_pass = not baseline.is_empty() and water_ratio >= float(baseline.get("water_comparable_ratio", INF)) and ratio >= float(baseline.get("ratio", INF)) and opaque_ratio >= float(baseline.get("opaque_geometry_ratio", INF))
			check(adoption_pass, "known cooldown ramp must not regress in raw/water/opaque comparisons: " + name)
			print("KNOWN LIMITATION: ", name, " western ascent ramp still obscures the lower body; raw_ratio=", ratio, " water_comparable_ratio=", water_ratio, " opaque_geometry_ratio=", opaque_ratio, " strict_threshold=0.98; non-regression is not a full visibility pass")
		else:
			adoption_pass = water_ratio >= 0.98
			check(adoption_pass, "candidate return/entry water-comparable visibility: " + name)
	elif pose.name == "returned": check(ratio < 0.60, "baseline reproduces known opaque rim masking")
	captures.append({"variant": variant, "pose": pose.name, "facing": [scene.player.facing.x,scene.player.facing.y], "body_flip_h":body.flip_h, "point": [pose.point.x, pose.point.y], "width": size.x, "height": size.y, "visible_body_pixels": counts.scenery, "unobstructed_body_pixels": counts.bare, "ratio": ratio, "water_reference_body_pixels": counts["water-reference"], "water_comparable_ratio": water_ratio, "opaque_geometry_body_pixels": counts["opaque-only"], "opaque_geometry_ratio": opaque_ratio, "strict_full_scene_visibility_pass": ratio >= 0.98, "strict_opaque_visibility_pass": opaque_ratio >= 0.98, "strict_threshold": 0.98, "classification": classification, "adoption_gate": "not_applicable_baseline" if variant == "baseline" else "non_regression_only" if pose.name == "cooldown-edge" else "water_comparable_at_least_0.98", "adoption_pass": adoption_pass if variant == "candidate" else null, "baseline_ratios": {} if baseline.is_empty() else {"raw": baseline.ratio, "water_comparable": baseline.water_comparable_ratio, "opaque_geometry": baseline.opaque_geometry_ratio}, "actor_error": actor_error, "camera_error": camera_error, "image_prefix": name, "actual_render": true})
	print("WATERFALL ", JSON.stringify(captures[-1]))

func _finish() -> void:
	if finished: return
	finished = true
	var strict_failures := captures.filter(func(entry): return entry.variant == "candidate" and not entry.strict_opaque_visibility_pass)
	var limitations := captures.filter(func(entry): return entry.variant == "candidate" and entry.classification == "known_preexisting_ramp_occlusion")
	if not output.is_empty():
		var report := {"engine": Engine.get_version_info().string, "adapter": RenderingServer.get_video_adapter_name(), "captures": captures, "checks": checks, "errors": errors, "strict_opaque_visibility_failures": strict_failures, "known_limitations": limitations, "adoption_scope": "return and before-entry water-comparable ratio >=0.98; existing cooldown ramp non-regression only, not a full visibility fix", "user_data_dir": OS.get_user_data_dir(), "scope": "fixed local entrance/return poses, frozen pressure and synthetic access; not natural play"}
		var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
		if file == null: check(false, "cannot save report")
		else:
			file.store_string(JSON.stringify(report, "  ") + "\n")
			file.close()
	print("Jungle waterfall visibility: %d checks, %d rendered cases, %d adoption/contract failures, %d strict opaque visibility failures, %d documented known-limitation cases" % [checks, captures.size(), errors.size(), strict_failures.size(), limitations.size()])
	quit(1 if not errors.is_empty() else 0)

func _process(_delta: float) -> bool:
	if started > 0 and not finished and Time.get_ticks_usec() - started > 180000000:
		check(false, "180-second fixture watchdog expired")
		_finish()
	return false

func _descendants(node: Node) -> Array:
	var result := []
	for child in node.get_children():
		result.append(child)
		result.append_array(_descendants(child))
	return result

func _release_input() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(action)

func _press_world(direction: Vector2) -> void:
	_release_input()
	var movement := direction.rotated(-scene.player.input_rotation)
	if movement.x < -0.1: Input.action_press("move_left", -movement.x)
	if movement.x > 0.1: Input.action_press("move_right", movement.x)
	if movement.y < -0.1: Input.action_press("move_up", -movement.y)
	if movement.y > 0.1: Input.action_press("move_down", movement.y)
