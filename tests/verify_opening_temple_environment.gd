extends SceneTree
## Focused opening-place contract: real terrain, input routes and warning clipping.
## Fixed input fixture, not human play, difficulty or art acceptance.

const Opening = preload("res://game/temple_opening_environment.gd")
var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _frames(count: int) -> void:
	for i in count: await physics_frame

func _release() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(action)

func _travel(scene, target: Vector2) -> bool:
	for i in 600:
		if scene.player.position.distance_to(target) <= 14:
			_release()
			await _frames(2)
			return scene.player.position.distance_to(target) <= 22
		var screen: Vector2 = scene.player.position.direction_to(target).rotated(PI / 4.0)
		_release()
		Input.action_press("move_right" if screen.x > 0 else "move_left", absf(screen.x))
		Input.action_press("move_down" if screen.y > 0 else "move_up", absf(screen.y))
		await physics_frame
	_release()
	return false

func _mounted_root(scene) -> Node3D:
	var found: Node3D = scene.get_node_or_null("TempleOpeningEnvironment")
	if found != null: return found
	var sample := Opening.build(scene)
	scene.add_child(sample)
	return sample

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene = load("res://game/hybrid_region.tscn").instantiate()
	scene.profile_save_prefix = "user://verify_opening_temple_profile"
	scene.growth_save_prefix = "user://verify_opening_temple_unlocks"
	root.add_child(scene)
	current_scene = scene
	await _frames(3)
	var before := [scene.terrain.plateaus.duplicate(true), scene.terrain.ramps.duplicate(true), scene.terrain.water_areas.duplicate(), scene.terrain.wall_areas.duplicate(true), scene.terrain.barriers().duplicate()]
	var terrain_vertices: PackedVector3Array = scene.terrain_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].duplicate()
	var native_mount: bool = scene.get_node_or_null("TempleOpeningEnvironment") != null
	var opening := _mounted_root(scene)
	_check(before == [scene.terrain.plateaus, scene.terrain.ramps, scene.terrain.water_areas, scene.terrain.wall_areas, scene.terrain.barriers()], "mounting visual groups leaves every gameplay terrain record unchanged")
	_check(terrain_vertices == scene.terrain_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], "original authoritative terrain mesh is untouched")
	_check(scene.start_point == Vector2(650, 1870) and scene.camera.size == 9.0 and scene.camera_offset == Vector3(14, 13.864, 14), "actual opening position and camera contract are preserved")
	_check(opening.get_child_count() == 5 and opening.find_children("*", "CollisionObject3D", true, false).is_empty(), "five batched visual meshes add no physics objects")
	for child in opening.get_children():
		var valid := true
		var follows_surface := true
		var footprints: Array = child.get_meta("blocked_footprints", [])
		for vertex in child.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			valid = valid and vertex.is_finite()
			var point: Vector2 = Vector2(vertex.x, vertex.z) / scene.terrain.SCALE
			if not footprints.is_empty():
				var inside := false
				for footprint in footprints:
					if footprint.grow(0.02).has_point(point): inside = true
				valid = valid and inside
			else:
				var lift: float = vertex.y / scene.terrain.SCALE - scene.terrain.height_at(point)
				follows_surface = follows_surface and lift >= 0.10 and lift <= Opening.FLOOR_MAX_LIFT + 0.01
		_check(valid, "finite solid/growth geometry remains inside assigned existing blocker: " + child.name)
		if footprints.is_empty(): _check(follows_surface, "every paving vertex follows actual height with less than one unit of lift")
		for area in footprints:
			var contained := false
			for barrier in before[4]:
				if barrier.grow(0.03).encloses(area): contained = true
			_check(contained, "structural/plant footprint is contained by an original barrier: %s" % area)
	for point in [Vector2(650, 1840), Vector2(650, 1400), Vector2(935, 1870), Vector2(935, 1450), Vector2(250, 1320), Vector2(1135, 1410), Vector2(1125, 1135), Vector2(1520, 1140), Vector2(640, 210)]:
		_check(scene.navigation.find_path(scene.start_point, point).size() > 1, "south entry, stones, courtyard circulation and exits retain navigation: %s" % point)
	_check(not scene.clear_attack(Vector2(170, 1620), Vector2(530, 1620)), "water still clips attacks")
	_check(not scene.clear_attack(Vector2(810, 1500), Vector2(810, 1610)), "closed raised court edge still clips attacks")
	_check(scene.clear_attack(Vector2(650, 1450), Vector2(650, 1860)), "south slope permits connected attacks")
	_check(scene.clear_attack(Vector2(935, 1450), Vector2(935, 1860)), "stepping-stone route permits connected attacks")
	scene.spawn_credit = -100000
	scene.player.hurt_immunity = 100000
	scene.wisp.set_physics_process(false)
	for actor in scene.actors.keys():
		if actor != scene.player: scene.temple_section._remove_actor(actor)
	await _frames(2)
	scene.teleport(scene.start_point)
	for point in [Vector2(650, 1430), Vector2(935, 1430), Vector2(935, 1870), Vector2(650, 1870), Vector2(650, 1410), Vector2(1135, 1410), Vector2(1135, 1150), Vector2(1520, 1150), Vector2(1135, 1150), Vector2(1135, 1410), Vector2(650, 1410), Vector2(650, 1870)]:
		_check(await _travel(scene, point), "real player input reaches and returns through south ramp, alternate stones and side exit: %s (ended %s)" % [point, scene.player.position])
	_check(scene.terrain.height_at(scene.player.position) == 0, "round trip returns to the lower water approach")
	for size in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = size
		scene.teleport(Vector2(650, 1410))
		var enemy = scene._spawn_enemy_at(Vector2(775, 1325), TrainingEnemy.Role.BEAST, 100)
		enemy.set_physics_process(false)
		enemy.warning_time = 0.4
		enemy.locked_direction = enemy.position.direction_to(scene.player.position)
		await _frames(2)
		scene._draw_enemy_warnings(1.0)
		_check(scene.warning_vertex_count > 0, "existing first-court attack warning remains present at %s" % size)
		_check(scene.actors[scene.player].position.distance_to(scene.terrain.world_point(scene.player.position)) < 0.01, "actual actor feet remain on authoritative surface at %s" % size)
		var foot: Vector3 = scene.terrain.world_point(scene.player.position, 10)
		var blocked := false
		for group in opening.get_meta("occlusion_groups"):
			for volume in group.get_meta("occlusion_volumes"):
				if (volume as AABB).intersects_segment(foot, foot + scene.camera.global_basis.z * 40) != null: blocked = true
		_check(not blocked, "bank remnant cannot cover first-court combat feet at %s" % size)
		scene.temple_section._remove_actor(enemy)
		await _frames(2)
	# Bank remnants stay below the raised combat floor; sight handling stays safe.
	scene.teleport(Vector2(389, 1525))
	Opening.update_visibility(opening, scene)
	_check(opening.get_node("WestBankRemnant").material_override.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "bank remnant stays below the raised player rather than occluding their feet")
	scene.teleport(scene.start_point)
	Opening.update_visibility(opening, scene)
	_check(opening.get_node("WestBankRemnant").material_override.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "water-bank remnant restores on the open approach")
	var expired := TrainingEnemy.new()
	scene.actors[expired] = null
	expired.free()
	Opening.update_visibility(opening, scene)
	scene.actors.erase(expired)
	if native_mount:
		scene.temple_section.enter_garden()
		await process_frame
		await process_frame
		_check(not opening.visible, "native mount hides opening during the separate garden visit")
		scene.temple_section.leave_garden()
		await process_frame
		await process_frame
		_check(opening.visible, "native mount restores opening after garden return")
	print("Opening mount mode: ", "native integration" if native_mount else "independent fixture")
	print("Opening environment resource counts: ", opening.get_meta("resource_counts"))
	scene.queue_free()
	await process_frame
	if native_mount:
		for fixture in [
			{"path": "res://game/hybrid_region.tscn", "kit": true, "opening": false, "label": "opening-only baseline"},
			{"path": "res://game/hybrid_region.tscn", "kit": false, "opening": true, "label": "complete temple baseline"},
			{"path": "res://game/jungle_pass.tscn", "kit": true, "opening": true, "label": "inherited jungle scene"},
		]:
			var comparison = load(fixture.path).instantiate()
			comparison.profile_save_prefix = "user://verify_opening_temple_comparison_profile"
			comparison.growth_save_prefix = "user://verify_opening_temple_comparison_unlocks"
			comparison.temple_environment_enabled = fixture.kit
			comparison.temple_opening_enabled = fixture.opening
			root.add_child(comparison)
			await _frames(2)
			_check(comparison.get_node_or_null("TempleOpeningEnvironment") == null, "opening is excluded from " + fixture.label)
			comparison.queue_free()
			await process_frame
	print("Opening environment verification: ", checks, " checks, ", failures, " failures; human art/place/fun unverified")
	quit(1 if failures else 0)
