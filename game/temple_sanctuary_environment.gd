class_name TempleSanctuaryEnvironment
extends "res://game/temple_environment_kit.gd"
## Southeast Asia -> existing ruined temple -> sanctuary approach / sanctuary.
## The building sits in the already sealed east strip, never on the fight floor.

const COURT := Rect2(3990, 540, 950, 1040)
const COURT_REMNANT := Rect2(4820, 970, 100, 180)
const SEALED_BACKDROP := Rect2(5090, 0, 510, 2160)
const SHRINE_BOUNDS := Rect2(5092, 950, 456, 500)
const SHRINE_HEIGHT := 554.0


static func replaces_wall(wall: Dictionary) -> bool:
	return wall.get("area", Rect2()) == COURT_REMNANT


static func build(arena: Node3D) -> Node3D:
	return load("res://game/temple_sanctuary_environment.gd").new()._build(arena)


func _build(arena: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "TempleSanctuaryEnvironment"
	for surface in [_stone, _paving, _growth, _threshold]:
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var groups: Array[MeshInstance3D] = []
	_shrine()
	groups.append(_finish_structure(root, "SteppedSanctuary", [
		_volume(SHRINE_BOUNDS, 0, 55),
		_volume(Rect2(5096, 967, 418, 464), 55, 110),
		_volume(Rect2(5100, 983, 380, 430), 110, 166),
		_volume(Rect2(5102, 996, 338, 402), 166, 220),
		_volume(Rect2(5104, 1000, 250, 350), 220, 430),
		_volume(Rect2(5104, 1350, 71, 40), 220, 430),
		_volume(Rect2(5280, 1350, 74, 40), 220, 430),
		_volume(Rect2(5098, 988, 270, 414), 400, 452),
		_volume(Rect2(5128, 1025, 211, 330), 452, SHRINE_HEIGHT),
	]))
	root.set_meta("doorway_points", [Vector3(5175, 220, 1390) * Terrain.SCALE, Vector3(5280, 220, 1390) * Terrain.SCALE, Vector3(5175, 400, 1390) * Terrain.SCALE, Vector3(5280, 400, 1390) * Terrain.SCALE])
	root.set_meta("doorway_recess_point", Vector3(5210, 300, 1351) * Terrain.SCALE)
	root.set_meta("arrival_plinth_point", Vector3(5140, 166, 1410) * Terrain.SCALE)
	_gallery()
	groups.append(_finish_structure(root, "BrokenRearGallery", [
		_volume(Rect2(5100, 600, 390, 350), 0, 25),
		_volume(Rect2(5350, 600, 90, 350), 25, 145),
		_volume(Rect2(5110, 650, 90, 100), 25, 236),
		_volume(Rect2(5110, 875, 90, 75), 25, 176),
		_volume(Rect2(5118, 720, 79, 115), 205, 244),
	]))
	for wall in arena.terrain.wall_areas:
		if not replaces_wall(wall): continue
		_gallery_fragment(COURT_REMNANT, float(wall.get("base", 0.0)), float(wall.height), 2)
		_reclaim_edges(COURT_REMNANT, 0, float(wall.height), 2)
	groups.append(_finish_structure(root, "CourtMasonryRemnant", [_volume(COURT_REMNANT, 0, 130)]))
	_court()
	_finish_batch(root, _paving, "ProcessionalCourt", 1, false)
	_finish_batch(root, _growth, "ReclaimedStructuralEdges", 2, false)
	root.set_meta("occlusion_groups", groups)
	root.set_meta("region_hierarchy", ["동남아", "청록 폐사원", "성소 접근→성소", "폐허 성소·전투 뜰·가장자리 식생"])
	root.set_meta("sealed_backdrop", SEALED_BACKDROP)
	root.set_meta("replaced_wall_area", COURT_REMNANT)
	root.set_meta("max_floor_lift", FLOOR_MAX_LIFT)
	root.set_meta("visual_only", true)
	var vertices := 0
	for child in root.get_children():
		vertices += child.mesh.surface_get_array_len(0)
	root.set_meta("resource_counts", {"mesh_instances": root.get_child_count(), "materials": root.get_child_count(), "vertices": vertices})
	return root


func _shrine() -> void:
	var stone := Color("a6ae92")
	# The chamber is close to the court, on a substantial raised stone plinth.
	# A short corbel crown leaves the doorway, rather than a pyramid, dominant.
	var steps := [
		[SHRINE_BOUNDS, 0.0, 55.0],
		[Rect2(5096, 967, 418, 464), 55.7, 110.0],
		[Rect2(5100, 983, 380, 430), 110.7, 166.0],
		[Rect2(5102, 996, 338, 402), 166.7, 220.0],
	]
	for i in steps.size():
		var area: Rect2 = steps[i][0]
		_block(_stone, area.grow(-3), steps[i][1], steps[i][2] - 9, stone.darkened(0.11), 4 + i, 4)
		_block(_stone, area, steps[i][2] - 8.3, steps[i][2], stone.lightened(0.12), 9 + i, 3)
	for course in 4:
		var bottom := 221.0 + course * 52.0
		var tint := stone.lightened(0.025 * (course % 3))
		_block(_stone, Rect2(5104, 1000, 250, 350), bottom, bottom + 50.5, tint, course + 11, 2.8)
		_block(_stone, Rect2(5104, 1350, 71, 40), bottom, bottom + 50.5, tint, course + 20, 2.5)
		_block(_stone, Rect2(5280, 1350, 74, 40), bottom, bottom + 50.5, tint, course + 30, 2.5)
	_quad(_stone, Vector3(5175, 221, 1351), Vector3(5280, 221, 1351), Vector3(5280, 402, 1351), Vector3(5175, 402, 1351), Color("405e59"))
	for area in [Rect2(5120, 1280, 26, 118), Rect2(5315, 1280, 26, 118)]:
		_block(_stone, area, 220, 391, stone.darkened(0.07), 45, 2.5)
		_block(_stone, area.grow(3), 391.7, 428, stone.lightened(0.15), 46, 2)
	_block(_stone, Rect2(5170, 1350, 115, 48), 400, 430, stone.darkened(0.13), 47, 3)
	_relief_band(Rect2(5103, 1000, 252, 398), 348, 386, 2, false)
	var tiers := [
		[Rect2(5098, 988, 270, 414), 430.0, 452.0],
		[Rect2(5128, 1025, 211, 330), 453.0, 489.0],
		[Rect2(5150, 1060, 164, 251), 490.0, 524.0],
		[Rect2(5174, 1100, 113, 163), 525.0, SHRINE_HEIGHT],
	]
	for i in tiers.size():
		var tier: Array = tiers[i]
		var area: Rect2 = tier[0]
		var bottom: float = tier[1]
		var top: float = tier[2]
		_block(_stone, area.grow(-5), bottom, top - 9, stone.darkened(0.06), 51 + i, 4)
		_block(_stone, area, top - 8.3, top, stone.lightened(0.17), 62 + i, 3)
	# Roots attached to this facade fade with its stone, never float opaque.
	var limits := SHRINE_BOUNDS.grow(-1)
	_root([Vector3(5347, 429, 1350), Vector3(5349, 345, 1366), Vector3(5347, 270, 1384), Vector3(5350, 221, 1391), Vector3(5380, 167, 1402), Vector3(5455, 56, 1415)], 4.0, limits, Color("847d55"), _stone)
	_root([Vector3(5347, 270, 1384), Vector3(5331, 242, 1391), Vector3(5313, 221, 1394)], 2.5, limits, Color("89845c"), _stone)
	for spec in [[Vector3(5516, 55.5, 980), Vector2(23, 25)], [Vector3(5495, 55.5, 1415), Vector2(27, 24)]]:
		_edge_growth(spec[0], spec[1], limits, 4)


func _gallery() -> void:
	var stone := Color("92a58e")
	_block(_stone, Rect2(5100, 600, 390, 350), 0, 25, stone.darkened(0.10), 2, 4)
	for i in 2:
		_block(_stone, Rect2(5350, 600 + i * 175, 90, 171), 25.7, 122 + i * 23, stone, 81 + i, 4)
	for spec in [[Rect2(5110, 650, 90, 100), 236.0], [Rect2(5110, 875, 90, 75), 176.0]]:
		var area: Rect2 = spec[0]
		var top: float = spec[1]
		_block(_stone, area, 25, 50, stone.darkened(0.07), 90, 3)
		for i in 4:
			var bottom := 51.0 + i * (top - 72) / 4.0
			_block(_stone, area.grow(-12), bottom, bottom + (top - 72) / 4.0 - 1, stone, 91 + i, 3)
		_block(_stone, area.grow(-4), top - 22, top, stone.lightened(0.17), 95, 3)
		_relief_band(area.grow(-12), 74, 120, 2, true)
	_block(_stone, Rect2(5118, 720, 79, 77), 205, 225, stone.darkened(0.05), 96, 3)
	_block(_stone, Rect2(5118, 720, 79, 115), 226, 244, stone.lightened(0.12), 97, 4)
	for i in 3:
		_block(_stone, Rect2(5210 + i * 32, 780 + i * 40, 68, 58), 25, 46 + i * 9, stone.darkened(0.03), 100 + i, 4)
	for center in [Vector3(5420, 25.5, 660), Vector3(5200, 25.5, 890)]:
		_edge_growth(center, Vector2(24, 31), Rect2(5102, 602, 386, 346), 9)


func _court() -> void:
	# Large, quiet courses carry the procession into the existing duel court.
	# Their sub-unit lift has no gameplay height or collision of its own.
	_paving_field(COURT.grow(-6), 0.7, Color("d5cbb0"), 236, 256, 4)
	_paving_field(Rect2(3998, 1012, 812, 178), 0.73, Color("ded5ba"), 203, 178, 2)
	for z in [548.0, 1556.0]:
		_paving_field(Rect2(4000, z, 928, 16), 0.75, Color("aeb59a"), 232, 16, 1)


func _edge_growth(center: Vector3, radius: Vector2, limits: Rect2, seed: int) -> void:
	_moss_patch(center, radius, limits, seed, 0.6)
	for i in 4:
		_leaf_group(center + Vector3((i % 2) * 12 - 6, 1, floori(i / 2.0) * 14 - 7), limits, seed + i, 1.5)


func _volume(area: Rect2, bottom: float, top: float) -> AABB:
	return AABB(Vector3(area.position.x, bottom, area.position.y) * Terrain.SCALE, Vector3(area.size.x, top - bottom, area.size.y) * Terrain.SCALE)


func _finish_structure(root: Node3D, label: String, volumes: Array) -> MeshInstance3D:
	var mesh := _finish_batch(root, _stone, label, 0, true)
	mesh.set_meta("occlusion_volumes", volumes)
	_stone = SurfaceTool.new()
	_stone.begin(Mesh.PRIMITIVE_TRIANGLES)
	_vertex_counts[0] = 0
	return mesh


static func update_visibility(root: Node3D, arena: Node3D) -> void:
	if not root.visible or not is_instance_valid(arena.player): return
	var targets: Array[Vector3] = []
	if not arena.overview:
		for actor in arena.actors:
			if not is_instance_valid(actor): continue
			if actor != arena.player and (not actor is TrainingEnemy or actor.health <= 0): continue
			if not is_instance_valid(arena.actors[actor]) or not arena.actors[actor].is_visible_in_tree(): continue
			if actor.position.distance_to(arena.player.position) > 1500: continue
			var center: Vector3 = arena.terrain.world_point(actor.position, 55)
			if not arena.get_viewport().get_visible_rect().grow(30).has_point(arena.camera.unproject_position(center)): continue
			for lift in [10.0, 65.0, 120.0 if actor is GateBoss else 85.0]:
				targets.append(arena.terrain.world_point(actor.position, lift))
		_add_boss_warning_targets(arena, targets)
	var visible_targets: Array[Vector3] = []
	for target in targets:
		if arena.get_viewport().get_visible_rect().grow(12).has_point(arena.camera.unproject_position(target)): visible_targets.append(target)
	var toward_camera: Vector3 = arena.camera.global_basis.z * 40.0
	for group in root.get_meta("occlusion_groups", []):
		var obscures := false
		for target in visible_targets:
			for volume in group.get_meta("occlusion_volumes", []):
				if (volume as AABB).intersects_segment(target, target + toward_camera) != null:
					obscures = true
					break
			if obscures: break
		if not group.has_meta("solid_material"):
			var solid: StandardMaterial3D = group.material_override
			var faded := solid.duplicate() as StandardMaterial3D
			faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			faded.albedo_color.a = 0.12
			group.set_meta("solid_material", solid)
			group.set_meta("faded_material", faded)
		group.material_override = group.get_meta("faded_material" if obscures else "solid_material")
		group.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if obscures else GeometryInstance3D.SHADOW_CASTING_SETTING_ON


static func _add_boss_warning_targets(arena: Node3D, targets: Array[Vector3]) -> void:
	if not is_instance_valid(arena.boss): return
	var boss: GateBoss = arena.boss
	if not boss.encounter_active: return
	var radius := GateBoss.RING_OUTER_RADIUS if boss.ring_warning > 0 or (boss.impact_flash > 0 and boss.impact_is_ring) else GateBoss.SHOCK_RADIUS
	if boss.shock_warning > 0 or boss.ring_warning > 0 or boss.impact_flash > 0:
		for i in 48:
			var angle := TAU * i / 48.0
			var point := boss.global_position + Vector2.from_angle(angle) * radius
			if arena.clear_attack(boss.global_position, point): targets.append(arena.terrain.world_point(point, 65))
	if boss.warning_time > 0:
		var reach: float = arena._attack_reach_at(boss.position, boss.locked_direction.angle(), boss.charge_reach())
		var half_width: float = boss.collision_radius + arena.player.collision_radius + boss.contact_margin + 7.0
		for i in 9:
			for side in [-1.0, 1.0]:
				var point: Vector2 = boss.position + boss.locked_direction * reach * i / 8.0 + boss.locked_direction.orthogonal() * half_width * side
				targets.append(arena.terrain.world_point(point, 65))
