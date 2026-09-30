class_name JunglePassTerrain
extends "res://game/hybrid_terrain.gd"

const Grotto = preload("res://game/jungle_grotto_layout.gd")

const GATE_COLUMN_RISE := 155.0
const GATE_COLUMN_SIZE := Vector2(125.0, 120.0)
const GATE_COLUMN_CENTERS := [Vector2(4120, 650), Vector2(5200, 650)]
const CANOPY_POINTS := [
	Vector2(350, 470), Vector2(650, 360), Vector2(1090, 350),
	Vector2(350, 1880), Vector2(820, 2070), Vector2(1250, 1790),
	Vector2(1820, 600), Vector2(2310, 570), Vector2(3180, 590),
	Vector2(1810, 1790), Vector2(2450, 2160), Vector2(3470, 2200),
	Vector2(3980, 640), Vector2(5140, 480), Vector2(4060, 1390), Vector2(5200, 2160),
]

var gate_columns: Array[Dictionary] = []
var rock_ledge_areas: Array[Rect2] = [
	Rect2(2780, 1690, 120, 210),
	Rect2(2910, 1770, 140, 170),
	Rect2(3070, 1680, 130, 230),
]
var gate_routes: Dictionary = {
	"stairs": {"entry": Rect2(2510, 620, 250, 830), "crest": Rect2(3760, 900, 240, 550)},
	"rocks": {"entry": Rect2(2520, 1660, 260, 260), "crest": Rect2(4100, 1550, 260, 450)},
}


func _init() -> void:
	map_size = Vector2(5600, 2400)
	# One western ridge forks into an upper causeway and a genuinely lower
	# canyon route. Both rise separately to the high gate court.
	plateaus = [
		{"area": Rect2(1550, 400, 950, 1600), "height": 240.0, "base": 0.0, "name": "정글 능선", "openings": {"west": [[900.0, 1450.0]], "north": [[2000.0, 2350.0]], "south": [[2000.0, 2350.0]], "east": [[760.0, 1320.0], [1660.0, 1920.0]]}},
		{"area": Rect2(2500, 620, 850, 830), "height": 240.0, "base": 0.0, "name": "무너진 석교", "openings": {"west": [[760.0, 1320.0]], "east": [[900.0, 1450.0]], "south": [[2760.0, 3020.0]]}},
		{"area": Rect2(2760, 1550, 460, 700), "height": 80.0, "base": 0.0, "name": "강변 쉼터", "openings": {"west": [[1660.0, 1920.0]], "east": [[1550.0, 2250.0]], "north": [[2760.0, 3020.0]]}},
		{"area": Rect2(3900, 500, 1350, 1050), "height": 480.0, "base": 0.0, "name": "관문 상단", "openings": {"west": [[900.0, 1450.0]], "south": [[4360.0, 5250.0]]}},
		{"area": Rect2(4360, 1550, 890, 700), "height": 480.0, "base": 0.0, "name": "남쪽 관문 상단", "openings": {"west": [[1550.0, 2250.0]], "north": [[4360.0, 5250.0]]}},
		{"area": Rect2(2000, 130, 350, 270), "height": 240.0, "base": 0.0, "name": "북쪽 덩굴길 쉼터", "openings": {"west": [[130.0, 400.0]], "south": [[2000.0, 2350.0]]}},
	]
	ramps = [
		{"area": Rect2(800, 900, 750, 550), "axis": 0, "from": 0.0, "to": 240.0, "name": "서쪽 상승로"},
		{"area": Rect2(1250, 130, 750, 270), "axis": 0, "from": 0.0, "to": 240.0, "name": "북쪽 덩굴길"},
		{"area": Rect2(2000, 2000, 350, 270), "axis": 1, "from": 240.0, "to": 0.0, "name": "남쪽 우회로"},
		{"area": Rect2(3150, 900, 750, 550), "axis": 0, "from": 240.0, "to": 480.0, "base": 0.0, "name": "관문 석계단", "kind": "gate_stairs"},
		{"area": Rect2(3600, 1550, 760, 700), "axis": 0, "from": 240.0, "to": 480.0, "base": 0.0, "name": "강변 유적 오르막", "kind": "rock_path"},
		{"area": Rect2(2500, 1660, 260, 260), "axis": 0, "from": 240.0, "to": 80.0, "base": 0.0, "name": "협곡 하강로", "kind": "rock_path"},
		{"area": Rect2(3100, 1550, 500, 700), "axis": 0, "from": 80.0, "to": 240.0, "base": 0.0, "name": "끊어진 바위 다리", "kind": "broken_bridge"},
	]
	ramps.append({"area": Rect2(2760, 1200, 260, 520), "axis": 1, "from": 240.0, "to": 80.0, "base": 0.0, "name": "강변 연결 비탈", "kind": "rock_path"})
	water_areas = []
	chasm_areas = [
		Rect2(2500, 1450, 260, 100),
		Rect2(3020, 1450, 580, 100),
		Rect2(2500, 1620, 260, 40),
	]
	floor_areas = [
		{"area": Rect2(100, 370, 1260, 1670), "color": Color("6b8664")},
		{"area": Rect2(210, 390, 930, 270), "height": 1.3, "color": Color("52745b")},
		{"area": Rect2(220, 1650, 1060, 300), "height": 1.3, "color": Color("587663")},
		{"area": Rect2(390, 780, 1160, 720), "height": 1.2, "color": Color("9b9b70")},
		{"area": Rect2(1640, 540, 790, 1320), "height": 241.2, "color": Color("788b6d")},
		{"area": Rect2(1930, 910, 570, 520), "height": 242.4, "color": Color("b3aa83")},
		{"area": Rect2(2530, 700, 770, 670), "height": 241.2, "color": Color("b8ad87")},
		{"area": Rect2(2760, 1630, 450, 620), "height": 81.2, "color": Color("536d65")},
		{"area": Rect2(2760, 2050, 450, 190), "height": 81.4, "color": Color("497775")},
		{"area": Rect2(3920, 540, 1270, 1010), "height": 481.2, "color": Color("9f9b7f")},
		{"area": Rect2(4360, 1550, 830, 620), "height": 481.2, "color": Color("9f9b7f")},
		{"area": Rect2(4100, 800, 1030, 720), "height": 482.4, "color": Color("bcb08a")},
		{"area": Rect2(3900, 940, 240, 470), "height": 483.6, "color": Color("b8ad87")},
	]
	wall_areas = [
		{"area": Rect2(600, 500, 180, 250), "rise": 165.0, "color": Color("3d6149")},
		{"area": Rect2(930, 1640, 190, 260), "rise": 175.0, "color": Color("426b52")},
		{"area": Rect2(1850, 620, 230, 290), "rise": 185.0, "color": Color("4c6752")},
		{"area": Rect2(2860, 710, 160, 160), "rise": 145.0, "color": Color("52644f")},
		{"area": Rect2(2700, 1460, 110, 110), "rise": 185.0, "color": Color("40564e"), "collidable": false},
		{"area": Rect2(3350, 1480, 120, 110), "rise": 210.0, "color": Color("50665c"), "collidable": false},
		{"area": Rect2(4380, 590, 210, 300), "rise": 90.0, "color": Color("727a65")},
		{"area": Rect2(4380, 1250, 210, 220), "rise": 90.0, "color": Color("727a65")},
		{"area": Rect2(3330, 2050, 70, 75), "rise": 110.0, "color": Color("586b63"), "collidable": false},
		{"area": Rect2(4490, 1690, 90, 100), "rise": 115.0, "color": Color("67776b")},
	]
	# Broken parapets constrict the direct causeway; broad bank below permits flanking.
	for area in [Rect2(2760, 880, 260, 140), Rect2(2530, 1320, 180, 105), Rect2(3420, 1550, 110, 190)]:
		wall_areas.append({"area": area, "rise": 65.0, "color": Color("827f69")})
	floor_areas.append({"area": Rect2(2780, 1990, 200, 160), "height": 81.5, "color": Color("5d9290")})
	plateaus[1]["cutouts"] = [ramps[7].area]
	for floor in floor_areas:
		if float(floor.get("height", 0.0)) > 200.0 and floor.area.intersects(ramps[7].area):
			floor["cutouts"] = [ramps[7].area]
	for center in GATE_COLUMN_CENTERS:
		var column := {"area": Rect2(center - GATE_COLUMN_SIZE * 0.5, GATE_COLUMN_SIZE), "rise": GATE_COLUMN_RISE, "color": Color("677867")}
		gate_columns.append(column)
		wall_areas.append(column)
	for point in CANOPY_POINTS:
		# The trunk silhouette and its small walkability footprint share one record.
		wall_areas.append({"area": Rect2(point - Vector2.ONE * 23.0, Vector2.ONE * 46.0), "rise": 230.0, "color": Color("486d57"), "visual": false})
	for wall in wall_areas:
		var base: float = height_at(wall.area.get_center())
		wall["base"] = base
		wall["height"] = base + float(wall.rise)

	Grotto.install(self)


func height_at(point: Vector2) -> float:
	for ramp in ramps:
		if ramp.area.has_point(point): return ramp_height(ramp, point)
	for i in range(plateaus.size() - 1, -1, -1):
		if plateaus[i].area.has_point(point): return plateaus[i].height
	return 0.0


func surface_name(point: Vector2) -> String:
	if Grotto.FIELD_BOUNDS.has_point(point): return Grotto.surface_name(point)
	for ramp in ramps:
		if ramp.area.has_point(point): return ramp.name
	if plateaus[3].area.has_point(point) or plateaus[4].area.has_point(point): return "관문 상단"
	if plateaus[5].area.has_point(point): return "북쪽 덩굴길 쉼터"
	if plateaus[2].area.has_point(point): return "강변 쉼터"
	if plateaus[1].area.has_point(point): return "무너진 석교"
	if plateaus[0].area.has_point(point): return "정글 능선"
	return "정글 진입로" if point.x < 1550.0 else "절벽 아랫길"
