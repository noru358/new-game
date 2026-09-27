class_name JunglePassTerrain
extends "res://game/hybrid_terrain.gd"


func _init() -> void:
	map_size = Vector2(5600, 2400)
	# The first approach is open. A high ridge offers a main western ramp,
	# a northern climb and a southern detour before the raised gate court.
	plateaus = [
		{"area": Rect2(1550, 400, 2050, 1600), "height": 240.0, "base": 0.0, "name": "정글 능선", "openings": {"west": [[900.0, 1450.0]], "north": [[2000.0, 2350.0]], "south": [[2700.0, 3050.0]], "east": [[900.0, 1450.0]]}},
		{"area": Rect2(3900, 500, 1350, 1400), "height": 480.0, "base": 0.0, "name": "관문 상단", "openings": {"west": [[900.0, 1450.0]]}},
	]
	ramps = [
		{"area": Rect2(1280, 900, 270, 550), "axis": 0, "from": 0.0, "to": 240.0, "name": "서쪽 상승로"},
		{"area": Rect2(2000, 130, 350, 270), "axis": 1, "from": 0.0, "to": 240.0, "name": "북쪽 덩굴길"},
		{"area": Rect2(2700, 2000, 350, 270), "axis": 1, "from": 240.0, "to": 0.0, "name": "남쪽 우회로"},
		{"area": Rect2(3600, 900, 300, 550), "axis": 0, "from": 240.0, "to": 480.0, "name": "관문 오름길"},
	]
	water_areas = []
	floor_areas = [
		{"area": Rect2(100, 370, 1260, 1670), "color": Color("6b8664")},
		{"area": Rect2(390, 780, 1160, 720), "height": 1.2, "color": Color("9b9b70")},
		{"area": Rect2(1640, 540, 1820, 1320), "height": 241.2, "color": Color("788b6d")},
		{"area": Rect2(1930, 910, 1660, 520), "height": 242.4, "color": Color("b3aa83")},
		{"area": Rect2(3920, 540, 1270, 1320), "height": 481.2, "color": Color("9f9b7f")},
		{"area": Rect2(4100, 800, 1030, 720), "height": 482.4, "color": Color("bcb08a")},
	]
	wall_areas = [
		{"area": Rect2(600, 500, 180, 250), "height": 165.0, "color": Color("3d6149")},
		{"area": Rect2(930, 1640, 190, 260), "height": 175.0, "color": Color("426b52")},
		{"area": Rect2(1850, 620, 230, 290), "height": 185.0, "color": Color("4c6752")},
		{"area": Rect2(3000, 1510, 290, 230), "height": 195.0, "color": Color("52644f")},
		{"area": Rect2(4380, 590, 210, 300), "height": 270.0, "color": Color("727a65")},
		{"area": Rect2(4380, 1510, 210, 300), "height": 270.0, "color": Color("727a65")},
		{"area": Rect2(4870, 940, 135, 520), "height": 340.0, "color": Color("6c7363")},
	]


func height_at(point: Vector2) -> float:
	for ramp in ramps:
		if ramp.area.has_point(point): return ramp_height(ramp, point)
	for i in range(plateaus.size() - 1, -1, -1):
		if plateaus[i].area.has_point(point): return plateaus[i].height
	return 0.0


func surface_name(point: Vector2) -> String:
	for ramp in ramps:
		if ramp.area.has_point(point): return ramp.name
	if plateaus[1].area.has_point(point): return "관문 상단"
	if plateaus[0].area.has_point(point): return "정글 능선"
	return "정글 진입로" if point.x < 1550.0 else "절벽 아랫길"
