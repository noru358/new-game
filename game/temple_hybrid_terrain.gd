class_name TempleHybridTerrain
extends "res://game/hybrid_terrain.gd"


func _init() -> void:
	map_size = Vector2(3840, 2160)
	plateaus = [
		{"area": Rect2(300, 780, 900, 760), "height": 160.0, "base": 0.0, "name": "수변 마당 중정", "openings": {"north": [[520.0, 760.0]], "south": [[520.0, 760.0], [860.0, 1010.0]], "east": [[1050.0, 1260.0]]}},
		{"area": Rect2(800, 970, 250, 310), "height": 320.0, "base": 160.0, "name": "사원 테라스", "openings": {"west": [[1030.0, 1210.0]]}}
	]
	ramps = [
		{"area": Rect2(520, 520, 240, 260), "axis": 1, "from": 0.0, "to": 160.0, "name": "북쪽 경사로"},
		{"area": Rect2(520, 1540, 240, 280), "axis": 1, "from": 160.0, "to": 0.0, "name": "남쪽 경사로"},
		{"area": Rect2(1200, 1050, 270, 210), "axis": 0, "from": 160.0, "to": 0.0, "name": "사원 뜰 연결로"},
		{"area": Rect2(620, 1030, 180, 180), "axis": 0, "from": 160.0, "to": 320.0, "name": "테라스 경사로"},
		{"area": Rect2(860, 1540, 150, 260), "axis": 1, "from": 160.0, "to": 0.0, "name": "디딤돌", "kind": "stepping_stones"}
	]
	water_areas = [
		Rect2(200, 1560, 290, 75), Rect2(240, 1635, 250, 90), Rect2(270, 1725, 210, 90),
		Rect2(1120, 1560, 230, 75), Rect2(1100, 1635, 250, 90), Rect2(1120, 1725, 210, 90),
		Rect2(2050, 300, 440, 130), Rect2(2100, 1700, 370, 120)
	]
	floor_areas = [
		{"area": Rect2(1530, 680, 900, 800), "color": Color("cbbf9e")},
		{"area": Rect2(1760, 790, 550, 170), "height": 1.2, "color": Color("ddd0ad")},
		{"area": Rect2(1760, 1240, 550, 170), "height": 1.2, "color": Color("ddd0ad")},
		{"area": Rect2(2460, 740, 480, 680), "color": Color("a9b8aa")},
		{"area": Rect2(2480, 790, 440, 190), "height": 1.2, "color": Color("c1c8ad")},
		{"area": Rect2(2480, 1160, 440, 210), "height": 1.2, "color": Color("c1c8ad")},
		{"area": Rect2(2960, 650, 740, 860), "color": Color("ddc9a8")},
		{"area": Rect2(3040, 750, 590, 170), "height": 1.2, "color": Color("e8dab5")},
		{"area": Rect2(3040, 1260, 590, 170), "height": 1.2, "color": Color("e8dab5")}
	]
	wall_areas = [
		{"area": Rect2(1620, 700, 260, 36), "height": 78.0, "color": Color("84988a")},
		{"area": Rect2(1650, 1420, 270, 36), "height": 78.0, "color": Color("84988a")},
		{"area": Rect2(1870, 1010, 290, 180), "height": 95.0, "color": Color("89958a")},
		{"area": Rect2(2510, 1030, 110, 70), "height": 90.0, "color": Color("718780")},
		{"area": Rect2(2800, 1030, 110, 70), "height": 90.0, "color": Color("718780")},
		{"area": Rect2(2970, 790, 36, 150), "height": 105.0, "color": Color("8d9b87")},
		{"area": Rect2(2970, 1220, 36, 150), "height": 105.0, "color": Color("8d9b87")},
		{"area": Rect2(3160, 950, 300, 280), "height": 130.0, "color": Color("a9a58d")}
	]


func height_at(point: Vector2) -> float:
	for ramp in ramps:
		if ramp.area.has_point(point):
			return ramp_height(ramp, point)
	for i in range(plateaus.size() - 1, -1, -1):
		if plateaus[i].area.has_point(point):
			return plateaus[i].height
	return 0.0


func surface_name(point: Vector2) -> String:
	for ramp in ramps:
		if ramp.area.has_point(point):
			return ramp.name
	if plateaus[1].area.has_point(point):
		return "사원 테라스"
	if point.x < 1450.0:
		return "수변 마당"
	if point.x < 2500.0:
		return "사원 뜰"
	if point.x < 2900.0:
		return "회랑"
	return "성소"
