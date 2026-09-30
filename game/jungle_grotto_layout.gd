extends RefCounted

const MAIN_BOUNDS := Rect2(0, 0, 5600, 2400)
const FIELD_BOUNDS := Rect2(6000, 80, 3200, 2200)
const ENTRY_TRIGGER := Rect2(1250, 630, 100, 110)
const RETURN_POINT := Vector2(1150, 700)
const FIELD_ENTRY := Vector2(6230, 1960)
const EXIT_TRIGGER := Rect2(6070, 1880, 110, 170)
const ALTAR := Vector2(8870, 440)
const FIRST_WAVE := [Vector2(6740, 1830), Vector2(7030, 1790), Vector2(7070, 1530)]
const SECOND_WAVE := [Vector2(7910, 1170), Vector2(8240, 920), Vector2(8490, 690)]
const FIRST_WAVE_AREA := Rect2(6320, 1210, 1070, 980)
const SECOND_WAVE_AREA := Rect2(7650, 390, 1340, 1000)

static func install(terrain) -> void:
	terrain.map_size = Vector2(9300, 2400)
	for rect in [Rect2(1240, 590, 150, 30), Rect2(1350, 590, 40, 210), Rect2(1240, 760, 150, 40)]:
		terrain.wall_areas.append({"area": rect, "base": 0.0, "height": 185.0, "color": Color("41695b"), "discovery_id": "JUNGLE_GROTTO"})
	terrain.floor_areas.append({"area": FIELD_BOUNDS, "color": Color("537b68"), "discovery_id": "JUNGLE_GROTTO"})
	for rect in [Rect2(6120, 1830, 1150, 290), Rect2(7000, 1130, 280, 980), Rect2(7080, 1110, 1150, 270), Rect2(7980, 390, 280, 930), Rect2(8080, 300, 960, 300)]:
		terrain.floor_areas.append({"area": rect, "height": 1.2, "color": Color("a5ae89"), "discovery_id": "JUNGLE_GROTTO"})
	# Offset stream pools shape a winding route, with generous dry crossings.
	for rect in [Rect2(6220, 850, 660, 790), Rect2(7450, 1490, 1020, 490), Rect2(8340, 750, 580, 590)]:
		terrain.water_areas.append(rect)
	for rect in [Rect2(6000, 80, 3200, 45), Rect2(6000, 2235, 3200, 45), Rect2(6000, 80, 45, 2200), Rect2(9155, 80, 45, 2200), Rect2(6180, 400, 800, 180), Rect2(6920, 240, 240, 700), Rect2(7330, 680, 400, 220), Rect2(8500, 2080, 550, 90)]:
		terrain.wall_areas.append({"area": rect, "base": 0.0, "height": 155.0, "color": Color("3f655b"), "discovery_id": "JUNGLE_GROTTO"})
	terrain.wall_areas.append({"area": Rect2(5600, 0, 400, 2400), "base": 0.0, "height": 200.0, "visual": false})
	for rect in [Rect2(8650, 210, 390, 45), Rect2(8670, 270, 65, 120), Rect2(9000, 430, 65, 150)]:
		terrain.wall_areas.append({"area": rect, "base": 0.0, "height": 120.0, "color": Color("9baf97"), "discovery_id": "JUNGLE_GROTTO"})
