extends RefCounted
## Southeast Asia -> reclaimed temple -> landing / court / cloister / water walk.
## These are traces of use, inside existing barriers or beneath feet. No new
## collision, terrain height, camera, gameplay, interaction or progression.
const Kit = preload("res://game/temple_environment_kit.gd")
const LANDING := Rect2(560, 2380, 220, 150)
const WATER_GROWTH := [Rect2(3000, 1630, 115, 210), Rect2(3190, 1940, 120, 225), Rect2(3700, 1210, 135, 300), Rect2(3700, 2370, 155, 360)]
const GALLERY_WEST := Rect2(950, 1030, 130, 550)
const GALLERY_HALL := Rect2(1730, 1190, 420, 500)
const MERGE_WALL := Rect2(2510, 1340, 410, 190)
const FLOOR_LIFT := 0.72

static func build(arena: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "TemplePlaceComposition"
	var builder = Kit.new()
	for surface in [builder._stone, builder._paving, builder._growth]: surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_landing(builder)
	_ground_courses(builder, arena)
	for index in WATER_GROWTH.size(): _bank_growth(builder, WATER_GROWTH[index], index + 3)
	builder._finish_batch(root, builder._stone, "WaterLandingRemains", 0, false)
	builder._finish_batch(root, builder._paving, "ProcessionalAndCloisterCourses", 1, false)
	builder._finish_batch(root, builder._growth, "BankAndLandingGrowth", 2, false)
	root.set_meta("visual_only", true)
	root.set_meta("region_hierarchy", ["동남아", "폐사원", "수변 진입→중정→회랑/물가→성소"])
	root.set_meta("solid_bounds", [LANDING] + WATER_GROWTH)
	root.set_meta("maximum_solid_height", 9.0)
	root.set_meta("maximum_walkable_lift", FLOOR_LIFT)
	return root

static func masonry(builder, area: Rect2, top: float, seed: int) -> void:
	# Continuous low foundations keep the full old blocked footprint visibly solid.
	# Columns, collapsed bays and wall ends never exceed the previous envelope.
	if area != GALLERY_WEST and area != GALLERY_HALL and area != MERGE_WALL:
		builder._gallery_fragment(area, 0.0, top, seed)
		builder._reclaim_edges(area, 0.0, top, seed)
		return
	var stone := Color("9da58c") if area == GALLERY_WEST else Color("b0aa8b")
	var foundation := top * 0.39
	builder._gallery_fragment(area, 0.0, foundation, seed)
	var axis := 1 if area == GALLERY_WEST else 0
	var bays := 4 if area == GALLERY_HALL else 3
	var span := area.size[axis] / float(bays)
	for bay in bays:
		var base := area.grow(-3.0)
		base.position[axis] = area.position[axis] + float(bay) * span + 5.0
		base.size[axis] = span - 10.0
		var level := top * (0.63 if bay == 1 else 0.72)
		builder._gallery_fragment(base, foundation + 0.3, level, seed + bay + 8)
		var column := base.grow(-4.0)
		column.size[axis] = minf(34.0, span * 0.28)
		# Short square pier sections, not beams extruded across the whole hall.
		column.size[1 - axis] = minf(38.0, column.size[1 - axis])
		if area == GALLERY_WEST: column.position.x = base.end.x - column.size.x - 4.0
		if bay % 2: column.position[axis] = base.end[axis] - column.size[axis] - 4.0
		builder._block(builder._stone, column, level + 0.3, top - 6.0, stone.lightened(0.07), seed + bay + 20, 2.0)
		builder._block(builder._stone, column.grow(2.0), top - 5.7, top - 0.2, stone.lightened(0.16), seed + bay + 31, 1.3)
		builder._reclaim_edges(base, foundation, level, seed + bay + 2)
	# A broad incised band identifies masonry along the walked side of the hall.
	builder._relief_band(area.grow(-3.0), foundation * 0.45, foundation * 0.83, seed, area == GALLERY_WEST)

static func _landing(builder) -> void:
	# Abandoned washing/landing stones, entirely in the existing west water basin.
	var stone := Color("9da690")
	for step in 3:
		var area := Rect2(570 + step * 19, 2496 - step * 27, 200 - step * 19, 29)
		builder._block(builder._stone, area, 1.05, 3.0 + step * 2.2, stone.lightened(step * 0.03), step + 40, 1.0)
	var basin := Rect2(588, 2396, 123, 76)
	for rim in [Rect2(588, 2396, 123, 15), Rect2(588, 2411, 16, 61), Rect2(695, 2411, 16, 61), Rect2(604, 2457, 91, 15)]:
		builder._block(builder._stone, rim, 1.05, 9.0, stone.darkened(0.06), 49, 1.0)
	var inside := basin.grow(-17.0)
	_flat(builder, builder._stone, inside, 1.12, Color("3f7370"))
	_bank_growth(builder, Rect2(727, 2390, 47, 65), 2)

static func _ground_courses(builder, arena: Node3D) -> void:
	# Large quiet slabs indicate the former walking system; no repeated pickups.
	# Different widths reflect an open gathering court and a paced side gallery.
	var fields := [
		[Rect2(530, 2758, 880, 142), 214.0, 142.0, Color("b8b399")],
		[Rect2(1310, 2440, 120, 410), 120.0, 152.0, Color("a8ab90")],
		[Rect2(1340, 2150, 130, 315), 130.0, 138.0, Color("a8ab90")],
		[Rect2(1910, 2204, 900, 140), 231.0, 140.0, Color("c8c09f")],
		[Rect2(2230, 1620, 216, 580), 216.0, 207.0, Color("c8c09f")],
		[Rect2(1190, 924, 410, 1320), 202.0, 145.0, Color("aeb39a")],
		[Rect2(1600, 905, 577, 150), 188.0, 150.0, Color("b7b699")],
		[Rect2(2215, 780, 760, 193), 248.0, 193.0, Color("ccc2a0")],
		[Rect2(2732, 300, 136, 485), 136.0, 168.0, Color("cfc3a1")],
		[Rect2(3220, 1110, 305, 140), 154.0, 140.0, Color("a5b39d")],
		[Rect2(3435, 1252, 105, 977), 105.0, 263.0, Color("9da994")],
		[Rect2(3280, 2218, 260, 125), 163.0, 125.0, Color("a5b39d")],
	]
	var barriers: Array[Rect2] = arena.terrain.barriers()
	var covered: Array[Rect2] = []
	for index in fields.size():
		var spec: Array = fields[index]
		var bounds: Rect2 = spec[0]
		var rows := ceili(bounds.size.y / spec[2])
		var columns := ceili(bounds.size.x / spec[1])
		for row in rows:
			for column in columns:
				var size := bounds.size / Vector2(columns, rows)
				var area := Rect2(bounds.position + Vector2(column, row) * size + Vector2.ONE * 2.0, size - Vector2.ONE * 4.0)
				# Never imply paving through a barrier or over a disconnected cliff.
				var usable := true
				for point in [area.position, area.end, area.get_center()]:
					for barrier in barriers:
						if barrier.has_point(point): usable = false
				if not usable: continue
				var tint: Color = spec[3].lightened(0.012 * ((column + row + index) % 3))
				# Meeting courses share one surface; coincident tinted quads flicker.
				for piece in arena.terrain.surface_areas({"area":area,"cutouts":covered}):
					var points := [piece.position, Vector2(piece.end.x, piece.position.y), piece.end, Vector2(piece.position.x, piece.end.y)]
					var vertices: Array[Vector3] = []
					for point in points: vertices.append(Vector3(point.x, arena.terrain.height_at(point) + FLOOR_LIFT, point.y))
					builder._quad(builder._paving, vertices[0], vertices[3], vertices[2], vertices[1], tint)
					covered.append(piece)

static func _flat(builder, surface: SurfaceTool, area: Rect2, level: float, tint: Color) -> void:
	builder._quad(surface, Vector3(area.position.x, level, area.position.y), Vector3(area.position.x, level, area.end.y), Vector3(area.end.x, level, area.end.y), Vector3(area.end.x, level, area.position.y), tint)

static func _bank_growth(builder, area: Rect2, seed: int) -> void:
	# Broad overlapping water leaves read as one bank colony at the game camera.
	# The colony's entire volume is contained by an existing impassable water area.
	for clump in 5:
		var center := area.position + area.size * Vector2(0.25 + 0.5 * float(clump % 2), (float(clump) + 0.5) / 5.0)
		for leaf in 4:
			var angle := float(leaf) * TAU / 4.0 + seed * 0.71 + clump * 0.3
			var along := Vector2.from_angle(angle) * (22.0 + 5.0 * (clump % 3))
			var side := along.orthogonal() * 0.28
			var a: Vector3 = builder._inside(Vector3(center.x, 2.1, center.y), area)
			var tip: Vector3 = builder._inside(Vector3(center.x + along.x, 6.0, center.y + along.y), area)
			var left: Vector3 = builder._inside(Vector3(center.x + along.x * 0.55 + side.x, 5.0, center.y + along.y * 0.55 + side.y), area)
			var right: Vector3 = builder._inside(Vector3(center.x + along.x * 0.55 - side.x, 5.0, center.y + along.y * 0.55 - side.y), area)
			var ridge: Vector3 = builder._inside(Vector3(center.x + along.x * 0.48, 9.0, center.y + along.y * 0.48), area)
			builder._triangle(builder._growth, a, ridge, left, Color("567953"))
			builder._triangle(builder._growth, a, right, ridge, Color("365e48"))
			builder._triangle(builder._growth, left, ridge, tip, Color("77905d"))
			builder._triangle(builder._growth, ridge, right, tip, Color("466f4d"))
