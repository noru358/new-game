extends SceneTree
## Presentation must retain the current playable temple and hidden-field contract.

var failures := 0

func _initialize() -> void: call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _frames(count: int) -> void:
	for i in count: await physics_frame

func _fresh(enabled: bool, suffix: String, path: String = "res://game/hybrid_region.tscn", sanctuary_enabled: bool = true):
	var scene = load(path).instantiate()
	# Keep the retained alpha comparison covered independently of the new default.
	scene.temple_occlusion_candidate_enabled = false
	scene.temple_environment_enabled = enabled
	scene.temple_sanctuary_enabled = sanctuary_enabled
	scene.profile_save_prefix = "user://verify_temple_environment_profile_" + suffix
	scene.growth_save_prefix = "user://verify_temple_environment_unlocks_" + suffix
	root.add_child(scene)
	current_scene = scene
	return scene

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var baseline = _fresh(false, "baseline")
	await _frames(3)
	var original_barriers: Array[Rect2] = baseline.terrain.barriers().duplicate()
	var original_camera: float = baseline.camera.size
	var original_speed: float = baseline.player.move_speed_multiplier
	var original_dash: float = baseline.player.dash_distance_multiplier
	_check(baseline.temple_environment_root == null, "startup baseline switch retains the original visual path")
	_check(baseline.temple_sanctuary_root == null, "original baseline also excludes the later sanctuary ensemble")
	baseline.queue_free()
	await process_frame
	await process_frame
	var v33 = _fresh(true, "v33", "res://game/hybrid_region.tscn", false)
	await _frames(3)
	_check(is_instance_valid(v33.temple_environment_root) and v33.temple_sanctuary_root == null, "sanctuary-only baseline preserves the v33 gallery instead of overstating the comparison")
	_check(v33.terrain.barriers() == original_barriers, "v33 comparison shares the original gameplay barriers")
	v33.queue_free()
	await process_frame
	await process_frame
	var scene = _fresh(true, "kit")
	await _frames(3)
	_check(is_instance_valid(scene.temple_environment_root), "real temple scene mounts the representative kit")
	_check(scene.terrain.barriers() == original_barriers, "every original wall, water and terrain barrier is preserved")
	_check(scene.camera.size == original_camera and scene.player.move_speed_multiplier == original_speed and scene.player.dash_distance_multiplier == original_dash, "presentation preserves camera and locomotion")
	_check(scene.temple_environment_root.get_meta("replaced_wall_areas").size() == 4, "four existing wall visuals are replaced, not stacked over the original boxes")
	_verify_sanctuary_geometry(scene)
	for size in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = size
		await process_frame
		await process_frame
		for point in [Vector2(3900, 1120), Vector2(4320, 1150), Vector2(4750, 1370)]:
			scene.teleport(point)
			var coverage := _visible_structure_bounds(scene, scene.temple_sanctuary_root.get_node("SteppedSanctuary"))
			_check(coverage.size.x > size.x * 0.07 and coverage.size.y > size.y * 0.13, "actual camera sees a building-scale sanctuary portion at %s %s: %s" % [size, point, coverage])
			print("Sanctuary projected coverage ", size, " at ", point, ": ", coverage)
			var visible_door_corners := 0
			for corner in scene.temple_sanctuary_root.get_meta("doorway_points"):
				var screen := _output_point(scene, corner)
				if Rect2(Vector2.ZERO, Vector2(size)).has_point(screen): visible_door_corners += 1
			if point == Vector2(3900, 1120):
				_check(visible_door_corners >= 2, "last bend reveals the chamber doorway itself, not only a crown tip")
			elif point == Vector2(4320, 1150):
				_check(visible_door_corners == 4, "arrival camera includes the complete doorway aperture")
				var plinth := _output_point(scene, scene.temple_sanctuary_root.get_meta("arrival_plinth_point"))
				_check(Rect2(Vector2.ZERO, Vector2(size) * Vector2(1, 0.94)).has_point(plinth), "arrival also reveals the stepped plinth beneath the doorway")
				var recess: Vector3 = scene.temple_sanctuary_root.get_meta("doorway_recess_point")
				var blocked := false
				for volume in scene.temple_sanctuary_root.get_node("SteppedSanctuary").get_meta("occlusion_volumes"):
					if (volume as AABB).intersects_segment(recess, recess + scene.camera.global_basis.z * 40) != null: blocked = true
				_check(not blocked, "actual diagonal camera can see the recessed doorway back through its side piers")
	root.size = Vector2i(1280, 720)
	await process_frame
	await process_frame
	var remnant: MeshInstance3D = scene.temple_sanctuary_root.get_node("CourtMasonryRemnant")
	scene.teleport(Vector2(4770, 960))
	await process_frame
	await process_frame
	_check(remnant.material_override.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "court remnant fades when its real volume covers the player's feet")
	scene.teleport(Vector2(4320, 1150))
	await process_frame
	await process_frame
	_check(remnant.material_override.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "court remnant restores when the player leaves its projected volume")
	for point in [Vector2(3400, 710), Vector2(3400, 1380), Vector2(3900, 1120), scene.temple_section.RETRY_POINT, scene.temple_section.BOSS_POINT, scene.temple_section.Garden.ENTRY_TRIGGER.get_center()]:
		_check(scene.navigation.find_path(scene.start_point, point).size() > 1, "existing lane, destination or concealed-branch route stays connected: %s" % point)
	_check(scene.clear_attack(Vector2(3100, 710), Vector2(3700, 710)), "gallery lane still permits direct attacks")
	_check(not scene.clear_attack(Vector2(3180, 950), Vector2(3180, 1150)), "worked stone retains its original solid attack blocker")
	var threshold: MeshInstance3D = scene.temple_environment_root.get_node("RuinedSanctuaryThreshold")
	scene.teleport(Vector2(3980, 850))
	await process_frame
	await process_frame
	_check(threshold.material_override.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "complete far threshold fades when it covers the player")
	_check(scene.temple_environment_root.get_node("Masonry").material_override.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "other masonry stays solid during selective threshold fade")
	scene.teleport(Vector2(3900, 1120))
	await process_frame
	await process_frame
	_check(threshold.material_override.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "normal processional approach restores the threshold silhouette")
	_check(scene.navigation.is_open(Vector2(4038, 945), 30), "high broken corbel adds no ground obstacle beneath its overhang")
	var enemy = scene._spawn_enemy_at(Vector2(3980, 850), TrainingEnemy.Role.BEAST, 100.0)
	enemy.set_physics_process(false)
	enemy.warning_time = 0.55
	enemy.locked_direction = enemy.position.direction_to(scene.player.position)
	await process_frame
	await process_frame
	_check(threshold.material_override.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "visible enemy behind the threshold receives the same sight protection")
	_check(scene.warning_vertex_count > 0, "existing enemy attack telegraph remains present with the threshold faded")
	scene.temple_section._remove_actor(enemy)
	await process_frame
	await process_frame
	_check(threshold.material_override.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "enemy-only threshold fade restores after the actor leaves")
	# A defeated actor can be freed before the next dictionary cleanup tick.
	# Inspect validity before its type; the accelerated run exposed this case.
	var actor_count: int = scene.actors.size()
	var expired := TrainingEnemy.new()
	scene.actors[expired] = null
	expired.free()
	scene._update_temple_environment_visibility()
	scene.actors.erase(expired)
	_check(scene.actors.size() == actor_count, "visibility tolerates a freed actor pending normal cleanup")
	scene.spawn_credit = -100000.0
	scene.player.hurt_immunity = 1000.0
	scene.teleport(Vector2(3120, 710))
	for action in ["move_right", "move_down"]: Input.action_press(action)
	await _frames(90)
	for action in ["move_right", "move_down"]: Input.action_release(action)
	await _frames(2)
	_check(scene.player.position.x > 3580 and absf(scene.player.position.y - 710) < 10, "actual player walks the paved lane without a visual-only step or snag")
	for action in ["move_left", "move_up"]: Input.action_press(action)
	await _frames(90)
	for action in ["move_left", "move_up"]: Input.action_release(action)
	await _frames(2)
	_check(scene.player.position.x < 3190, "actual return travel remains reversible")
	scene.temple_section.enter_garden()
	await process_frame
	await process_frame
	_check(not scene.temple_environment_root.visible, "main-field kit hides during the separate garden visit")
	_check(not scene.temple_sanctuary_root.visible, "sanctuary ensemble also hides in the separate garden field")
	scene.temple_section.leave_garden()
	await process_frame
	await process_frame
	_check(scene.temple_environment_root.visible, "returning from the garden restores the corridor kit")
	_check(scene.temple_sanctuary_root.visible, "garden return restores the sanctuary ensemble")
	scene.run_time = scene.BOSS_TIME
	scene.teleport(Vector2(3900, 1120))
	scene.temple_section.tick(0.0)
	scene.temple_section.tick(1.3)
	_check(scene.boss_spawned and scene.boss.position == scene.temple_section.BOSS_POINT, "same four-minute destination boss can spawn beside the sample")
	scene.teleport(scene.temple_section.RETRY_POINT)
	scene.temple_section.tick(0.0)
	_check(scene.temple_section.boss_active, "existing sanctuary entry still engages the boss")
	scene.boss.set_physics_process(false)
	scene.teleport(Vector2(4350, 1180))
	scene.boss.ring_warning = 0.55
	await process_frame
	await process_frame
	_check(remnant.material_override.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "visible outer-ring warning boundary receives protection even when boss and hero are clear")
	scene.boss.ring_warning = 0
	await process_frame
	await process_frame
	_check(remnant.material_override.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "warning-only fade restores when the attack warning ends")
	# Defeat/removal may leave the scene's typed boss reference pending cleanup.
	scene.boss.queue_free()
	await process_frame
	await process_frame
	scene.TempleSanctuaryScript.update_visibility(scene.temple_sanctuary_root, scene)
	_check(not is_instance_valid(scene.boss), "visibility safely handles a freed boss before typed assignment")
	print("Temple environment resource counts: ", scene.temple_environment_root.get_meta("resource_counts"))
	print("Sanctuary environment resource counts: ", scene.temple_sanctuary_root.get_meta("resource_counts"))
	scene.queue_free()
	await process_frame
	await process_frame
	var jungle = _fresh(true, "jungle", "res://game/jungle_pass.tscn")
	await _frames(3)
	_check(jungle.temple_environment_root == null, "temple kit never appears in the inherited jungle scene")
	_check(jungle.temple_sanctuary_root == null, "sanctuary ensemble never appears in the inherited jungle scene")
	jungle.queue_free()
	await process_frame
	print("Temple environment verification: ", failures, " failures")
	quit(1 if failures else 0)


func _verify_sanctuary_geometry(scene) -> void:
	var sanctuary: Node3D = scene.temple_sanctuary_root
	_check(is_instance_valid(sanctuary), "sanctuary destination is mounted separately from the reversible v33 kit")
	if not is_instance_valid(sanctuary): return
	var sealed: Rect2 = sanctuary.get_meta("sealed_backdrop")
	for label in ["SteppedSanctuary", "BrokenRearGallery", "CourtMasonryRemnant"]:
		var mesh: MeshInstance3D = sanctuary.get_node(label)
		var bounds: Rect2 = sanctuary.get_meta("replaced_wall_area") if label == "CourtMasonryRemnant" else sealed
		var fits := true
		for vertex in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			fits = fits and vertex.is_finite() and bounds.grow(0.8).has_point(Vector2(vertex.x, vertex.z) / scene.terrain.SCALE)
		_check(fits, "structural vertices stay in shared existing blocked ground: " + label)
	var court: MeshInstance3D = sanctuary.get_node("ProcessionalCourt")
	_check(court.get_aabb().end.y <= 0.0161, "quiet paving stays below two game units with no new walking step")
	_check(not scene.navigation.is_open(Vector2(5180, 1600), 20), "destination mass occupies the existing sealed main-field separator")
	_check(not scene.clear_attack(Vector2(4750, 1060), Vector2(5000, 1060)), "dressed court remnant retains its original attack collision")


func _visible_structure_bounds(scene, mesh: MeshInstance3D) -> Rect2:
	var found := false
	var result := Rect2()
	for vertex in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var screen: Vector2 = scene.camera.unproject_position(mesh.to_global(vertex))
		if not root.get_visible_rect().has_point(screen): continue
		if not found:
			result = Rect2(screen, Vector2.ZERO)
			found = true
		else: result = result.expand(screen)
	var scale_to_output := Vector2(root.size) / root.get_visible_rect().size
	return Rect2(result.position * scale_to_output, result.size * scale_to_output)


func _output_point(scene, world: Vector3) -> Vector2:
	return scene.camera.unproject_position(world) * Vector2(root.size) / root.get_visible_rect().size
