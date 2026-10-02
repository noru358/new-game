extends "res://game/jungle_route_terrain.gd"
## Extend the existing jungle, preserving its ridge, two gate routes and hidden field.
const SOUTH_DESCENT := Rect2(2840, 2250, 340, 400)
const LANDING := Rect2(3320, 2520, 420, 260)
const TRANSIT_COURT := Rect2(1760, 2690, 620, 500)
const SOUTH_GROVES := [Vector2(1380, 2340), Vector2(1480, 2600), Vector2(1630, 3120)]
const SOUTH_ROUTE := [Vector2(3010, 2130), Vector2(3010, 2440), Vector2(3010, 2650), Vector2(3340, 2600), Vector2(2390, 2600), Vector2(2080, 2910), Vector2(1310, 2470), Vector2(1250, 2050)]
const RIDGE_RETURN := [Vector2(2080, 2910), Vector2(2175, 2400), Vector2(2175, 2120), Vector2(2175, 1800)]
func _init() -> void:
	super._init()
	map_size.y = 3600
	plateaus[2].openings["south"] = [[2840.0, 3180.0]]
	ramps.append({"area": SOUTH_DESCENT, "axis": 1, "from": 80.0, "to": 0.0, "base": 0.0, "name": "남쪽 강가 내리막", "kind": "south_bank_descent"})
	water_areas.erase(LOW_RIVER)
	water_areas.append(Rect2(2690, 2260, 150, 140))
	water_areas.append(Rect2(3180, 2260, 940, 140))
	for basin in [Rect2(2480, 2740, 1000, 640), Rect2(3480, 2400, 620, 940), Rect2(0, 2400, 1050, 1200), Rect2(4300, 2400, 1300, 1200), Rect2(1050, 3380, 3250, 220)]:
		_rounded_water(basin)
	_carve_water(Rect2(3180, 2520, 560, 260))
	plateaus.append({"area": LANDING, "height": 40.0, "base": 0.0, "name": "버려진 강가 나루", "openings": {"west": [[2520.0, 2780.0]]}})
	ramps.append({"area": Rect2(3180, 2520, 140, 260), "axis": 0, "from": 0.0, "to": 40.0, "base": 0.0, "name": "나루 진입 경사"})
	floor_areas.append({"area": LANDING, "height": 40.5, "color": Color("8b8f70")})
	floor_areas.append({"area": Rect2(1130, 2360, 1300, 950), "height": 0.6, "color": Color("607866")})
	floor_areas.append({"area": TRANSIT_COURT, "height": 0.35, "color": Color("9da487")})
	floor_areas.append({"area": Rect2(3200, 2460, 250, 230), "height": 0.7, "color": Color("a3ad90")})
	for area in [Rect2(1830, 2710, 110, 220), Rect2(2230, 2990, 100, 120)]:
		wall_areas.append({"area": area, "base": 0.0, "height": 120.0, "rise": 120.0, "color": Color("87967c"), "visual": false, "minimap_visible": true, "south_masonry": true})
	for point in SOUTH_GROVES:
		wall_areas.append({"area": Rect2(point - Vector2(85, 85), Vector2(170, 170)), "base": 0.0, "height": 240.0, "rise": 240.0, "color": Color("476651"), "visual": false, "minimap_visible": true, "south_grove": true})
	# Extend the existing hidden-field separator; the larger main field must not bypass it.
	wall_areas.append({"area": Rect2(5600, 3000, 400, 600), "base": 0.0, "height": 200.0, "rise": 200.0, "visual": false})

func _rounded_water(area: Rect2) -> void:
	var radius: float = minf(150.0, minf(area.size.x, area.size.y) * 0.28)
	var y: float = area.position.y
	while y < area.end.y:
		var depth: float = minf(40.0, area.end.y - y)
		var edge: float = minf(y + depth * 0.5 - area.position.y, area.end.y - y - depth * 0.5)
		var inset: float = radius - sqrt(maxf(0.0, radius * radius - pow(maxf(0.0, radius - edge), 2.0))) if edge < radius else 0.0
		water_areas.append(Rect2(area.position.x + inset, y, area.size.x - inset * 2, depth))
		y += depth

func surface_name(point: Vector2) -> String:
	if point.x < 5600 and point.y > 2250:
		if LANDING.grow(100).has_point(point): return "버려진 강가 나루"
		if SOUTH_DESCENT.has_point(point): return "남쪽 강가 내리막"
		if TRANSIT_COURT.grow(140).has_point(point): return "무너진 강변 통행 거점"
		if point.x > 2800: return "열린 강가 조망터"
		return "강가 뿌리 굽이"
	return super.surface_name(point)

func _carve_water(dry: Rect2) -> void:
	var original: Array = water_areas.duplicate()
	water_areas.clear()
	for water in original:
		if not water.intersects(dry):
			water_areas.append(water)
			continue
		var cut: Rect2 = water.intersection(dry)
		for piece in [Rect2(water.position, Vector2(water.size.x, cut.position.y - water.position.y)), Rect2(Vector2(water.position.x, cut.end.y), Vector2(water.size.x, water.end.y - cut.end.y)), Rect2(Vector2(water.position.x, cut.position.y), Vector2(cut.position.x - water.position.x, cut.size.y)), Rect2(Vector2(cut.end.x, cut.position.y), Vector2(water.end.x - cut.end.x, cut.size.y))]:
			if piece.size.x > 0 and piece.size.y > 0: water_areas.append(piece)
