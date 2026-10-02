class_name TempleCircuitTrialTerrain
extends "res://game/hybrid_terrain.gd"
## Whole-field topology candidate, kept separate from the playable progression map.
const ENTRY := Vector2(650, 3000)
const CENTRAL_COURT := Vector2(2450, 2100)
const CLOISTER := Vector2(1450, 1350)
const WATER_PATH := Vector2(3400, 2080)
const THRESHOLD := Vector2(2650, 1000)
const SANCTUARY := Vector2(2800, 460)
const MAIN_ROUTE := [ENTRY, Vector2(1350, 2800), CENTRAL_COURT, CLOISTER, Vector2(1650, 910), THRESHOLD, SANCTUARY]
const WATER_ROUTE := [CENTRAL_COURT, Vector2(2880, 2470), WATER_PATH, Vector2(3350, 1190), THRESHOLD]

func _init() -> void:
	map_size = Vector2(4600, 3500)
	plateaus = []
	ramps = []
	water_areas = [Rect2(70, 70, 720, 2470), Rect2(790, 70, 1150, 570), Rect2(3650, 800, 850, 2540), Rect2(2950, 1590, 390, 620), Rect2(1850, 3070, 1800, 280)]
	floor_areas = [
		{"area": Rect2(280, 2600, 1350, 440), "height": 0.5, "color": Color("a0b49d")},
		{"area": Rect2(1870, 1600, 990, 1150), "height": 0.5, "color": Color("c3bd96")},
		{"area": Rect2(1150, 870, 530, 1400), "height": 0.5, "color": Color("a8ad8d")},
		{"area": Rect2(2170, 720, 900, 510), "height": 0.5, "color": Color("c6c19e")},
		{"area": Rect2(2380, 160, 1000, 540), "height": 0.5, "color": Color("d3c7a0")},
	]
	wall_areas = [
		{"area": Rect2(1730, 1190, 420, 500), "height": 110.0, "color": Color("819987")},
		{"area": Rect2(2510, 1340, 410, 190), "height": 65.0, "color": Color("879584")},
		{"area": Rect2(950, 1030, 130, 550), "height": 160.0, "color": Color("7d9585")},
		{"area": Rect2(2360, 170, 80, 370), "height": 110.0, "color": Color("839786")},
		{"area": Rect2(3310, 170, 80, 370), "height": 110.0, "color": Color("839786")},
		{"area": Rect2(2430, 160, 900, 80), "height": 180.0, "color": Color("78917d")},
	]

func height_at(_point: Vector2) -> float: return 0.0
func surface_name(point: Vector2) -> String:
	if point.distance_to(SANCTUARY) < 500: return "성소 후보"
	if point.distance_to(THRESHOLD) < 570: return "상단 문턱"
	if point.x > 3000: return "물가 우회"
	if point.x < 1750 and point.y < 2350: return "서쪽 회랑"
	if point.y > 2570: return "수변 진입"
	return "중심 뜰"
