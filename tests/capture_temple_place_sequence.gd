extends "res://tests/capture_regional_landmarks.gd"
## Same normal-speed walk on pinned a141b6c and candidate; two full ring directions.
## Inherits the actual player/camera-follow and Body differential render checks.
## Time/spawn pressure is frozen. No natural combat or aesthetic acceptance claim.

func _samples() -> Array:
	return [
		{"name":"01-entry", "point":Vector2(650,3000)},
		{"name":"02-water-landing", "point":Vector2(1120,2820)},
		{"name":"03-west-stairs", "point":Vector2(1650,2275)},
		{"name":"04-open-court", "point":Vector2(2450,2100)},
		{"name":"05-cloister-entry", "point":Vector2(1450,1900)},
		{"name":"06-cloister", "point":Vector2(1450,1350)},
		{"name":"07-hidden-return", "point":Vector2(1310,920)},
		{"name":"08-gallery-turn", "point":Vector2(1650,910)},
		{"name":"09-sanctuary-reveal", "point":Vector2(2650,1000)},
		{"name":"10-human-door", "point":Vector2(2800,460)},
		{"name":"11-boss-floor", "point":Vector2(2800,620)},
		{"name":"12-water-merge", "point":Vector2(3350,1190)},
		{"name":"13-open-bank", "point":Vector2(3440,1750)},
		{"name":"14-water-walk", "point":Vector2(3400,2080)},
		{"name":"15-east-stairs", "point":Vector2(3060,2390)},
		{"name":"16-court-return", "point":Vector2(2450,2100)},
		{"name":"17-entry-return", "point":Vector2(1350,2800)},
	]

func _walk(goal: Vector2) -> void:
	await super._walk(goal)
	# Native shader/window startup can consume the fixed wall-time wait before
	# enough physics follow steps have run. Let the normal follow settle itself;
	# never set camera transforms or teleport to make a capture assertion pass.
	for frame in 120:
		var expected: Vector3 = scene.terrain.world_point(scene.player.position,35) + scene.camera_offset
		if scene.camera.position.distance_to(expected) < 0.01: return
		await physics_frame
	errors.append("Normal camera follow did not settle within120 physics frames")

func _capture_checkpoint(label: String, width: int, record: Dictionary) -> void:
	# Place comparison deliberately hides location labels in the capture fixture.
	for tag in scene.find_children("*", "Label3D", true, false): tag.hide()
	record["place_labels_hidden"] = true
	var enemy: TrainingEnemy
	if label in ["04-open-court", "06-cloister", "14-water-walk"]:
		var point: Vector2 = scene.player.position + Vector2(110,-100)
		if not scene.navigation.is_open(point, 30) or not scene.clear_attack(point, scene.player.position):
			errors.append("Enemy tell fixture cannot use legal nearby floor at " + label)
			return
		enemy = scene._spawn_enemy_at(point, TrainingEnemy.Role.LAMP if label == "14-water-walk" else TrainingEnemy.Role.BEAST, 40.0)
		enemy.set_physics_process(false)
		enemy.warning_time = 0.3
		enemy.locked_direction = point.direction_to(scene.player.position)
		for i in 3: await process_frame
		scene._draw_enemy_warnings(1.0)
		record["fixed_enemy_tell"] = {"role":enemy.role, "point":_point(point), "warning_time":enemy.warning_time, "warning_surfaces":scene.warning_mesh.get_surface_count(), "scope":"fixed real enemy/rendered telegraph, no attack or difficulty claim"}
		if scene.warning_mesh.get_surface_count() == 0: errors.append("Missing actual enemy telegraph at " + label)
	await super._capture_checkpoint(label, width, record)
	if not is_instance_valid(enemy) and record.has("visibility") and record.visibility.ratio < 0.98:
		errors.append("Player Body visibility below98% at " + label)
	if is_instance_valid(enemy):
		var visual: Node3D = scene.actors[enemy]
		scene.set_process(false)
		scene.set_physics_process(false)
		scene.player.set_physics_process(false)
		# The inherited reference removes the existing attack tell too: its deliberate
		# overlap with the player's feet is not a new scenery obstruction. Preserve
		# that raw result and additionally compare with identical actors/tells.
		record["player_scenery_visibility"] = await _geometry_visibility(scene.actors[scene.player].get_node("Body"), 80, label + "-hero", width)
		record["enemy_body_visibility"] = await _geometry_visibility(visual.get_node("Body"), 80, label + "-enemy", width)
		record["enemy_tell_visibility"] = await _geometry_visibility(scene.warning_visual, 200, label + "-tell", width, scene.terrain.world_point(enemy.position))
		if record.player_scenery_visibility.get("ratio",0.0) < 0.98: errors.append("Player scenery visibility below98% at " + label)
		if record.enemy_body_visibility.get("ratio",0.0) < 0.98: errors.append("Enemy Body visibility below98% at " + label)
		if record.enemy_tell_visibility.get("ratio",0.0) < 0.95: errors.append("Enemy tell visibility below95% at " + label)
		scene.player.set_physics_process(true)
		scene.set_process(true)
		scene.set_physics_process(true)
		visual.queue_free()
		scene.actors.erase(enemy)
		scene.actor_motion.erase(enemy)
		enemy.queue_free()
		for i in 3: await process_frame

func _geometry_visibility(geometry: GeometryInstance3D, radius: int, label: String, width: int, at: Vector3 = Vector3.INF) -> Dictionary:
	var normal := await _image()
	geometry.hide()
	var normal_without := await _image()
	geometry.show()
	var hidden: Array[GeometryInstance3D] = []
	for node in scene.find_children("*","GeometryInstance3D",true,false):
		if node == scene.warning_visual or not node.visible: continue
		var actor_geometry := false
		for actor in scene.actors.values():
			if actor.is_ancestor_of(node): actor_geometry = true
		if actor_geometry: continue
		hidden.append(node)
		node.hide()
	var reference := await _image()
	geometry.hide()
	var reference_without := await _image()
	geometry.show()
	for node in hidden: node.show()
	if normal == null or normal_without == null or reference == null or reference_without == null: return {}
	expected_screenshots += 1
	_save(reference,"%s-reference-%d.png" % [label,width])
	var logical_rect: Rect2 = scene.camera.get_viewport().get_visible_rect()
	var center: Vector2 = (scene.camera.unproject_position(geometry.global_position if at == Vector3.INF else at) - logical_rect.position) * Vector2(normal.get_size()) / logical_rect.size
	var roi := Rect2i(Vector2i(center) - Vector2i(radius,radius),Vector2i(radius*2,radius*2)).intersection(Rect2i(Vector2i.ZERO,normal.get_size()))
	var potential := 0
	var visible := 0
	for y in range(roi.position.y,roi.end.y):
		for x in range(roi.position.x,roi.end.x):
			if _different(reference.get_pixel(x,y),reference_without.get_pixel(x,y)):
				potential += 1
				if _different(normal.get_pixel(x,y),normal_without.get_pixel(x,y)): visible += 1
	if potential < 50: errors.append("Unusable Body/telegraph pixel reference at " + label)
	return {"reference_pixels":potential,"normal_pixels":visible,"ratio":float(visible)/maxf(1.0,potential),"roi":[roi.position.x,roi.position.y,roi.size.x,roi.size.y],"scope":"fixed real enemy Body/telegraph differential, scenery hidden reference with same actors; bounded sample"}
