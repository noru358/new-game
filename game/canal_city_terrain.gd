class_name CanalCityTerrain
extends HybridTerrain

const MAP_SIZE := Vector2(7200, 4800)
const WATER_Y := 2220.0
const SOUTH_BANK_Y := 2720.0
const BRIDGES := [Rect2(3250, WATER_Y, 360, 500), Rect2(5020, WATER_Y, 350, 500)]
const DOCK := Rect2(4280, 2520, 350, 310)

var districts := {
	"동문": Rect2(5700, 3100, 1200, 1350),
	"시장 골목": Rect2(3650, 950, 1850, 1200),
	"열린 수변": Rect2(3800, 2750, 1800, 700),
	"창고 하역장": Rect2(1450, 2950, 2350, 1500),
	"수문 앞 마당": Rect2(1050, 1050, 1500, 1000),
}


func _init() -> void:
	map_size = MAP_SIZE
	plateaus = []
	ramps = []
	chasm_areas = []
	water_areas = [
		Rect2(350, WATER_Y, 2900, 500),
		Rect2(3610, WATER_Y, 1410, 300),
		Rect2(3610, 2520, 670, 200),
		Rect2(4630, 2520, 390, 200),
		Rect2(5370, WATER_Y, 1530, 500),
	]
	floor_areas = [
		{"area": Rect2(500, 790, 6350, 1340), "height": 0.3, "color": Color("baa98a"), "name": "북쪽 석조 거리"},
		{"area": Rect2(5700, 3140, 1100, 1250), "color": Color("b7aa8e"), "name": "동문 돌길"},
		{"area": Rect2(3500, 1050, 2050, 1040), "color": Color("ceb996"), "name": "시장 골목"},
		{"area": Rect2(950, 1050, 1750, 1050), "color": Color("d0c5a4"), "name": "수문 앞 마당"},
		{"area": Rect2(1350, 2900, 2500, 1500), "color": Color("a89c85"), "name": "창고 하역장"},
		{"area": Rect2(3750, 2770, 1780, 730), "color": Color("c9bc9c"), "name": "열린 수변"},
		{"area": Rect2(3250, WATER_Y, 360, 500), "color": Color("a88058"), "name": "서쪽 연결교"},
		{"area": Rect2(5020, WATER_Y, 350, 500), "color": Color("a88058"), "name": "상점 사이 연결교"},
		{"area": DOCK, "color": Color("987650"), "name": "고정 선착장"},
	]
	wall_areas = []
	# Buildings, their navigation footprints, and their visible geometry use one record.
	for entry in [
		[Rect2(3720, 990, 450, 355), "shop", "d9d0b8"],
		[Rect2(4270, 890, 500, 390), "shop", "d3c2a6"],
		[Rect2(4870, 1010, 435, 310), "shop", "dfd5bc"],
		[Rect2(3730, 1770, 480, 360), "shop", "cfc5ae"],
		[Rect2(4290, 1790, 440, 330), "shop", "d8cfb3"],
		[Rect2(5420, 1720, 400, 400), "shop", "d2c5a8"],
		[Rect2(1530, 3520, 610, 650), "warehouse", "c8bd9f"],
		[Rect2(2240, 3500, 645, 650), "warehouse", "c3b99f"],
		[Rect2(2990, 3500, 650, 770), "warehouse", "cbbda1"],
		[Rect2(1810, 4260, 750, 390), "warehouse", "c4b69b"],
		[Rect2(2740, 4320, 720, 310), "warehouse", "c3bea8"],
		[Rect2(890, 1200, 210, 370), "sluice", "7c9997"],
		[Rect2(890, 1760, 210, 360), "sluice", "7c9997"],
		[Rect2(6570, 3050, 250, 490), "gate", "8b9a88"],
		[Rect2(6570, 4020, 250, 500), "gate", "8b9a88"],
	]:
		var kind: String = entry[1]
		wall_areas.append({"area": entry[0], "height": 260.0 if kind == "warehouse" else 230.0 if kind == "shop" else 195.0, "color": Color(entry[2]), "kind": kind})
	# Far bank silhouettes sit beyond the trial's walkable northern edge.
	wall_areas.append({"area": Rect2(0, 720, 7200, 36), "height": 46.0, "color": Color("728981"), "kind": "parapet"})
	for i in 12:
		var width := 440.0 + float(i % 3) * 95.0
		wall_areas.append({"area": Rect2(170.0 + i * 605.0, -550.0 + float(i % 2) * 105.0, width, 1030.0), "height": 220.0 + float(i % 4) * 55.0, "color": Color("bdc2ad") if i % 2 == 0 else Color("d5ceb4"), "kind": "background", "collidable": false})
	for bridge in BRIDGES:
		for edge_x in [bridge.position.x, bridge.end.x - 24.0]:
			wall_areas.append({"area": Rect2(edge_x, WATER_Y, 24.0, 500.0), "height": 43.0, "color": Color("7b7060"), "kind": "bridge_rail"})
	# Fixed waterside stairs and quay blocks do not project over the combat lane.
	for i in 5:
		wall_areas.append({"area": Rect2(3810 + i * 330, SOUTH_BANK_Y, 44, 34), "height": 35.0, "color": Color("958f77"), "kind": "bollard"})


func height_at(_point: Vector2) -> float:
	return 0.0


func surface_name(point: Vector2) -> String:
	for district in districts:
		if (districts[district] as Rect2).has_point(point):
			return district
	for bridge in BRIDGES:
		if bridge.has_point(point): return "운하 연결교"
	if DOCK.has_point(point): return "고정 선착장"
	return "강남 수로도시"
