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
	var water_curtains := 0
	for child in section.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh and is_equal_approx(child.mesh.size.y, 1.8):
			water_curtains += 1
			check(child.material_override.albedo_color == Color(0.4, 0.82, 0.85, 0.55), "authored water material retained")
	check(water_curtains == 6, "all authored waterfall sheets retained")
	for pose in POSES:
		check(scene.navigation.is_open(pose.point, scene.ACTOR_CLEARANCE), "actor never placed inside collision: " + pose.name)
		check(not scene.navigation.find_path(scene.start_point, pose.point).is_empty(), "local pose remains reachable: " + pose.name)
	var health: float = scene.player.health
	var run_id: String = scene.run_id
	var run_time: float = scene.run_time
	# Real trigger-driven transitions, twice, including the existing cooldown.
	for cycle in 2:
		scene.teleport(Layout.ENTRY_TRIGGER.get_center())
		section.portal_cooldown = 0.0
		section.tick(0.0)
		check(section.in_garden and scene.player.position == Layout.FIELD_ENTRY, "actual entrance transition")
		scene.teleport(Layout.EXIT_TRIGGER.get_center())
		section.tick(0.4)
		check(section.in_garden, "exit honors portal cooldown")
		section.tick(0.41)
		check(not section.in_garden and scene.player.position == Layout.RETURN_POINT, "actual exit restores authored return")
		check(scene.navigation.is_open(scene.player.position, scene.ACTOR_CLEARANCE), "returned actor collision-clear")
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

func _capture(variant: String, size: Vector2i, pose: Dictionary) -> void:
	scene.teleport(pose.point)
	scene._process(0.0)
	scene.camera.position = scene.terrain.world_point(pose.point, 35) + scene.camera_offset
	scene.camera.look_at(scene.terrain.world_point(pose.point, 35), Vector3.UP)
	var body: Sprite3D = scene.actors[scene.player].get_node("Body")
	check(not body.no_depth_test and body.alpha_cut == SpriteBase3D.ALPHA_CUT_DISCARD and body.modulate.a == 1.0, "ordinary opaque player depth, no bypass")
	var actor_error: float = scene.actors[scene.player].position.distance_to(scene.terrain.world_point(pose.point))
	var camera_error: float = scene.camera.position.distance_to(scene.terrain.world_point(pose.point, 35) + scene.camera_offset)
	check(actor_error < 0.001 and camera_error < 0.001, "fixed actor/camera synchronization")
	var meshes: Array[Node] = scene.find_children("*", "MeshInstance3D", true, false)
	var visibility: Array[bool] = []
	for mesh in meshes: visibility.append(mesh.visible)
	var counts: Array[int] = []
	var name := "%s-%d-%s" % [variant, size.x, pose.name]
	for scenery in [true, false]:
		for i in meshes.size(): meshes[i].visible = visibility[i] if scenery else false
		body.hide()
		var empty := await _image()
		body.show()
		var filled := await _image()
		check(not filled.is_empty() and filled.get_size() == size, "actual image dimensions")
		counts.append(_difference(filled, empty))
		var suffix := "scenery" if scenery else "bare"
		check(empty.save_png(output.path_join(name + "-" + suffix + "-empty.png")) == OK and filled.save_png(output.path_join(name + "-" + suffix + "-body.png")) == OK, "save differential image pair")
	for i in meshes.size(): meshes[i].visible = visibility[i]
	var ratio := float(counts[0]) / maxf(1.0, float(counts[1]))
	check(counts[1] >= 100, "enough unobstructed body pixels for a valid measurement")
	if variant == "candidate": check(ratio >= 0.98, "candidate full body visibility: " + name)
	elif pose.name == "returned": check(ratio < 0.60, "baseline reproduces known opaque rim masking")
	captures.append({"variant": variant, "pose": pose.name, "point": [pose.point.x, pose.point.y], "width": size.x, "height": size.y, "visible_body_pixels": counts[0], "unobstructed_body_pixels": counts[1], "ratio": ratio, "actor_error": actor_error, "camera_error": camera_error, "image_prefix": name, "actual_render": true})
	print("WATERFALL ", JSON.stringify(captures[-1]))

func _finish() -> void:
	if finished: return
	finished = true
	if not output.is_empty():
		var report := {"engine": Engine.get_version_info().string, "adapter": RenderingServer.get_video_adapter_name(), "captures": captures, "checks": checks, "errors": errors, "user_data_dir": OS.get_user_data_dir(), "scope": "fixed local entrance/return poses, frozen pressure and synthetic access; not natural play"}
		var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
		if file == null: check(false, "cannot save report")
		else:
			file.store_string(JSON.stringify(report, "  ") + "\n")
			file.close()
	print("Jungle waterfall visibility: %d checks, %d rendered cases, %d failures" % [checks, captures.size(), errors.size()])
	quit(1 if not errors.is_empty() else 0)

func _process(_delta: float) -> bool:
	if started > 0 and not finished and Time.get_ticks_usec() - started > 180000000:
		check(false, "180-second fixture watchdog expired")
		_finish()
	return false
