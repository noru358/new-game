class_name JunglePassTerrain
extends "res://game/hybrid_terrain.gd"

const GATE_COLUMN_TOP := 1010.0
const GATE_COLUMN_SIZE := Vector2(125.0, 120.0)
const GATE_COLUMN_CENTERS := [Vector2(4120, 1160), Vector2(5070, 1160)]
const CANOPY_POINTS := [
	Vector2(350, 470), Vector2(650, 360), Vector2(1090, 350),
	Vector2(350, 1880), Vector2(820, 2070), Vector2(1250, 1790),
	Vector2(1820, 600), Vector2(2310, 570), Vector2(3180, 590),
	Vector2(1810, 1790), Vector2(2500, 1830), Vector2(3410, 1750),
	Vector2(3980, 640), Vector2(5140, 640), Vector2(4020, 1760), Vector2(5150, 1760),
]

var gate_columns: Array[Dictionary] = []


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
		{"area": Rect2(1850, 620, 230, 290), "base": 240.0, "height": 425.0, "color": Color("4c6752")},
		{"area": Rect2(3000, 1510, 290, 230), "base": 240.0, "height": 435.0, "color": Color("52644f")},
		{"area": Rect2(4380, 590, 210, 300), "base": 480.0, "height": 750.0, "color": Color("727a65")},
		{"area": Rect2(4380, 1510, 210, 300), "base": 480.0, "height": 750.0, "color": Color("727a65")},
	]
	for center in GATE_COLUMN_CENTERS:
		var column := {"area": Rect2(center - GATE_COLUMN_SIZE * 0.5, GATE_COLUMN_SIZE), "base": 480.0, "height": GATE_COLUMN_TOP, "color": Color("677867")}
		gate_columns.append(column)
		wall_areas.append(column)
	for point in CANOPY_POINTS:
		# The trunk silhouette and its small walkability footprint share one record.
		wall_areas.append({"area": Rect2(point - Vector2.ONE * 23.0, Vector2.ONE * 46.0), "base": height_at(point), "height": height_at(point) + 230.0, "color": Color("486d57"), "visual": false})


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
