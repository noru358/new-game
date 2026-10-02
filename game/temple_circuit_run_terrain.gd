extends "res://game/temple_circuit_trial_terrain.gd"
const Original = preload("res://game/temple_hybrid_terrain.gd")
const Layout = preload("res://game/temple_circuit_run_layout.gd")
func _init() -> void:
	super._init()
	map_size = Vector2(8700, 3500)
	var original = Original.new()
	for record in original.floor_areas:
		if record.get("discovery_id", "") == "TEMPLE_GARDEN": floor_areas.append(record.duplicate(true))
	for record in original.wall_areas:
		if record.get("discovery_id", "") == "TEMPLE_GARDEN": wall_areas.append(record.duplicate(true))
	water_areas.append(Layout.POND)
	wall_areas.append({"area": preload("res://game/temple_circuit_environment.gd").FOOTPRINT, "height": 554.0, "visual": false})
	wall_areas.append({"area": Rect2(4600, 0, 990, 3500), "height": 200.0, "visual": false})
