class_name TempleEnvironmentKit
extends RefCounted
## A bounded, visual-only stone kit for the existing temple gallery and approach.
## Southeast Asia -> 청록 폐사원 -> 회랑 / 성소 접근 -> masonry and paving.
## There is no established intermediate regional name. This kit invents none.
## Call build(arena), then add the returned root. Skip default wall visuals only
## when replaces_wall(wall) is true; keep every original collision/terrain record.

const Terrain = preload("res://game/hybrid_terrain.gd")
const REGION_HIERARCHY := ["동남아", "청록 폐사원", "회랑→성소 접근"]
const SLICE_BOUNDS := Rect2(3030, 560, 1170, 1000)
const REPLACED_WALL_AREAS := [
	Rect2(3120, 1010, 120, 80), Rect2(3540, 1010, 120, 80),
	Rect2(4020, 730, 36, 165), Rect2(4020, 1270, 36, 165),
]
const GALLERY_LANES := [Rect2(3060, 630, 690, 190), Rect2(3060, 1280, 690, 210)]
const APPROACH_FLOOR := Rect2(3780, 960, 210, 320)
const GALLERY_FLOOR := Rect2(3030, 560, 750, 1000)
const FLOOR_MAX_LIFT := 0.85
const ELEVATED_WALL_AREA := Rect2(4020, 730, 36, 165)
const THRESHOLD_HEIGHT := 264.0
const THRESHOLD_OVERHANG := 76.0
const THRESHOLD_CLEARANCE := 203.0

var _stone := SurfaceTool.new()
var _paving := SurfaceTool.new()
var _growth := SurfaceTool.new()
var _threshold := SurfaceTool.new()
var _vertex_counts := [0, 0, 0, 0]
var _stone_blocks := 0
var _paving_slabs := 0
var _leaf_groups := 0
var _root_strands := 0
var _moss_patches := 0


static func replaces_wall(wall: Dictionary) -> bool:
	# Exact records avoid suppressing a nearby garden wall or future obstruction.
	return REPLACED_WALL_AREAS.has(wall.get("area", Rect2()))


static func build(arena: Node3D) -> Node3D:
	# Loading the script also works before the editor has refreshed global classes.
	return load("res://game/temple_environment_kit.gd").new()._build(arena)


func _build(arena: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "TempleEnvironmentKit"
	for surface in [_stone, _paving, _growth, _threshold]:
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var replaced: Array[Rect2] = []
	var built_floors: Array[Rect2] = []
	var wall_specs: Array[Dictionary] = []
	var threshold_spec: Dictionary = {}
	for wall in arena.terrain.wall_areas:
		if not replaces_wall(wall):
			continue
		var area: Rect2 = wall.area
		var bottom: float = wall.get("base", 0.0)
		var top: float = wall.height
		if top <= bottom:
			continue
		var seed := REPLACED_WALL_AREAS.find(area)
		var elevated := area == ELEVATED_WALL_AREA
		if area.size.x > area.size.y:
			_pier(area, bottom, top, seed)
		else:
			_gallery_fragment(area, bottom, top, seed, _threshold if elevated else _stone)
		_reclaim_edges(area, bottom, top, seed, _threshold if elevated else _growth)
		if elevated:
			_ruined_threshold(area, top)
			threshold_spec = {
				"source_area": area, "base_height": bottom, "elevation_start_height": top,
				"height": THRESHOLD_HEIGHT, "max_visual_height": THRESHOLD_HEIGHT,
				"visual_bounds": Rect2(area.position, area.size + Vector2(0.0, THRESHOLD_OVERHANG)),
				"overhang_area": Rect2(area.position.x, area.end.y, area.size.x, THRESHOLD_OVERHANG),
				"overhang_clearance": THRESHOLD_CLEARANCE, "visual_only": true,
			}
		replaced.append(area)
		wall_specs.append({"area": area, "base": bottom, "height": top})
	for floor_record in arena.terrain.floor_areas:
		var area: Rect2 = floor_record.area
		var level: float = floor_record.get("height", 0.7)
		if GALLERY_LANES.has(area):
			_gallery_paving(area, level, GALLERY_LANES.find(area))
			built_floors.append(area)
		elif area == APPROACH_FLOOR:
			_paving_field(area.grow(-5.0), level, Color("c9c0a3"), 67.0, 63.0, 7)
			built_floors.append(area)
		elif area == GALLERY_FLOOR:
			# Flat edge courses frame the courtyard; they never become new walls.
			_paving_field(Rect2(area.position, Vector2(area.size.x, 15.0)), level, Color("929f8c"), 96.0, 15.0, 11)
			_paving_field(Rect2(area.position.x, area.end.y - 15.0, area.size.x, 15.0), level, Color("929f8c"), 96.0, 15.0, 15)
	_finish_batch(root, _stone, "Masonry", 0, true)
	_finish_batch(root, _paving, "Paving", 1, false)
	_finish_batch(root, _growth, "RootsAndLowLeaves", 2, false)
	var threshold_mesh := _finish_batch(root, _threshold, "RuinedSanctuaryThreshold", 3, true)
	if threshold_mesh != null:
		for key in threshold_spec:
			threshold_mesh.set_meta(key, threshold_spec[key])
	root.set_meta("region_hierarchy", REGION_HIERARCHY.duplicate())
	root.set_meta("slice_bounds", SLICE_BOUNDS)
	root.set_meta("replaced_wall_areas", replaced)
	root.set_meta("wall_specs", wall_specs)
	root.set_meta("paved_floor_areas", built_floors)
	root.set_meta("max_floor_lift", FLOOR_MAX_LIFT)
	root.set_meta("elevated_threshold", threshold_spec)
	root.set_meta("threshold_meshes", [threshold_mesh] if threshold_mesh != null else [])
	root.set_meta("visual_only", true)
	root.set_meta("resource_counts", {
		"mesh_instances": root.get_child_count(), "materials": root.get_child_count(),
		"mesh_surfaces": root.get_child_count(), "vertices": _vertex_counts.reduce(func(a, b): return a + b, 0),
		"stone_blocks": _stone_blocks, "paving_slabs": _paving_slabs,
		"leaf_groups": _leaf_groups, "root_strands": _root_strands, "moss_patches": _moss_patches,
	})
	return root


func _pier(area: Rect2, bottom: float, top: float, seed: int) -> void:
	var height := top - bottom
	var stone := Color("91a597")
	_block(_stone, area, bottom, bottom + height * 0.14, stone.darkened(0.11), seed, 2.4)
	_block(_stone, area.grow(-3.0), bottom + height * 0.14, bottom + height * 0.23, stone.lightened(0.08), seed + 1, 2.1)
	var body := area.grow(-10.0)
	for course in range(2):
		var course_bottom := bottom + height * (0.23 + course * 0.235) + 0.65
		var joint := body.position.x + body.size.x * (0.44 if (course + seed) % 2 == 0 else 0.61)
		for part in [Rect2(body.position, Vector2(joint - body.position.x - 0.7, body.size.y)), Rect2(joint + 0.7, body.position.y, body.end.x - joint - 0.7, body.size.y)]:
			_block(_stone, part, course_bottom, course_bottom + height * 0.235 - 1.3, stone.lightened(course * 0.025), seed + course + 4, 2.0)
	_block(_stone, area.grow(-7.0), bottom + height * 0.70, bottom + height * 0.79, stone.darkened(0.04), seed + 7, 1.6)
	_block(_stone, area.grow(-0.4), bottom + height * 0.79, top - 0.2, stone.lightened(0.16), seed + 10, 4.0)
	_cap_weathering(area, top, seed)
	_relief_band(body, bottom + height * 0.39, bottom + height * 0.65, seed, false)
	_relief_band(body, bottom + height * 0.39, bottom + height * 0.65, seed, true)


func _gallery_fragment(area: Rect2, bottom: float, top: float, seed: int, surface: SurfaceTool = null) -> void:
	if surface == null: surface = _stone
	var height := top - bottom
	var stone := Color("a7b19a")
	_block(surface, area, bottom, bottom + height * 0.13, stone.darkened(0.14), seed, 2.0)
	var body := area.grow(-2.5)
	for course in range(4):
		var course_bottom := bottom + height * (0.13 + course * 0.185) + 0.55
		var cursor := body.position.y
		var piece := 0
		while cursor < body.end.y - 0.5:
			var span := minf(43.0 if piece == 0 and course % 2 == 1 else 65.0, body.end.y - cursor)
			if span > 1.5:
				var block_area := Rect2(body.position.x, cursor + 0.6, body.size.x, span - 1.2)
				_block(surface, block_area, course_bottom, course_bottom + height * 0.185 - 1.1, stone.lightened(float((course + piece) % 3) * 0.035), seed + course * 3 + piece, 1.8)
			cursor += span
			piece += 1
	# Three coping stones keep the original peak while giving the ends a worn step.
	for cap in range(3):
		var cap_area := Rect2(area.position.x + 0.4, area.position.y + cap * area.size.y / 3.0 + 0.6, area.size.x - 0.8, area.size.y / 3.0 - 1.2)
		var cap_top := top - (4.0 if cap == seed % 3 else 0.0)
		_block(surface, cap_area, bottom + height * 0.87, cap_top, stone.lightened(0.15), seed + cap + 20, 2.9)
	_relief_band(body, bottom + height * 0.48, bottom + height * 0.67, seed, true, surface)


func _cap_weathering(area: Rect2, top: float, seed: int) -> void:
	# A few broad marks survive the gameplay camera; no speckled noise texture.
	var origin := area.position + Vector2(10.0, 8.0)
	var fracture: Array[Vector2] = [origin, origin + Vector2(18, 14), origin + Vector2(23, 25), origin + Vector2(42, 32)]
	if seed % 2 == 1:
		for i in range(fracture.size()):
			fracture[i].x = area.position.x + area.end.x - fracture[i].x
	for i in range(fracture.size() - 1):
		var a := fracture[i]
		var b := fracture[i + 1]
		var side := (b - a).orthogonal().normalized() * (0.85 if i == 0 else 0.6)
		_quad(_stone, Vector3(a.x + side.x, top - 0.11, a.y + side.y), Vector3(b.x + side.x, top - 0.11, b.y + side.y), Vector3(b.x - side.x, top - 0.11, b.y - side.y), Vector3(a.x - side.x, top - 0.11, a.y - side.y), Color("718777"))
	var patch_center := Vector3(area.end.x - 22.0 if seed % 2 == 0 else area.position.x + 22.0, top - 0.1, area.end.y - 17.0)
	_moss_patch(patch_center, Vector2(15.0, 9.0), area.grow(-6.0), seed + 3, 0.05)


func _ruined_threshold(area: Rect2, base: float) -> void:
	# One deliberately taller rear threshold member; the near member stays broken.
	# Its shaft remains in the existing wall footprint. Only the high corbel reaches
	# into the opening, leaving the central approach and every ground record intact.
	var stone := Color("a8b49c")
	var end := area.end.y
	var shaft := Rect2(area.position.x + 4.0, end - 64.0, area.size.x - 8.0, 61.0)
	_block(_threshold, Rect2(area.position.x + 2.0, end - 70.0, area.size.x - 4.0, 68.0), base, 130.0, stone.darkened(0.1), 31, 2.0)
	_block(_threshold, shaft, 130.7, 153.0, stone, 32, 2.0)
	_block(_threshold, shaft, 153.7, 177.0, stone.lightened(0.05), 34, 2.4)
	_block(_threshold, Rect2(area.position.x + 1.5, end - 74.0, area.size.x - 3.0, 73.0), 177.5, 194.0, stone.darkened(0.02), 35, 2.5)
	_block(_threshold, Rect2(area.position.x + 1.0, end - 82.0, area.size.x - 2.0, 82.0), 194.5, THRESHOLD_CLEARANCE, stone.lightened(0.13), 36, 1.8)
	# Successive corbels form a broken lintel arm, not a roof or a full overhead gate.
	_block(_threshold, Rect2(area.position.x + 1.0, end - 82.0, area.size.x - 2.0, 106.0), THRESHOLD_CLEARANCE, 222.0, stone, 37, 2.5)
	_block(_threshold, Rect2(area.position.x + 1.0, end - 84.0, area.size.x - 2.0, 135.0), 222.5, 243.0, stone.lightened(0.06), 38, 3.0)
	_block(_threshold, Rect2(area.position.x + 0.4, end - 94.0, area.size.x - 0.8, 120.0), 243.5, THRESHOLD_HEIGHT - 0.2, stone.lightened(0.16), 39, 3.0)
	_block(_threshold, Rect2(area.position.x + 0.4, end + 26.8, area.size.x - 0.8, THRESHOLD_OVERHANG - 26.8), 243.5, THRESHOLD_HEIGHT - 6.0, stone.lightened(0.13), 40, 4.2)
	_relief_band(shaft, 146.0, 172.0, 1, true, _threshold)
	var limits := Rect2(area.position + Vector2(0.2, 0.2), area.size + Vector2(-0.4, THRESHOLD_OVERHANG - 0.4))
	var face := area.end.x
	var roots: Array[Vector3] = [
		Vector3(face - 0.8, 241.0, end - 54.0), Vector3(face - 0.8, 215.0, end - 51.0),
		Vector3(face - 1.0, 194.0, end - 47.0), Vector3(face - 2.0, 165.0, end - 44.0),
		Vector3(face - 2.0, 133.0, end - 36.0), Vector3(face - 1.2, base + 1.5, end - 27.0),
	]
	_root(roots, 1.35, limits, Color("817d57"), _threshold)
	_root([roots[3], Vector3(face - 2.0, 145.0, end - 29.0), Vector3(face - 2.0, 134.0, end - 24.0)], 0.9, limits, Color("8c865c"), _threshold)
	_moss_patch(Vector3(area.get_center().x + 3.0, THRESHOLD_HEIGHT - 0.1, end - 58.0), Vector2(9.0, 18.0), limits.grow(-4.0), 4, 0.05, _threshold)
	_moss_patch(Vector3(area.get_center().x, 258.1, end + 47.0), Vector2(9.0, 10.0), limits.grow(-5.0), 7, 0.05, _threshold)


func _relief_band(area: Rect2, bottom: float, top: float, seed: int, east: bool, surface: SurfaceTool = null) -> void:
	if surface == null: surface = _stone
	# Shallow geometric carvings, not a new narrative/religious icon or pickup.
	var start := area.position.y if east else area.position.x
	var length := area.size.y if east else area.size.x
	var count := maxi(2, int(length / 29.0))
	var fixed := (area.end.x if east else area.end.y) + 0.24
	var shade := Color("627f73")
	for i in range(count):
		var center := start + (float(i) + 0.5) * length / count
		var half_width := minf(8.0, length / count * 0.29)
		var middle := (bottom + top) * 0.5
		var half_height := (top - bottom) * 0.39
		var points: Array[Vector3] = []
		for p in [Vector2(center - half_width, middle), Vector2(center, middle + half_height), Vector2(center + half_width, middle), Vector2(center, middle - half_height)]:
			points.append(Vector3(fixed, p.y, p.x) if east else Vector3(p.x, p.y, fixed))
		_quad(surface, points[0], points[1], points[2], points[3], shade.lightened(0.025 * ((i + seed) % 2)))
		var peak := Vector3(fixed + 0.7, middle, center) if east else Vector3(center, middle, fixed + 0.7)
		_triangle(surface, points[0], points[1], peak, Color("b4c1a4"))
		_triangle(surface, peak, points[1], points[2], Color("8ea28c"))


func _gallery_paving(area: Rect2, level: float, seed: int) -> void:
	var border := 13.0
	var stone := Color("bcc5a9")
	_paving_field(Rect2(area.position, Vector2(area.size.x, border)), level, stone.darkened(0.08), 92.0, border, seed + 2)
	_paving_field(Rect2(area.position.x, area.end.y - border, area.size.x, border), level, stone.darkened(0.08), 92.0, border, seed + 6)
	_paving_field(Rect2(area.position.x + 3.0, area.position.y + border + 2.0, area.size.x - 6.0, area.size.y - border * 2.0 - 4.0), level, stone, 98.0, 57.0, seed)


func _paving_field(area: Rect2, level: float, color: Color, span_x: float, span_z: float, seed: int) -> void:
	var rows := maxi(1, ceili(area.size.y / span_z))
	for row in range(rows):
		var z := area.position.y + row * area.size.y / rows
		var depth := area.size.y / rows
		var cursor := area.position.x
		var column := 0
		while cursor < area.end.x - 1.0:
			var width := minf(span_x * (0.56 if column == 0 and (row + seed) % 2 == 1 else 1.0), area.end.x - cursor)
			if width > 4.0:
				var slab := Rect2(cursor + 1.0, z + 1.0, width - 2.0, depth - 2.0)
				var tint := color.lightened(float((row * 3 + column + seed) % 4) * 0.018)
				_block(_paving, slab, level + 0.15, level + FLOOR_MAX_LIFT, tint, seed + row * 7 + column, 0.35)
			cursor += width
			column += 1


func _block(surface: SurfaceTool, area: Rect2, bottom: float, top: float, color: Color, seed: int, bevel: float) -> void:
	var corner := minf(minf(area.size.x, area.size.y) * 0.19, 7.5)
	var edge := minf(bevel, minf((top - bottom) * 0.3, minf(area.size.x, area.size.y) * 0.12))
	var rings := [
		_outline(area.grow(-edge * 0.35), corner * 0.8, seed),
		_outline(area, corner, seed),
		_outline(area, corner, seed),
		_outline(area.grow(-edge), corner * 0.7, seed),
	]
	var levels := [bottom, bottom + edge, top - edge, top]
	for ring in range(3):
		for i in range(8):
			var next := (i + 1) % 8
			var a: Vector2 = rings[ring][i]
			var b: Vector2 = rings[ring][next]
			var c: Vector2 = rings[ring + 1][next]
			var d: Vector2 = rings[ring + 1][i]
			var tone := color.darkened(0.11 if ring == 1 else 0.02)
			if i in [2, 3, 4]: tone = tone.darkened(0.06)
			_quad(surface, Vector3(a.x, levels[ring], a.y), Vector3(d.x, levels[ring + 1], d.y), Vector3(c.x, levels[ring + 1], c.y), Vector3(b.x, levels[ring], b.y), tone)
	var center := Vector3(area.get_center().x, top, area.get_center().y)
	for i in range(8):
		var a: Vector2 = rings[3][i]
		var b: Vector2 = rings[3][(i + 1) % 8]
		_triangle(surface, center, Vector3(b.x, top, b.y), Vector3(a.x, top, a.y), color.lightened(0.025 if i % 3 == seed % 3 else 0.0))
	if surface == _stone or surface == _threshold: _stone_blocks += 1
	else: _paving_slabs += 1


func _outline(area: Rect2, cut: float, seed: int) -> Array[Vector2]:
	# Unequal corner cuts produce chips without random runs or expanded footprints.
	var p := area.position
	var e := area.end
	var a := cut * (1.25 if seed % 4 == 0 else 0.72)
	var b := cut * (1.3 if seed % 4 == 1 else 0.86)
	var c := cut * (1.22 if seed % 4 == 2 else 0.74)
	var d := cut * (1.28 if seed % 4 == 3 else 0.9)
	return [Vector2(p.x + a, p.y), Vector2(e.x - b, p.y), Vector2(e.x, p.y + b), Vector2(e.x, e.y - c), Vector2(e.x - c, e.y), Vector2(p.x + d, e.y), Vector2(p.x, e.y - d), Vector2(p.x, p.y + a)]


func _reclaim_edges(area: Rect2, bottom: float, top: float, seed: int, surface: SurfaceTool = null) -> void:
	if surface == null: surface = _growth
	var height := top - bottom
	var margin := area.grow(-0.8)
	var pier := area.size.x > area.size.y
	var base_top := bottom + height * (0.14 if pier else 0.13) + 0.18
	var east := area.end.x - (7.5 if pier else 1.5)
	var north := area.position.y + area.size.y * (0.27 if seed % 2 == 0 else 0.67)
	var foot := Vector3(area.end.x - 1.5, base_top, north + 6.0)
	var root_path: Array[Vector3] = [
		Vector3(east, bottom + height * 0.73, north - 8.0),
		Vector3(east, bottom + height * 0.53, north - 4.0),
		Vector3(east + 0.8, bottom + height * 0.28, north + 2.0),
		foot, Vector3(area.end.x - (9.0 if pier else 1.6), base_top, north + 21.0),
	]
	_root(root_path, 1.8, margin, Color("827d59"), surface)
	_root([root_path[2], foot + Vector3(-7.0, 0.0, -4.0), foot + Vector3(-15.0, 0.0, -11.0)], 1.15, margin, Color("8f8962"), surface)
	# Growth occupies the broad base, below the top and inside the old barrier.
	var first := Vector3(area.end.x - (6.0 if pier else 1.6), base_top, north + 17.0)
	_moss_patch(first, Vector2(7.0 if pier else 0.65, 15.0), margin, seed, 0.45, surface)
	_leaf_group(first, margin, seed, 1.0 if pier else 0.14, surface)
	if pier:
		var second := Vector3(area.position.x + 13.0, base_top, area.end.y - 6.0)
		_moss_patch(second, Vector2(12.0, 6.0), margin, seed + 5, 0.45, surface)
		_leaf_group(second, margin, seed + 7, 1.0, surface)


func _root(points: Array[Vector3], radius: float, area: Rect2, color: Color, surface: SurfaceTool = null) -> void:
	if surface == null: surface = _growth
	for segment in range(points.size() - 1):
		var a := points[segment]
		var b := points[segment + 1]
		var tangent := (b - a).normalized()
		var side := tangent.cross(Vector3.UP).normalized()
		if side.length_squared() < 0.1: side = Vector3.RIGHT
		var other := tangent.cross(side).normalized()
		var start_radius := radius * (1.0 - float(segment) / points.size() * 0.6)
		var end_radius := start_radius * 0.8
		for i in range(5):
			var angle := float(i) * TAU / 5.0
			var next := float(i + 1) * TAU / 5.0
			var u := side * cos(angle) + other * sin(angle)
			var v := side * cos(next) + other * sin(next)
			_quad(surface, _inside(a + u * start_radius, area), _inside(b + u * end_radius, area), _inside(b + v * end_radius, area), _inside(a + v * start_radius, area), color.lightened(0.06 if i == 1 else 0.0))
	_root_strands += 1


func _moss_patch(center: Vector3, radius: Vector2, area: Rect2, seed: int, lift: float = 0.45, surface: SurfaceTool = null) -> void:
	if surface == null: surface = _growth
	for i in range(7):
		var angle := float(i) * TAU / 7.0
		var next := float(i + 1) * TAU / 7.0
		var extent := 0.72 if (i + seed) % 3 == 0 else 1.0
		var a := center + Vector3(cos(angle) * radius.x * extent, 0.0, sin(angle) * radius.y * extent)
		var b := center + Vector3(cos(next) * radius.x, 0.0, sin(next) * radius.y)
		_triangle(surface, _inside(center + Vector3.UP * lift, area), _inside(b, area), _inside(a, area), Color("738958").lightened(0.05 * (i % 2)))
	_moss_patches += 1


func _leaf_group(center: Vector3, area: Rect2, seed: int, x_spread: float = 1.0, surface: SurfaceTool = null) -> void:
	if surface == null: surface = _growth
	for leaf in range(5):
		var angle := float(leaf) * 1.15 + seed * 0.61
		var along := Vector3(cos(angle) * x_spread, 0.0, sin(angle))
		var side := Vector3(-sin(angle) * x_spread, 0.0, cos(angle))
		var length := 8.0 + float((seed + leaf) % 3) * 2.2
		var base := _inside(center, area)
		var left := _inside(center + along * length * 0.48 + side * 2.7 + Vector3.UP * 3.0, area)
		var right := _inside(center + along * length * 0.48 - side * 2.7 + Vector3.UP * 3.0, area)
		var ridge := _inside(center + along * length * 0.55 + Vector3.UP * 5.7, area)
		var tip := _inside(center + along * length + Vector3.UP * (4.0 + leaf % 2 * 2.0), area)
		_triangle(surface, base, ridge, left, Color("789757"))
		_triangle(surface, base, right, ridge, Color("507950"))
		_triangle(surface, left, ridge, tip, Color("91a761"))
		_triangle(surface, ridge, right, tip, Color("608a53"))
	_leaf_groups += 1


func _inside(point: Vector3, area: Rect2) -> Vector3:
	return Vector3(clampf(point.x, area.position.x, area.end.x), point.y, clampf(point.z, area.position.y, area.end.y))


func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_triangle(surface, a, b, c, color)
	_triangle(surface, a, c, d, color)


func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if normal.length_squared() < 0.1: return
	for point in [a, b, c]:
		surface.set_normal(normal)
		surface.set_color(color)
		surface.add_vertex(point * Terrain.SCALE)
	var batch := 0 if surface == _stone else (1 if surface == _paving else (2 if surface == _growth else 3))
	_vertex_counts[batch] += 3


func _finish_batch(root: Node3D, surface: SurfaceTool, label: String, index: int, shadows: bool) -> MeshInstance3D:
	if _vertex_counts[index] == 0: return null
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(instance)
	return instance
