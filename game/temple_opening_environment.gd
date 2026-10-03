class_name TempleOpeningEnvironment
extends "res://game/temple_sanctuary_environment.gd"
## Southeast Asia -> 청록 폐사원 -> waterfront approach / raised opening court.
## Reuses the worked-stone kit. Every raised solid stays in an existing barrier;
## the quiet paving follows the authoritative single-surface terrain heights.

const OPENING_COURT := Rect2(100, 780, 1100, 760)
const SOUTH_RAMP := Rect2(520, 1540, 240, 280)
const OPENING_BOUNDS := Rect2(95, 775, 1260, 1175)
const BANK_PIERS := [Rect2(416, 1565, 69, 65), Rect2(1125, 1565, 69, 65)]


static func replaces_wall(_wall: Dictionary) -> bool:
	# The opening has plateau/ramp boundaries, not replaceable wall records.
	return false


static func build(arena: Node3D) -> Node3D:
	return load("res://game/temple_opening_environment.gd").new()._build(arena)


func _build(arena: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "TempleOpeningEnvironment"
	for surface in [_stone, _paving, _growth, _threshold]:
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var groups: Array[MeshInstance3D] = []
	var structural_bounds: Array[Rect2] = []
	for plateau in arena.terrain.plateaus:
		# Retaining courses use only the existing ten-unit blocked boundary.
		for edge in arena.terrain.plateau_edge_spans(plateau):
			var area := _edge_footprint(edge)
			_retaining_courses(area, float(plateau.base), float(plateau.height), edge.side)
			structural_bounds.append(area)
	var retaining := _finish_batch(root, _stone, "WorkedCourtRetainingFaces", 0, true)
	retaining.set_meta("blocked_footprints", structural_bounds)
	_stone = SurfaceTool.new()
	_stone.begin(Mesh.PRIMITIVE_TRIANGLES)
	_vertex_counts[0] = 0
	for i in BANK_PIERS.size():
		_bank_remnant(BANK_PIERS[i], i)
		var pier := _finish_structure(root, "WestBankRemnant" if i == 0 else "EastBankRemnant", [_volume(BANK_PIERS[i], 0, 138 if i == 0 else 80)])
		pier.set_meta("blocked_footprints", [BANK_PIERS[i]])
		groups.append(pier)
	_opening_paving(arena.terrain)
	_finish_batch(root, _paving, "QuietCourtAndApproach", 1, false)
	var water_bounds: Array[Rect2] = []
	for area in arena.terrain.water_areas:
		if area.position.x > 1400 or area.position.y < 1500: continue
		_water_edge(area, water_bounds.size())
		water_bounds.append(area)
	var growth := _finish_batch(root, _growth, "WaterGardenEdges", 2, false)
	growth.set_meta("blocked_footprints", water_bounds)
	root.set_meta("occlusion_groups", groups)
	root.set_meta("region_hierarchy", ["동남아", "청록 폐사원", "수변 접근→높은 중정", "남쪽 경사로·석축·물·낮은 식생"])
	root.set_meta("slice_bounds", OPENING_BOUNDS)
	root.set_meta("source_plateaus", arena.terrain.plateaus.duplicate(true))
	root.set_meta("source_ramps", arena.terrain.ramps.duplicate(true))
	root.set_meta("source_barriers", arena.terrain.barriers().duplicate())
	root.set_meta("max_floor_lift", FLOOR_MAX_LIFT)
	root.set_meta("visual_only", true)
	var vertices := 0
	for child in root.get_children(): vertices += child.mesh.surface_get_array_len(0)
	root.set_meta("resource_counts", {"mesh_instances": root.get_child_count(), "materials": root.get_child_count(), "vertices": vertices})
	return root


func _edge_footprint(edge: Dictionary) -> Rect2:
	var horizontal: bool = edge.side in ["north", "south"]
	return Rect2(edge.start + 0.2, edge.fixed - 4.7, edge.end - edge.start - 0.4, 9.4) if horizontal else Rect2(edge.fixed - 4.7, edge.start + 0.2, 9.4, edge.end - edge.start - 0.4)


func _retaining_courses(area: Rect2, bottom: float, top: float, side: String) -> void:
	var horizontal := side in ["north", "south"]
	var length := area.size.x if horizontal else area.size.y
	var span := 110.0
	for row in 4:
		var cursor := 0.0
		var column := 0
		while cursor < length - 1:
			var width := minf(span * (0.5 if column == 0 and row % 2 else 1.0), length - cursor)
			var part := Rect2(area.position + Vector2(cursor + 0.4, 0), Vector2(width - 0.8, area.size.y)) if horizontal else Rect2(area.position + Vector2(0, cursor + 0.4), Vector2(area.size.x, width - 0.8))
			var low := lerpf(bottom, top, row / 4.0) + 0.5
			var high := lerpf(bottom, top, (row + 1) / 4.0) - 0.5
			_block(_stone, part, low, high, Color("8c9d89").lightened(0.023 * ((row + column) % 3)), row + column, 1.25)
			cursor += width
			column += 1
	# The original lip already rises four units; this stays below that top.
	_block(_stone, area, top + 0.2, top + 3.4, Color("b6bda0"), 2, 0.6)


func _bank_remnant(area: Rect2, seed: int) -> void:
	var stone := Color("a5b297")
	_block(_stone, area, 1.2, 18, stone.darkened(0.15), seed, 3)
	_block(_stone, area.grow(-4), 18.6, 31, stone.lightened(0.09), seed + 1, 2)
	var shaft := area.grow(-13)
	var top := 119.0 if seed == 0 else 63.0
	for row in 3:
		var low := lerpf(32.0, top, row / 3.0)
		var high := lerpf(32.0, top, (row + 1) / 3.0) - 0.8
		_block(_stone, shaft, low, high, stone, 20 + seed + row, 2)
	_block(_stone, area.grow(-8), top, top + 12, stone.lightened(0.13), 30 + seed, 2)
	_block(_stone, Rect2(area.position + Vector2(17, 15), Vector2(26, 31)), top + 12, top + 18, stone.darkened(0.06), 39 + seed, 2)
	_relief_band(shaft, 39, minf(top - 4, 70), seed, false)
	# Attached low plants and roots belong to this group's selective sight fade.
	_reclaim_edges(area, 1.2, top + 18, seed, _stone)


func _opening_paving(terrain) -> void:
	# Broad quiet joints on the first combat floor. Keep the terrace/ramp out of it.
	_paving_field(Rect2(120, 1294, 1060, 224), 160, Color("cdc9ac"), 212, 224, 3)
	_paving_field(Rect2(121, 799, 196, 486), 160, Color("ccc8aa"), 196, 243, 2)
	_paving_field(Rect2(328, 800, 501, 206), 160, Color("d2ccae"), 250.5, 206, 4)
	_paving_field(Rect2(866, 986, 218, 278), 320, Color("d8d0ae"), 218, 139, 2)
	# Flush slope joints, never horizontal fake steps across a changing height.
	for ramp in terrain.ramps:
		if ramp.area != SOUTH_RAMP: continue
		for row in 5:
			var area := Rect2(537, 1543 + row * 54.8, 206, 52.6)
			_surface_slab(area, terrain, Color("c9c2a2").lightened(0.015 * (row % 2)))
	for row in 2:
		_surface_slab(Rect2(541 + row * 6, 1823 + row * 56, 202 - row * 12, 53), terrain, Color("afb49a").lightened(0.02 * row))


func _surface_slab(area: Rect2, terrain, color: Color) -> void:
	var points: Array[Vector3] = []
	for point in [area.position, Vector2(area.position.x, area.end.y), area.end, Vector2(area.end.x, area.position.y)]:
		points.append(terrain.world_point(point, 0.65) / Terrain.SCALE)
	_quad(_paving, points[0], points[1], points[2], points[3], color)


func _water_edge(area: Rect2, seed: int) -> void:
	var limits := area.grow(-1.0)
	# Group the remaining garden along the outside bank; leave the inner water open.
	var center := Vector3(area.position.x + 20 if seed < 3 else area.end.x - 20, 1.3, area.get_center().y)
	_moss_patch(center, Vector2(17, 24), limits, seed, 0.1)
	for i in 5:
		_leaf_group(center + Vector3((i % 2) * 8 - 4, 0, i * 8 - 16), limits, seed * 3 + i, 1.8)
	# Short ripples never form a seam across a whole pool or imply a walking slab.
	var ripple := Vector3(area.get_center().x, 1.25, area.get_center().y + 13)
	_quad(_growth, ripple, ripple + Vector3(0, 0, 1.3), ripple + Vector3(25, 0, 1.3), ripple + Vector3(27, 0, 0), Color("579b99"))
	for blade in 5:
		var foot := center + Vector3((blade % 2) * 5 - 2, 0, blade * 6 - 12)
		var tip := _inside(foot + Vector3(3 - blade, 19 + (blade % 2) * 4, -4), limits)
		_triangle(_growth, foot + Vector3(-1, 0, 0), tip, foot + Vector3(1, 0, 0), Color("71995c").lightened(blade * 0.015))
