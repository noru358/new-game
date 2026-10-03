extends RefCounted
## Southeast Asia -> large ruined temple -> quiet courtyard behind the cloister.
## This is this garden's story, not a universal history rule for hidden streets.
## Portal, guardian, discovery and reward contracts remain in Garden.
const Garden = preload("res://game/temple_garden_layout.gd")
const FLOOR_ZONES := [
	{"area": Rect2(5650, 1660, 780, 280), "color": Color("a7ad91"), "place": "collapsed_cloister"},
	{"area": Rect2(6190, 420, 245, 1300), "color": Color("b5b79b"), "place": "tended_walk"},
	{"area": Rect2(6435, 420, 1505, 260), "color": Color("b7b59b"), "place": "tended_walk"},
	{"area": Rect2(6390, 1430, 1700, 280), "color": Color("989e7e"), "place": "rooted_bank"},
	{"area": Rect2(7890, 680, 280, 750), "color": Color("a9aa8b"), "place": "rooted_bank"},
	{"area": Rect2(8070, 280, 410, 400), "color": Color("bbbba0"), "place": "garden_stone"},
]
# Only the rear perimeter retains tall masonry. Every interior/southeast edge
# is permanently low, so normal camera/actor rays are never solved by fading.
const WALL_SPECS := [
	{"area": Rect2(5600, 80, 3000, 45), "height": 115.0, "place": "rear_cloister"},
	{"area": Rect2(5600, 125, 45, 1910), "height": 115.0, "place": "rear_cloister"},
	{"area": Rect2(5600, 2035, 3000, 45), "height": 21.0, "place": "low_boundary"},
	{"area": Rect2(8555, 125, 45, 1910), "height": 21.0, "place": "low_boundary"},
	{"area": Rect2(5680, 920, 470, 620), "height": 21.0, "place": "cloister_bed"},
	{"area": Rect2(6480, 250, 95, 480), "height": 21.0, "place": "tended_bed"},
	{"area": Rect2(6480, 930, 95, 260), "height": 21.0, "place": "tended_bed"},
	{"area": Rect2(6810, 1820, 580, 120), "height": 21.0, "place": "rooted_bed"},
	{"area": Rect2(7770, 190, 120, 360), "height": 21.0, "place": "garden_stone"},
	{"area": Rect2(8201, 321, 48, 48), "height": 21.0, "place": "water_bowl"},
	{"area": Rect2(8230, 1740, 200, 150), "height": 21.0, "place": "rooted_bed"},
]
const DRY_CHANNEL := [Vector2(6170, 1610), Vector2(6460, 1610), Vector2(6460, 1570), Vector2(6650, 1570), Vector2(6650, 1120), Vector2(6805, 1120)]
const WALK_POINTS := [
	{"name": "threshold", "point": Garden.FIELD_ENTRY},
	{"name": "first_fork", "point": Vector2(6350, 1510)},
	{"name": "west_pond", "point": Vector2(6640, 1080)},
	{"name": "tended_walk", "point": Vector2(7130, 520)},
	{"name": "north_pond", "point": Vector2(7520, 730)},
	{"name": "rooted_bank", "point": Vector2(7360, 1510)},
	{"name": "east_pond", "point": Vector2(8030, 1370)},
	{"name": "garden_stone", "point": Garden.ALTAR},
	{"name": "north_return", "point": Vector2(7130, 520)},
	{"name": "west_return", "point": Vector2(6310, 810)},
	{"name": "threshold_return", "point": Garden.FIELD_ENTRY},
]

static func install(terrain) -> void:
	# Hybrid owns the main vestibule. Circuit copies these exact field records
	# from Original, so it needs no second garden/collision implementation.
	var cuts: Array = [Garden.POND]
	for spec in WALL_SPECS: cuts.append(spec.area)
	for zone in FLOOR_ZONES: cuts.append(zone.area)
	terrain.floor_areas.append({"area": Garden.FIELD_BOUNDS, "height": 0.3, "color": Color("889775"), "cutouts": cuts, "discovery_id": "TEMPLE_GARDEN"})
	for i in FLOOR_ZONES.size():
		var zone: Dictionary = FLOOR_ZONES[i]
		var zone_cuts: Array = [Garden.POND]
		for wall in WALL_SPECS: zone_cuts.append(wall.area)
		for j in range(i + 1, FLOOR_ZONES.size()): zone_cuts.append(FLOOR_ZONES[j].area)
		terrain.floor_areas.append({"area": zone.area, "height": 0.45, "color": zone.color, "cutouts": zone_cuts, "discovery_id": "TEMPLE_GARDEN", "courtyard_place": zone.place})
	terrain.water_areas.append(Garden.POND)
	for spec in WALL_SPECS:
		terrain.wall_areas.append({"area": spec.area, "height": spec.height, "color": Color("8e9f8c"), "visual": false, "minimap_visible": true, "garden_courtyard": true, "discovery_id": "TEMPLE_GARDEN", "courtyard_place": spec.place})
