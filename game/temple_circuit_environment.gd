extends RefCounted
## Reuse the existing sanctuary's authored stonework behind the new court.
const Sanctuary = preload("res://game/temple_sanctuary_environment.gd")
const OFFSET := Vector3(-25.2, 0.0, -12.1)
const FOOTPRINT := Rect2(2572, 0, 456, 240)
const FAR_BANK_GROVES := [Vector2(330, 500), Vector2(420, 1150), Vector2(300, 1900), Vector2(1000, 300), Vector2(1530, 300)]
static func build(arena: Node3D) -> Node3D:
	var root := Node3D.new()
	var builder = Sanctuary.new()
	for surface in [builder._stone, builder._paving, builder._growth, builder._threshold]:
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder._shrine()
	builder._finish_batch(root, builder._stone, "SteppedSanctuary", 0, true)
	builder._finish_batch(root, builder._growth, "AttachedMoss", 2, false)
	var court := _build_court(arena)
	court.position = -OFFSET
	root.add_child(court)
	var groves := preload("res://game/wetland_root_environment.gd").build(arena, FAR_BANK_GROVES)
	groves.name = "FarBankGroves"
	groves.position = -OFFSET
	root.add_child(groves)
	root.name = "CircuitSanctuaryBackdrop"
	root.position = OFFSET
	root.set_meta("visual_only", true)
	root.set_meta("region_hierarchy", ["동남아", "사원 동선 후보", "성소", "기존 석조 재사용"])
	root.set_meta("candidate_footprint", FOOTPRINT)
	return root

static func _build_court(arena: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "ReclaimedCourtMasonry"
	var builder = preload("res://game/temple_environment_kit.gd").new()
	for surface in [builder._stone, builder._paving, builder._growth, builder._threshold]:
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var footprints: Array[Rect2] = []
	for wall in arena.terrain.wall_areas:
		if not wall.get("circuit_masonry", false): continue
		var area: Rect2 = wall.area
		var top: float = wall.height
		builder._gallery_fragment(area, 0.0, top, footprints.size())
		builder._reclaim_edges(area, 0.0, top, footprints.size())
		footprints.append(area)
	# Broad stone courses stay on the low raised court; every ramp band follows its slope.
	var court: Rect2 = arena.terrain.plateaus[0].area
	builder._paving_field(court.grow(-6), 120.75, Color("b9b496"), 238, 246, 4)
	for ramp in arena.terrain.ramps:
		for band in 9:
			var area: Rect2 = ramp.area
			area.position[ramp.axis] += ramp.area.size[ramp.axis] * float(band) / 9.0 + 0.8
			area.size[ramp.axis] = ramp.area.size[ramp.axis] / 9.0 - 1.6
			var points := [area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)]
			var vertices: Array[Vector3] = []
			for point in points: vertices.append(Vector3(point.x, arena.terrain.ramp_height(ramp, point) + 0.75, point.y))
			builder._quad(builder._paving, vertices[0], vertices[3], vertices[2], vertices[1], Color("bab294").lightened(0.018 * (band % 2)))
	builder._finish_batch(root, builder._paving, "CourtAndStairCourses", 1, false)
	builder._finish_batch(root, builder._stone, "WeatheredCourtyardWalls", 0, true)
	builder._finish_batch(root, builder._growth, "CourtyardEdgeGrowth", 2, false)
	root.set_meta("collision_footprints", footprints)
	return root
