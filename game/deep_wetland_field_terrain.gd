extends "res://game/deep_wetland_terrain.gd"
## Whole-field candidate: keep the original approach and add the inner sanctuary loop.
## Geometry first; this separate scene does not grant campaign ownership or rewards.
const INNER_COURT := Vector2(4920, 1040)
const OFFERING_GROVE := Vector2(4010, 1730)
const INNER_ROUTE := [TEMPLE_COURT, Vector2(3620, 970), Vector2(3980, 970), Vector2(4060, 690), Vector2(4600, 690), INNER_COURT]
const RETURN_ROUTE := [INNER_COURT, Vector2(4780, 1670), OFFERING_GROVE, Vector2(3420, 1630), Vector2(3180, 1280), TEMPLE_COURT]
const SANCTUARY_FLOOR := Rect2(4630, 730, 630, 680)
const INNER_RUINS := [Rect2(3820, 840, 120, 110), Rect2(3830, 1060, 110, 110), Rect2(4660, 760, 100, 130), Rect2(5170, 780, 90, 150), Rect2(3900, 1820, 150, 110)]
func _init() -> void:
	super._init()
	map_size.x = 5600
	# A broad broken causeway opens the old eastern bank. All visual and collision water
	# records are carved together, so no invisible bridge or false dry ground is introduced.
	_carve_water(Rect2(3350, 830, 900, 310))
	_carve_water(Rect2(3220, 1420, 1300, 390))
	for basin in [Rect2(3900, 80, 1620, 440), Rect2(5290, 80, 230, 2830), Rect2(3900, 2070, 1620, 840), Rect2(4200, 900, 370, 590)]:
		_rounded_water(basin)
	floor_areas.append({"area": SANCTUARY_FLOOR, "color": Color("999d83"), "height": 0.5})
	for area in INNER_RUINS:
		wall_areas.append({"area": area, "height": 130.0, "visual": false, "minimap_visible": true})

func _rounded_water(area: Rect2) -> void:
	var radius := minf(150.0, minf(area.size.x, area.size.y) * 0.3)
	var y := area.position.y
	while y < area.end.y:
		var depth := minf(40.0, area.end.y - y)
		var edge := minf(y + depth * 0.5 - area.position.y, area.end.y - y - depth * 0.5)
		var inset := radius - sqrt(maxf(0.0, radius * radius - pow(maxf(0.0, radius - edge), 2.0))) if edge < radius else 0.0
		water_areas.append(Rect2(area.position.x + inset, y, area.size.x - 2 * inset, depth))
		y += depth

func _carve_water(dry: Rect2) -> void:
	var previous: Array = water_areas.duplicate()
	water_areas.clear()
	for water in previous:
		if not water.intersects(dry):
			water_areas.append(water)
			continue
		var cut: Rect2 = water.intersection(dry)
		for piece in [Rect2(water.position, Vector2(water.size.x, cut.position.y - water.position.y)), Rect2(Vector2(water.position.x, cut.end.y), Vector2(water.size.x, water.end.y - cut.end.y)), Rect2(Vector2(water.position.x, cut.position.y), Vector2(cut.position.x - water.position.x, cut.size.y)), Rect2(Vector2(cut.end.x, cut.position.y), Vector2(water.end.x - cut.end.x, cut.size.y))]:
			if piece.size.x > 0 and piece.size.y > 0: water_areas.append(piece)

func surface_name(point: Vector2) -> String:
	if SANCTUARY_FLOOR.grow(130).has_point(point): return "안쪽 성소"
	if point.x > 3500 and point.y > 1450: return "뿌리에 잠긴 공양터"
	if point.x > 3400: return "무너진 안쪽 참배길"
	return super.surface_name(point)
