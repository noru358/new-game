extends "res://game/hybrid_terrain.gd"
## China south > Jiangnan reference region > canal town > market / cargo quay.
## Authored v2 connections, shared by collision, navigation and rendering.
## Background architecture remains outside the playable rectangle.
const ENTRY := Vector2(6200, 4000)
const MARKET := Vector2(1600, 1550)
const WATERFRONT := Vector2(4540, 2630)
const WAREHOUSE := Vector2(4300, 2910)
const SLUICE := Vector2(6650, 1500)
const LOADING_BARRELS := [Vector2(4440, 2770), Vector2(4490, 2790), Vector2(4710, 2710)]
const CART := Vector2(4470, 3080)
const BRIDGES := [Rect2(1200, 1960, 400, 500), Rect2(3600, 1960, 500, 500), Rect2(5900, 1960, 400, 500), Rect2(2750, 850, 480, 400)]
const BUILDINGS := [
	{"area": Rect2(200, -720, 470, 430), "background": true, "kind": "background"},
	{"area": Rect2(850, -720, 470, 430), "background": true, "kind": "background"},
	{"area": Rect2(1500, -720, 470, 430), "background": true, "kind": "background"},
	{"area": Rect2(2150, -720, 470, 430), "background": true, "kind": "background"},
	{"area": Rect2(2800, -720, 470, 430), "background": true, "kind": "background"},
	{"area": Rect2(3450, -720, 470, 430), "background": true, "kind": "background"},
	{"area": Rect2(4100, -720, 470, 430), "background": true, "kind": "background"},
	{"area": Rect2(4750, -720, 470, 430), "background": true, "kind": "background"},
	{"area": Rect2(5400, -720, 470, 430), "background": true, "kind": "background"},
	{"area": Rect2(6050, -720, 470, 430), "background": true, "kind": "background"},
	{"area": Rect2(6700, -720, 470, 430), "background": true, "kind": "background"},
	{"area": Rect2(150, 120, 680, 500), "background": false, "kind": "shop"},
	{"area": Rect2(950, 120, 620, 500), "background": false, "kind": "shop"},
	{"area": Rect2(1700, 120, 620, 500), "background": false, "kind": "shop"},
	{"area": Rect2(180, 850, 650, 470), "background": false, "kind": "shop"},
	{"area": Rect2(900, 820, 330, 450), "background": false, "kind": "shop"},
	{"area": Rect2(1750, 800, 570, 420), "background": false, "kind": "shop"},
	{"area": Rect2(160, 1520, 680, 340), "background": false, "kind": "shop"},
	# South-facing rows meet these north-facing premises around the selling
	# lane. The open west bridge mouth and east turning court remain clear.
	{"area": Rect2(1740, 1730, 450, 120), "background": false, "kind": "shop"},
	{"area": Rect2(2360, 1720, 320, 130), "background": false, "kind": "shop"},
	{"area": Rect2(3500, 150, 560, 600), "background": false, "kind": "shop"},
	{"area": Rect2(4200, 150, 620, 600), "background": false, "kind": "shop"},
	{"area": Rect2(4980, 150, 590, 600), "background": false, "kind": "shop"},
	{"area": Rect2(5780, 120, 1080, 450), "background": false, "kind": "shop"},
	{"area": Rect2(4450, 900, 540, 330), "background": false, "kind": "shop"},
	{"area": Rect2(5050, 900, 600, 330), "background": false, "kind": "shop"},
	{"area": Rect2(3300, 1670, 330, 250), "background": false, "kind": "shop"},
	{"area": Rect2(4300, 1640, 600, 300), "background": false, "kind": "shop"},
	{"area": Rect2(5050, 1640, 480, 300), "background": false, "kind": "shop"},
	{"area": Rect2(150, 2670, 840, 500), "background": false, "kind": "warehouse"},
	{"area": Rect2(150, 3380, 1000, 520), "background": false, "kind": "warehouse"},
	{"area": Rect2(2420, 3250, 980, 430), "background": false, "kind": "warehouse"},
	{"area": Rect2(3550, 3250, 850, 430), "background": false, "kind": "warehouse"},
	{"area": Rect2(4600, 2900, 650, 450), "background": false, "kind": "warehouse"},
	{"area": Rect2(4600, 3520, 900, 430), "background": false, "kind": "warehouse"},
	{"area": Rect2(6450, 2750, 550, 880), "background": false, "kind": "warehouse"},
	{"area": Rect2(2600, 4420, 820, 270), "background": false, "kind": "warehouse"},
	{"area": Rect2(3650, 4420, 850, 270), "background": false, "kind": "warehouse"},
 ]
var buildings: Array[Dictionary] = []
var props: Array[Dictionary] = []

func _init() -> void:
	map_size = Vector2(7200, 4800)
	plateaus = []
	ramps = []
	floor_areas = [
		{"area": Rect2(1100, 1280, 1580, 590), "color": Color("c6baa0")},
		{"area": Rect2(1200, 2470, 4500, 690), "color": Color("b3b6a0")},
		{"area": Rect2(5730, 1250, 1300, 670), "color": Color("cbd0ad")},
		{"area": Rect2(5800, 3700, 950, 600), "color": Color("c9c4ae")}
	]
	wall_areas = []
	# Bridges are real openings in water, not a walkable visual over a blocker.
	water_areas = [Rect2(0, 2000, 1200, 420), Rect2(1600, 2000, 2000, 420), Rect2(4100, 2000, 1800, 420), Rect2(6300, 2000, 900, 420), Rect2(2800, 0, 380, 850), Rect2(2800, 1250, 380, 750)]
	for area in BRIDGES:
		floor_areas.append({"area": area, "height": 2.0, "color": Color("b7b7a2")})
	for source in BUILDINGS:
		var record: Dictionary = source.duplicate()
		# Low plaster shop rows and slightly taller working storehouses. These
		# remain the v2 footprints; A's roof language replaces B's blank caps.
		record["height"] = 180.0 if record.kind == "shop" else 215.0
		if record.background: record["height"] = 235.0 + float(int(record.area.position.x) % 3) * 18.0
		record["front"] = "north" if (record.kind == "warehouse" or (record.area.position.y > 1500 and record.area.position.y < 1950)) else "south"
		buildings.append(record)
		if not record.background:
			wall_areas.append({"area": record.area, "height": record.height, "color": Color("e4d9bf"), "visual": false})
	# Stall counters belong to each shop frontage and share their blocker record.
	# West market: produce, pottery and cloth fronts face one shared selling
	# lane, with stock tucked back against the shops rather than scattered.
	for entry in [[1190, "produce"], [1450, "produce"], [1910, "pottery"], [2180, "textile"]]:
		_add_prop(Rect2(entry[0], 1320, 140, 90), "stall", entry[1])
	# East commercial approach repeats the same craft vocabulary at a smaller
	# scale; the continuous north lane still reaches the water-control court.
	_add_prop(Rect2(4490, 1290, 150, 85), "stall", "textile")
	_add_prop(Rect2(5130, 1290, 140, 85), "stall", "produce")
	for entry in [[Vector2(1940, 1265), "pottery"], [Vector2(2200, 1265), "textile"], [Vector2(4515, 1240), "textile"]]:
		_add_prop(Rect2(entry[0], Vector2(75, 45)), "stock", entry[1])
	for x in [3660, 3990, 4390, 4660, 5080, 5370]:
		_add_prop(Rect2(x, 2730 if x > 4600 else 3120, 95, 75), "cargo")
	for x in [6650, 6850]:
		_add_prop(Rect2(x, 3680, 80, 75), "cargo")
	for point in LOADING_BARRELS:
		wall_areas.append({"area": Rect2(point - Vector2(28, 28), Vector2(56, 56)), "height": 52.0, "color": Color("8d7852"), "visual": false})
	wall_areas.append({"area": Rect2(CART - Vector2(68, 44), Vector2(200, 88)), "height": 45.0, "color": Color("796a4d"), "visual": false})
	# Sluice piers are scenery blockers; the courtyard stays open.
	for x in [6410, 6880]:
		_add_prop(Rect2(x, 930, 110, 130), "sluice")
	# Low gateposts frame a generous, unimpeded east entry.
	for y in [3780, 4210]:
		_add_prop(Rect2(6480, y, 100, 100), "gate")

func _add_prop(area: Rect2, kind: String, trade: String = "") -> void:
	props.append({"area": area, "kind": kind, "trade": trade})
	wall_areas.append({"area": area, "height": 65.0, "color": Color("a18557"), "visual": false})

func height_at(_point: Vector2) -> float:
	return 0.0

func surface_name(point: Vector2) -> String:
	if point.x > 5700 and point.y > 3300: return "동문 돌길"
	if point.y < 1950 and point.x < 2780: return "운하 시장"
	if point.x > 5700 and point.y < 1950: return "수문 앞 마당"
	if point.y > 3200: return "창고 뒤 골목"
	if point.y > 2450: return "창고 수변"
	return "상점 사이 연결길"
