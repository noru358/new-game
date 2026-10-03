extends RefCounted
## Southeast Asia -> jungle -> waterfall threshold / receiving pool / small shrine.
## Field-only records. Main waterfall rims and all transition coordinates retain
## their existing geometry. Visuals consume these same collision/minimap records.
const FIELD := Rect2(6000, 80, 4200, 2800)
const SHOULDER := Rect2(6700, 2320, 280, 140)
const BACK := Rect2(9480, 80, 560, 140)

static func install(terrain) -> void:
	for wall in terrain.wall_areas:
		if wall.get("discovery_id", "") != "JUNGLE_GROTTO" or not FIELD.encloses(wall.area): continue
		wall["visual"] = false
		wall["minimap_visible"] = true
		wall["hidden_rock"] = true
		wall["color"] = Color("7d8d7b") if wall.get("foreground_edge", false) else Color("667969")
	for spec in [[SHOULDER, 228.0, "threshold"], [BACK, 190.0, "shrine"]]:
		# Entire footprints already belong to the rock bank. These introduce no
		# invisible obstacle across the passage, first clearing or reward approach.
		terrain.wall_areas.append({"area":spec[0], "base":0.0, "height":spec[1], "visual":false, "minimap_visible":true, "discovery_id":"JUNGLE_GROTTO", "hidden_landmark":spec[2], "color":Color("798574")})
	for floor in terrain.floor_areas:
		if floor.get("discovery_id", "") != "JUNGLE_GROTTO": continue
		floor["height"] = 0.45
		if floor.area == FIELD:
			floor["color"] = Color("657b65")
			floor["height"] = 0.15
		elif floor.area.position.x < 7040 and floor.area.position.y > 2400: floor["color"] = Color("78877c")
		elif floor.area.position.x > 9400 and floor.area.position.y < 700: floor["color"] = Color("b0b19a")
		else: floor["color"] = Color("99a88b")
