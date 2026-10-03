extends "res://game/jungle_pass_terrain.gd"
## Southeast Asia -> existing jungle pass -> ridge / riverbank / gate ascent.
## Uses the existing single-height terrain and original map bounds/route triggers.

const OLD_PARAPET := Rect2(3420, 1550, 110, 190)
const RIVER_REMNANT := Rect2(3150, 1810, 110, 190)
const LOW_RIVER := Rect2(2690, 2260, 1430, 140)
const FOREGROUND_TREE := Vector2(3470, 2200)
const BACKGROUND_TREE := Vector2(3470, 1575)
const WATER_LANDING := Rect2(2930, 2010, 245, 190)
const GATE_SIGHT_FLOOR := Rect2(4100, 1830, 240, 270)
const RIVER_ROOT_POINTS := [Vector2(2775, 2140), Vector2(3250, 1640), Vector2(4160, 2180)]
# Same ten original edge stones, grouped beside the route rather than spaced
# uniformly along both ramp edges. Nothing new enters the collision budget.
const ROCK_EDGE_POINTS := [
	Vector2(3250, 1580), Vector2(3325, 1590), Vector2(3390, 1620), Vector2(3500, 1600), Vector2(3550, 1580),
	Vector2(3940, 2220), Vector2(4050, 2230), Vector2(4140, 2240), Vector2(4240, 2220), Vector2(4330, 2230),
]
const PLACES := [
	{"id": "water_landing", "area": WATER_LANDING, "point": Vector2(3080, 2160)},
	{"id": "north_remnant", "area": Rect2(3130, 1560, 450, 460), "point": Vector2(3240, 1740)},
	{"id": "gate_sight", "area": Rect2(3920, 1770, 440, 480), "point": Vector2(4180, 1770)},
]
var route_canopy_points: Array = CANOPY_POINTS.duplicate()
var route_reed_points: Array[Vector2] = []

func _init() -> void:
	super._init()
	for wall in wall_areas:
		if wall.area != OLD_PARAPET: continue
		wall.area = RIVER_REMNANT
		wall.base = height_at(RIVER_REMNANT.get_center())
		wall.height = wall.base + float(wall.rise)
		wall.visual = false # Worked stone below draws this exact blocked footprint.
	# Same trunk/opaque crown and X-ramp height; place it behind the walked route.
	# Visual and collision positions move together, rather than hiding the asset.
	route_canopy_points[route_canopy_points.find(FOREGROUND_TREE)] = BACKGROUND_TREE
	for wall in wall_areas:
		if wall.area != Rect2(FOREGROUND_TREE - Vector2.ONE * 23.0, Vector2.ONE * 46.0): continue
		wall.area = Rect2(BACKGROUND_TREE - Vector2.ONE * 23.0, Vector2.ONE * 46.0)
		wall.base = height_at(BACKGROUND_TREE)
		wall.height = wall.base + float(wall.rise)
	water_areas.append(LOW_RIVER)
	# Keep 24 reeds, leaving open water-facing standing space in the middle.
	for i in 12:
		route_reed_points.append(Vector2(2780 + (i % 6) * 22, 2160 + (i / 6) * 40))
	for i in 6:
		route_reed_points.append(Vector2(3175 + (i % 3) * 22, 2150 + (i / 3) * 42))
	for i in 6:
		route_reed_points.append(Vector2(3940 + i * 34, 2180 + (i % 2) * 28))
