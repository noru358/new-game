class_name TempleHybridTerrain
extends "res://game/hybrid_terrain.gd"


const Garden = preload("res://game/temple_garden_layout.gd")

func _init() -> void:
	map_size = Vector2(8700, 2160)
	plateaus = [
		{"area": Rect2(100, 780, 1100, 760), "height": 160.0, "base": 0.0, "name": "수변 마당 중정", "openings": {"north": [[520.0, 760.0]], "south": [[520.0, 760.0], [860.0, 1010.0]], "east": [[1050.0, 1260.0]]}},
		{"area": Rect2(850, 970, 250, 310), "height": 320.0, "base": 160.0, "name": "사원 테라스", "openings": {"west": [[1030.0, 1210.0]]}}
	]
	ramps = [
		{"area": Rect2(520, 280, 240, 500), "axis": 1, "from": 0.0, "to": 160.0, "name": "북쪽 경사로"},
		{"area": Rect2(520, 1540, 240, 280), "axis": 1, "from": 160.0, "to": 0.0, "name": "남쪽 경사로"},
		{"area": Rect2(1200, 1050, 270, 210), "axis": 0, "from": 160.0, "to": 0.0, "name": "사원 뜰 연결로"},
		{"area": Rect2(350, 1030, 500, 180), "axis": 0, "from": 160.0, "to": 320.0, "name": "테라스 경사로"},
		{"area": Rect2(860, 1540, 150, 260), "axis": 1, "from": 160.0, "to": 0.0, "name": "디딤돌", "kind": "stepping_stones"}
	]
	water_areas = [
		Rect2(200, 1560, 290, 75), Rect2(240, 1635, 250, 90), Rect2(270, 1725, 210, 90),
		Rect2(1120, 1560, 230, 75), Rect2(1100, 1635, 250, 90), Rect2(1120, 1725, 210, 90),
		Rect2(2300, 300, 440, 130), Rect2(2350, 1700, 370, 120)
	]
	floor_areas = [
		{"area": Rect2(1470, 1020, 230, 240), "color": Color("b7b29d")},
		{"area": Rect2(1700, 600, 1100, 960), "color": Color("cbbf9e")},
		{"area": Rect2(1950, 720, 690, 185), "height": 1.2, "color": Color("ddd0ad")},
		{"area": Rect2(1950, 1250, 690, 185), "height": 1.2, "color": Color("ddd0ad")},
		{"area": Rect2(2800, 970, 230, 310), "color": Color("9daea4")},
		{"area": Rect2(3030, 560, 750, 1000), "color": Color("a9b8aa")},
		{"area": Rect2(3060, 630, 690, 190), "height": 1.2, "color": Color("c1c8ad")},
		{"area": Rect2(3060, 1280, 690, 210), "height": 1.2, "color": Color("c1c8ad")},
		{"area": Rect2(3780, 960, 210, 320), "color": Color("c9bda0")},
		{"area": Rect2(3990, 540, 950, 1040), "color": Color("ddc9a8")},
		{"area": Rect2(4070, 650, 780, 180), "height": 1.2, "color": Color("e8dab5")},
		{"area": Rect2(4070, 1310, 780, 180), "height": 1.2, "color": Color("e8dab5")}
	]
	wall_areas = [
		{"area": Rect2(1810, 635, 310, 36), "height": 78.0, "color": Color("84988a")},
		{"area": Rect2(1840, 1480, 320, 36), "height": 78.0, "color": Color("84988a")},
		{"area": Rect2(2110, 1000, 310, 200), "height": 95.0, "color": Color("89958a")},
		{"area": Rect2(3120, 1010, 120, 80), "height": 90.0, "color": Color("718780")},
		{"area": Rect2(3540, 1010, 120, 80), "height": 90.0, "color": Color("718780")},
		{"area": Rect2(4020, 730, 36, 165), "height": 105.0, "color": Color("8d9b87")},
		{"area": Rect2(4020, 1270, 36, 165), "height": 105.0, "color": Color("8d9b87")},
		{"area": Rect2(4820, 970, 100, 180), "height": 130.0, "color": Color("a9a58d")}
	]

	# A modest vestibule hides the transition; the actual garden is a mini field.
	floor_areas.append({"area": Rect2(3030, 180, 210, 160), "height": 1.0, "color": Color("719c69"), "discovery_id": "TEMPLE_GARDEN"})
	for rect in [Rect2(3030, 155, 235, 25), Rect2(3240, 155, 25, 210), Rect2(3030, 340, 235, 25)]:
		wall_areas.append({"area": rect, "height": 145.0, "color": Color("52715e"), "discovery_id": "TEMPLE_GARDEN"})
	floor_areas.append({"area": Garden.FIELD_BOUNDS, "height": 0.8, "color": Color("71966e"), "discovery_id": "TEMPLE_GARDEN"})
	for rect in [Rect2(5740, 1680, 900, 210), Rect2(6200, 550, 220, 1190), Rect2(6370, 430, 1650, 220), Rect2(6390, 1450, 1650, 230), Rect2(7910, 510, 230, 1070), Rect2(8090, 310, 390, 350)]:
		floor_areas.append({"area": rect, "height": 1.2, "color": Color("b7bd98"), "discovery_id": "TEMPLE_GARDEN"})
	water_areas.append(Garden.POND)
	for rect in [Rect2(5600, 80, 3000, 45), Rect2(5600, 2035, 3000, 45), Rect2(5600, 80, 45, 2000), Rect2(8555, 80, 45, 2000), Rect2(5680, 900, 470, 650), Rect2(6450, 250, 120, 980), Rect2(6750, 1780, 860, 190), Rect2(7770, 140, 120, 620), Rect2(8220, 1700, 210, 170)]:
		var foreground: bool = rect.position.y >= 1700.0 or rect.position.x >= 8550.0 or rect.position.x == 6450.0 or rect.position.x == 8220.0
		wall_areas.append({"area": rect, "height": 45.0 if foreground else 115.0, "color": Color("668477") if foreground else Color("52715e"), "discovery_id": "TEMPLE_GARDEN"})
	# No walking/attacking path connects the two fields behind the transition.
	wall_areas.append({"area": Rect2(5090, 0, 510, 2160), "height": 200.0, "color": Color("607f78"), "visual": false})



func height_at(point: Vector2) -> float:
	for ramp in ramps:
		if ramp.area.has_point(point):
			return ramp_height(ramp, point)
	for i in range(plateaus.size() - 1, -1, -1):
		if plateaus[i].area.has_point(point):
			return plateaus[i].height
	return 0.0


func surface_name(point: Vector2) -> String:
	if Garden.FIELD_BOUNDS.has_point(point): return "숨은 정원"
	for ramp in ramps:
		if ramp.area.has_point(point):
			return ramp.name
	if plateaus[1].area.has_point(point):
		return "사원 테라스"
	if point.x < 1620.0:
		return "수변 마당"
	if point.x < 2900.0:
		return "사원 뜰"
	if point.x < 3880.0:
		return "회랑"
	return "성소"
