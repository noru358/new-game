class_name DeepWetlandTerrain
extends "res://game/hybrid_terrain.gd"
## First-region representative route; not a progression region yet.
const ENTRY := Vector2(520, 2550)
const PROCESSION := Vector2(1350, 2140)
const FACE_BANK := Vector2(2350, 1510)
const TEMPLE_COURT := Vector2(3260, 830)
const DETOUR := Vector2(1600, 980)
const FACE := Vector2(2570, 960)
const WAYPOINTS := [ENTRY, Vector2(880, 2480), PROCESSION, Vector2(1700, 2050), FACE_BANK, Vector2(2840, 1530), Vector2(3180, 1280), TEMPLE_COURT]
const SIDE_ROUTE := [PROCESSION, Vector2(1030, 1790), Vector2(1050, 980), DETOUR, Vector2(2070, 1100), FACE_BANK]

func _init() -> void:
	map_size = Vector2(4000, 3000)
	plateaus = []
	ramps = []
	water_areas = [
		Rect2(80, 80, 640, 2090), Rect2(720, 80, 2100, 510),
		Rect2(1350, 1290, 550, 520), Rect2(1500, 1190, 350, 100),
		Rect2(2100, 650, 680, 620),
		# The colossal face belongs to a connected sacred pool, not a walk-behind plinth.
		Rect2(1350, 500, 1430, 430), Rect2(2450, 1760, 1450, 1150),
		Rect2(1900, 2310, 550, 600), Rect2(750, 2740, 1150, 170),
		Rect2(3450, 80, 460, 1330), Rect2(2780, 80, 670, 420)
	]
	# Rounded bank contours are built from the SAME water records used by navigation.
	# Narrow strips approximate erosion without a decorative floor/collision mismatch.
	var basins: Array = water_areas.duplicate()
	water_areas.clear()
	for basin in basins:
		var radius: float = minf(100.0, minf(basin.size.x, basin.size.y) * 0.28)
		var z: float = basin.position.y
		while z < basin.end.y:
			var depth: float = minf(40.0, basin.end.y - z)
			var edge: float = minf(z + depth * 0.5 - basin.position.y, basin.end.y - z - depth * 0.5)
			var inset: float = radius - sqrt(maxf(0.0, radius * radius - pow(maxf(0.0, radius - edge), 2.0))) if edge < radius else 0.0
			water_areas.append(Rect2(basin.position.x + inset, z, basin.size.x - inset * 2.0, depth))
			z += depth
	floor_areas = [
		{"area": Rect2(2860, 540, 530, 670), "color": Color("b0ad8a"), "height": 0.5},
	]
	wall_areas = []
	for p in [Vector2(1080, 1980), Vector2(1810, 1970), Vector2(2940, 610), Vector2(3340, 570)]:
		wall_areas.append({"area": Rect2(p - Vector2(75, 75), Vector2(150, 150)), "height": 240.0, "visual": false})
	# Landmark collision lies inside already impassable water, never over a path.
	wall_areas.append({"area": Rect2(FACE - Vector2(115, 100), Vector2(230, 200)), "height": 320.0, "visual": false})

func height_at(_point: Vector2) -> float:
	return 0.0

func surface_name(point: Vector2) -> String:
	if point.distance_to(TEMPLE_COURT) < 550: return "무너진 사원뜰"
	if point.distance_to(FACE_BANK) < 650: return "얼굴 유적 수변"
	if point.y < 1450: return "바깥 뿌리길"
	if point.x > 950: return "잠긴 참배길"
	return "뿌리 입구"
