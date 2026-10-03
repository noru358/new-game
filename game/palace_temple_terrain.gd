extends "res://game/hybrid_terrain.gd"
## Southeast Asia -> maintained palace temple -> procession / court / cloister.
const ENTRY := Vector2(180, 2200)
const REVEAL := Vector2(1300, 1600)
const GATE := Vector2(1500, 1800)
const COURT_CENTER := Vector2(2300, 2600)
const CLOISTER := Vector2(3550, 1940)
const WAYPOINTS := [ENTRY, Vector2(650, 2100), REVEAL, GATE, COURT_CENTER, Vector2(3550, 2850), CLOISTER, Vector2(4100, 1940)]
const GATE_ANGLE := -3.0 * PI / 4.0
const GATE_LOCAL := Vector2(960, 1555)
const GUARDIAN_LOCAL := [Vector2(700, 1180), Vector2(700, 1930)]

static func gate_point(local: Vector2) -> Vector2:
	return GATE + (local-GATE_LOCAL).rotated(GATE_ANGLE)

func _init() -> void:
	map_size = Vector2(4400, 3600)
	plateaus = []
	ramps = []
	water_areas = []
	chasm_areas.clear()
	floor_areas = [
		{"area": Rect2(110, 1960, 630, 440), "height": 0.5, "color": Color("cbbd94")},
		{"area": Rect2(650, 1430, 620, 760), "height": 0.5, "color": Color("cbbd94")},
		{"area": Rect2(1100, 1400, 820, 780), "height": 0.5, "color": Color("d5c9a4")},
		{"area": Rect2(1550, 1900, 2450, 1420), "height": 0.5, "color": Color("e6dcc1")},
		{"area": Rect2(2300, 1710, 1780, 330), "height": 0.5, "color": Color("9caa9b")},
	]
	# Later place floors own overlaps, keeping the union without coplanar faces.
	for index in floor_areas.size():
		var cuts: Array = []
		for later in range(index+1,floor_areas.size()): cuts.append(floor_areas[later].area)
		floor_areas[index]["cutouts"] = cuts
	wall_areas = [
		{"area": Rect2(2260, 1470, 1850, 120), "height": 225.0},
		{"area": Rect2(4050, 1150, 290, 530), "height": 580.0},
	]
	# Unrotated local dimensions with rotated centers/angles feed the existing
	# TempleBlock and ArenaNavigation contracts, rather than inflated AABB walls.
	for z in [1180.0,1930.0]:
		var center := gate_point(Vector2(960,z))
		wall_areas.append({"area": Rect2(center-Vector2(75,120),Vector2(150,240)), "height": 410.0, "angle": GATE_ANGLE})
	for local in GUARDIAN_LOCAL:
		var center := gate_point(local)
		wall_areas.append({"area": Rect2(center-Vector2(90,90),Vector2(180,180)), "height": 555.0, "angle": -PI/4.0})
	for x in [2340,2700,3060,3420,3780,4080]:
		wall_areas.append({"area": Rect2(x,1740,52,52), "height":235.0})
	for wall in wall_areas: wall["visual"] = false

func height_at(_point: Vector2) -> float: return 0.0

func surface_name(point: Vector2) -> String:
	if point.x < 1050: return "외곽 행렬길"
	if point.x < 1920 and point.y < 2250: return "채색 수호상의 문"
	if point.y < 2050: return "그늘진 회랑"
	return "밝은 중정"
