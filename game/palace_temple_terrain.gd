extends "res://game/hybrid_terrain.gd"
## Southeast Asia -> maintained palace temple -> procession / court / cloister.
const ENTRY := Vector2(580, 1550)
const GATE := Vector2(1080, 1550)
const COURT_CENTER := Vector2(1830, 1530)
const CLOISTER := Vector2(2180, 1080)
const WAYPOINTS := [ENTRY, GATE, Vector2(1450, 1550), COURT_CENTER, Vector2(2180, 1450), CLOISTER, Vector2(2720, 1080)]

func _init() -> void:
	map_size = Vector2(3400, 2500)
	plateaus = []
	ramps = []
	water_areas = []
	chasm_areas.clear()
	floor_areas = [
		{"area": Rect2(260, 1330, 990, 440), "height": 0.5, "color": Color("cbbd94")},
		{"area": Rect2(1220, 1040, 1820, 1100), "height": 0.5, "color": Color("e6dcc1")},
		{"area": Rect2(1460, 860, 1530, 260), "height": 0.5, "color": Color("9caa9b")},
	]
	wall_areas = [
		{"area": Rect2(890, 1070, 140, 220), "height": 420.0},
		{"area": Rect2(890, 1820, 140, 220), "height": 420.0},
		{"area": Rect2(720, 1090, 165, 180), "height": 485.0},
		{"area": Rect2(720, 1840, 165, 180), "height": 485.0},
		{"area": Rect2(280, 1000, 630, 70), "height": 165.0},
		{"area": Rect2(280, 2040, 750, 70), "height": 90.0},
		{"area": Rect2(1420, 620, 1610, 120), "height": 225.0},
		{"area": Rect2(2950, 360, 290, 530), "height": 580.0},
	]
	for x in [1500, 1860, 2220, 2580, 2940]:
		wall_areas.append({"area": Rect2(x, 890, 52, 52), "height": 235.0})
	for wall in wall_areas: wall["visual"] = false

func height_at(_point: Vector2) -> float: return 0.0

func surface_name(point: Vector2) -> String:
	if point.x < 1220: return "행렬문"
	if point.y < 1150: return "그늘진 회랑"
	return "밝은 중정"
