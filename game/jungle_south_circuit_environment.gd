extends RefCounted
static func build(arena: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "SouthernRiverPlaces"
	var builder = preload("res://game/temple_environment_kit.gd").new()
	for surface in [builder._stone, builder._paving, builder._growth, builder._threshold]: surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for wall in arena.terrain.wall_areas:
		if not wall.get("south_masonry", false): continue
		builder._gallery_fragment(wall.area, 0, wall.height, 3)
		builder._reclaim_edges(wall.area, 0, wall.height, 3)
	builder._paving_field(arena.SouthTerrain.TRANSIT_COURT.grow(-6), -0.2, Color("a4a88c"), 220, 210, 7)
	var landing: Rect2 = arena.SouthTerrain.LANDING
	for i in 12:
		var plank := Rect2(landing.position + Vector2(i * 35 + 0.8, 2), Vector2(33.4, landing.size.y - 4))
		builder._block(builder._paving, plank, 40.55, 40.65, Color("8a8264").lightened(0.025 * (i % 3)), i, 0.15)
	for point in [landing.position, Vector2(landing.end.x, landing.position.y), landing.end, Vector2(landing.position.x, landing.end.y)]:
		builder._block(builder._stone, Rect2(point - Vector2(10, 10), Vector2(20, 20)), 0.0, 105.0, Color("5d6651"), 9, 3.0)
	builder._finish_batch(root, builder._stone, "TransitRemnants", 0, true)
	builder._finish_batch(root, builder._growth, "ReclaimedTransitEdges", 2, false)
	builder._finish_batch(root, builder._paving, "TransitCourt", 1, false)
	var groves := preload("res://game/wetland_root_environment.gd").build(arena, arena.SouthTerrain.SOUTH_GROVES)
	groves.name = "RootBendGroves"
	root.add_child(groves)
	return root
