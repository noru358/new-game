extends RefCounted

const MAIN_BOUNDS := Rect2(0, 0, 5600, 2400)
const FIELD_BOUNDS := Rect2(6000, 80, 4200, 2800)
const ENTRY_TRIGGER := Rect2(1250, 630, 100, 110)
const RETURN_POINT := Vector2(1150, 700)
const FIELD_ENTRY := Vector2(6290, 2630)
const EXIT_TRIGGER := Rect2(6100, 2510, 160, 220)
const ALTAR := Vector2(9860, 440)
const FIRST_WAVE := [Vector2(7410, 2330), Vector2(7960, 2190), Vector2(8040, 1890)]
const SECOND_WAVE := [Vector2(8850, 1460), Vector2(9270, 1100), Vector2(9660, 980)]
const FIRST_WAVE_AREA := Rect2(7080, 1730, 1230, 1010)
const SECOND_WAVE_AREA := Rect2(8500, 810, 1500, 1200)
const FIRST_APPROACH := Vector2(7470, 2280)
const SECOND_APPROACH := Vector2(9190, 1320)
# Fixed authored paths: stream spine, two ravines, western return passage.
# Grid strips below only build their shared visual and collision geometry.
const PATHS := [
	{"width": 170.0, "points": [Vector2(6190, 2630), Vector2(7020, 2630), Vector2(7480, 2220)]},
	{"width": 210.0, "points": [Vector2(7480, 2220), Vector2(8080, 2150), Vector2(8190, 1530), Vector2(8840, 1490), Vector2(9280, 970), Vector2(9740, 970), ALTAR]},
	{"width": 155.0, "points": [Vector2(7480, 2220), Vector2(7270, 1810), Vector2(7490, 1430), Vector2(8190, 1530)]},
	{"width": 155.0, "points": [Vector2(8840, 1490), Vector2(9260, 1960), Vector2(9680, 1670), Vector2(9740, 970)]},
	{"width": 140.0, "points": [ALTAR, Vector2(8950, 440), Vector2(8530, 740), Vector2(7630, 740), Vector2(6790, 1100), Vector2(6500, 1920), FIELD_ENTRY]},
]
const CLEARINGS := [Rect2(7300, 2060, 880, 440), Rect2(8920, 1640, 550, 450), Rect2(9520, 220, 530, 430)]
const POOLS := [Rect2(7450, 1650, 430, 380), Rect2(8970, 1090, 390, 370), Rect2(8280, 930, 570, 350)]
const LANDMARKS := [Vector2(7480, 2220), Vector2(7490, 1430), Vector2(9260, 1960), Vector2(8530, 740), ALTAR]


static func _walkable(point: Vector2) -> bool:
	for area in CLEARINGS:
		if area.has_point(point): return true
	for route in PATHS:
		for i in range(route.points.size() - 1):
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point, route.points[i], route.points[i + 1])) <= route.width: return true
	return false


static func _kind(point: Vector2) -> int:
	if _walkable(point): return 0
	for area in POOLS:
		if area.has_point(point): return 1
	# The camera looks from the southeast. Tall near-side walls hide actors
	# walking just behind them, so keep only those edges at curb height.
	if _walkable(point - Vector2(140.0, 0.0)) or _walkable(point - Vector2(0.0, 140.0)): return 3
	return 2


static func install(terrain) -> void:
	terrain.map_size = Vector2(10300, 3000)
	for rect in [Rect2(1240, 590, 150, 30), Rect2(1350, 430, 100, 390), Rect2(1240, 760, 150, 40), Rect2(1110, 440, 230, 110)]:
		terrain.wall_areas.append({"area": rect, "base": 0.0, "height": 185.0, "color": Color("41695b"), "discovery_id": "JUNGLE_GROTTO"})
	terrain.floor_areas.append({"area": FIELD_BOUNDS, "color": Color("4b7665"), "discovery_id": "JUNGLE_GROTTO"})
	# Merged strips keep walls, water, collision and minimap in the same records.
	const CELL := 140.0
	for row in 20:
		var start := 0
		while start < 30:
			var kind := _kind(FIELD_BOUNDS.position + Vector2(start + 0.5, row + 0.5) * CELL)
			var end := start + 1
			while end < 30 and _kind(FIELD_BOUNDS.position + Vector2(end + 0.5, row + 0.5) * CELL) == kind: end += 1
			var rect := Rect2(FIELD_BOUNDS.position + Vector2(start, row) * CELL, Vector2(end - start, 1) * CELL)
			if kind == 0:
				terrain.floor_areas.append({"area": rect, "height": 1.2, "color": Color("9aa88a") if row > 10 else Color("879c80"), "discovery_id": "JUNGLE_GROTTO"})
			elif kind == 1:
				terrain.water_areas.append(rect)
			else:
				terrain.wall_areas.append({"area": rect, "base": 0.0, "height": 45.0 if kind == 3 else 155.0, "color": Color("527e6d") if kind == 3 else Color("416657"), "discovery_id": "JUNGLE_GROTTO", "foreground_edge": kind == 3})
			start = end
	for rect in [Rect2(6000, 80, 4200, 40), Rect2(6000, 2840, 4200, 40), Rect2(6000, 80, 40, 2800), Rect2(10160, 80, 40, 2800)]:
		terrain.wall_areas.append({"area": rect, "base": 0.0, "height": 175.0, "color": Color("375a50"), "discovery_id": "JUNGLE_GROTTO"})
	terrain.wall_areas.append({"area": Rect2(5600, 0, 400, 3000), "base": 0.0, "height": 200.0, "visual": false})


static func surface_name(point: Vector2) -> String:
	if point.distance_to(ALTAR) < 620.0: return "계곡 안쪽 유적"
	if point.y < 950.0 or point.x < 6820.0 and point.y < 2200.0: return "이끼 낀 바위틈"
	if point.x > 8660.0: return "갈라진 협곡"
	if point.y < 2470.0 and point.x > 7110.0: return "물웅덩이 갈림길"
	return "폭포 뒤 좁은 물길"
