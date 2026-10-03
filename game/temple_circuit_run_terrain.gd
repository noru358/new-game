extends "res://game/temple_circuit_trial_terrain.gd"
const Original = preload("res://game/temple_hybrid_terrain.gd")
const Layout = preload("res://game/temple_circuit_run_layout.gd")
func _init() -> void:
	super._init()
	for wall in wall_areas:
		wall["circuit_masonry"] = true
		wall["visual"] = false
		wall["minimap_visible"] = true
	# A low raised central court creates three readable approaches within the loop.
	plateaus = [{"area": Rect2(1870, 1600, 990, 1150), "height": 120.0, "base": 0.0, "name": "높은 중심 뜰", "openings": {"west": [[2100.0, 2450.0]], "north": [[2180.0, 2500.0]], "east": [[2240.0, 2540.0]]}}]
	ramps = [
		{"area": Rect2(1470, 2100, 400, 350), "axis": 0, "from": 0.0, "to": 120.0, "name": "뜰 서쪽 넓은 계단"},
		{"area": Rect2(2180, 1200, 320, 400), "axis": 1, "from": 0.0, "to": 120.0, "name": "회랑 위뜰 계단"},
		{"area": Rect2(2860, 2240, 400, 300), "axis": 0, "from": 120.0, "to": 0.0, "name": "물가 내리막"},
	]
	for floor in floor_areas:
		if floor.area == plateaus[0].area: floor["height"] = 120.5
	map_size = Vector2(8700, 3500)
	var original = Original.new()
	for record in original.floor_areas:
		if record.get("discovery_id", "") == "TEMPLE_GARDEN": floor_areas.append(record.duplicate(true))
	for record in original.wall_areas:
		if record.get("discovery_id", "") == "TEMPLE_GARDEN": wall_areas.append(record.duplicate(true))
	water_areas.append(Layout.POND)
	wall_areas.append({"area": preload("res://game/temple_circuit_environment.gd").FOOTPRINT, "height": 554.0, "visual": false})
	wall_areas.append({"area": preload("res://game/temple_monument_scale.gd").NORTH_FOOTPRINT, "height": 655.8, "visual": false})
	wall_areas.append({"area": Rect2(4600, 0, 990, 3500), "height": 200.0, "visual": false})

func height_at(point: Vector2) -> float:
	for ramp in ramps:
		if ramp.area.has_point(point): return ramp_height(ramp, point)
	for plateau in plateaus:
		if plateau.area.has_point(point): return float(plateau.height)
	return 0.0

func surface_name(point: Vector2) -> String:
	for ramp in ramps:
		if ramp.area.has_point(point): return ramp.name
	if plateaus[0].area.has_point(point): return "높은 중심 뜰"
	return super.surface_name(point)
