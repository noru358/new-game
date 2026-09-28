class_name JunglePassTerrain
extends "res://game/hybrid_terrain.gd"

const GATE_COLUMN_RISE := 530.0
const GATE_COLUMN_SIZE := Vector2(125.0, 120.0)
const GATE_COLUMN_CENTERS := [Vector2(4120, 1160), Vector2(5070, 1160)]
const CANOPY_POINTS := [
	Vector2(350, 470), Vector2(650, 360), Vector2(1090, 350),
	Vector2(350, 1880), Vector2(820, 2070), Vector2(1250, 1790),
	Vector2(1820, 600), Vector2(2310, 570), Vector2(3180, 590),
	Vector2(1810, 1790), Vector2(2450, 2160), Vector2(3470, 2200),
	Vector2(3980, 640), Vector2(5140, 640), Vector2(4020, 1760), Vector2(5150, 1760),
]

var gate_columns: Array[Dictionary] = []
var rock_ledge_areas: Array[Rect2] = [
	Rect2(2780, 1690, 120, 210),
	Rect2(2910, 1770, 140, 170),
	Rect2(3070, 1680, 130, 230),
]
var gate_routes: Dictionary = {
	"stairs": {"entry": Rect2(2510, 620, 250, 830), "crest": Rect2(3150, 620, 200, 830)},
	"rocks": {"entry": Rect2(2520, 1660, 260, 260), "crest": Rect2(3330, 1680, 250, 220)},
}


func _init() -> void:
	map_size = Vector2(5600, 2400)
	# One western ridge forks into an upper causeway and a genuinely lower
	# canyon route. Both rise separately to the high gate court.
	plateaus = [
		{"area": Rect2(1550, 400, 950, 1600), "height": 240.0, "base": 0.0, "name": "정글 능선", "openings": {"west": [[900.0, 1450.0]], "north": [[2000.0, 2350.0]], "south": [[2000.0, 2350.0]], "east": [[760.0, 1320.0], [1660.0, 1920.0]]}},
		{"area": Rect2(2500, 620, 850, 830), "height": 240.0, "base": 0.0, "name": "관문 제방", "openings": {"west": [[760.0, 1320.0]], "east": [[900.0, 1450.0]]}},
		{"area": Rect2(2760, 1620, 460, 380), "height": 80.0, "base": 0.0, "name": "하층 협곡", "openings": {"west": [[1660.0, 1920.0]], "east": [[1680.0, 1900.0]]}},
		{"area": Rect2(3900, 500, 1350, 1400), "height": 480.0, "base": 0.0, "name": "관문 상단", "openings": {"west": [[900.0, 1450.0], [1650.0, 1900.0]]}},
	]
	ramps = [
		{"area": Rect2(1280, 900, 270, 550), "axis": 0, "from": 0.0, "to": 240.0, "name": "서쪽 상승로"},
		{"area": Rect2(2000, 130, 350, 270), "axis": 1, "from": 0.0, "to": 240.0, "name": "북쪽 덩굴길"},
		{"area": Rect2(2000, 2000, 350, 270), "axis": 1, "from": 240.0, "to": 0.0, "name": "남쪽 우회로"},
		{"area": Rect2(3350, 900, 550, 550), "axis": 0, "from": 240.0, "to": 480.0, "base": 0.0, "name": "관문 석계단", "kind": "gate_stairs"},
		{"area": Rect2(3600, 1650, 300, 250), "axis": 0, "from": 240.0, "to": 480.0, "base": 0.0, "name": "관문 바위길", "kind": "rock_path"},
		{"area": Rect2(2500, 1660, 260, 260), "axis": 0, "from": 240.0, "to": 80.0, "base": 0.0, "name": "협곡 하강로", "kind": "rock_path"},
		{"area": Rect2(3220, 1680, 380, 220), "axis": 0, "from": 80.0, "to": 240.0, "base": 0.0, "name": "끊어진 바위 다리", "kind": "broken_bridge"},
	]
	water_areas = []
	chasm_areas = [
		Rect2(2500, 1450, 1100, 170),
		Rect2(2500, 1620, 260, 40),
		Rect2(3220, 1620, 380, 60),
		Rect2(3220, 1900, 380, 230),
	]
	floor_areas = [
		{"area": Rect2(100, 370, 1260, 1670), "color": Color("6b8664")},
		{"area": Rect2(390, 780, 1160, 720), "height": 1.2, "color": Color("9b9b70")},
		{"area": Rect2(1640, 540, 790, 1320), "height": 241.2, "color": Color("788b6d")},
		{"area": Rect2(1930, 910, 570, 520), "height": 242.4, "color": Color("b3aa83")},
		{"area": Rect2(2530, 700, 770, 670), "height": 241.2, "color": Color("b8ad87")},
		{"area": Rect2(2760, 1630, 450, 350), "height": 81.2, "color": Color("536d65")},
		{"area": Rect2(3920, 540, 1270, 1320), "height": 481.2, "color": Color("9f9b7f")},
		{"area": Rect2(4100, 800, 1030, 720), "height": 482.4, "color": Color("bcb08a")},
		{"area": Rect2(3900, 940, 240, 470), "height": 483.6, "color": Color("b8ad87")},
		{"area": Rect2(3900, 1660, 260, 230), "height": 482.5, "color": Color("788376")},
	]
	wall_areas = [
		{"area": Rect2(600, 500, 180, 250), "rise": 165.0, "color": Color("3d6149")},
		{"area": Rect2(930, 1640, 190, 260), "rise": 175.0, "color": Color("426b52")},
		{"area": Rect2(1850, 620, 230, 290), "rise": 185.0, "color": Color("4c6752")},
		{"area": Rect2(2860, 710, 160, 160), "rise": 145.0, "color": Color("52644f")},
		{"area": Rect2(2700, 1460, 110, 110), "rise": 185.0, "color": Color("40564e"), "collidable": false},
		{"area": Rect2(3350, 1480, 120, 110), "rise": 210.0, "color": Color("50665c"), "collidable": false},
		{"area": Rect2(4380, 590, 210, 300), "rise": 270.0, "color": Color("727a65")},
		{"area": Rect2(4380, 1510, 210, 300), "rise": 270.0, "color": Color("727a65")},
		{"area": Rect2(3330, 1970, 70, 75), "rise": 110.0, "color": Color("586b63"), "collidable": false},
		{"area": Rect2(4120, 1660, 90, 100), "rise": 115.0, "color": Color("67776b")},
	]
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


func height_at(point: Vector2) -> float:
	for ramp in ramps:
		if ramp.area.has_point(point): return ramp_height(ramp, point)
	for i in range(plateaus.size() - 1, -1, -1):
		if plateaus[i].area.has_point(point): return plateaus[i].height
	return 0.0


func surface_name(point: Vector2) -> String:
	for ramp in ramps:
		if ramp.area.has_point(point): return ramp.name
	if plateaus[3].area.has_point(point): return "관문 상단"
	if plateaus[2].area.has_point(point): return "하층 협곡"
	if plateaus[1].area.has_point(point): return "석계단 제방"
	if plateaus[0].area.has_point(point): return "정글 능선"
	return "정글 진입로" if point.x < 1550.0 else "절벽 아랫길"
