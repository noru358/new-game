extends "res://game/deep_wetland_field_terrain.gd"
const DUEL := Rect2(4600,600,850,1150)
func _init() -> void:
	super._init()
	_carve_water(DUEL.grow(30))
	floor_areas = floor_areas.filter(func(floor): return floor.area != SANCTUARY_FLOOR)
	floor_areas.append({"area":DUEL,"height":0.5,"color":Color("999d83")})
	wall_areas = wall_areas.filter(func(wall): return not wall.area.intersects(DUEL.grow(30)))

	for wall in wall_areas:
		if not wall.has("color"): wall["color"] = Color("85927a")
