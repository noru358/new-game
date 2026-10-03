extends "res://game/temple_environment_kit.gd"
## A low ruined riverbank marker, sharing the existing parapet's collision data.
const RouteTerrain = preload("res://game/jungle_route_terrain.gd")

static func build(arena: Node3D) -> Node3D:
	return load("res://game/jungle_route_environment.gd").new()._build(arena)

func _build(arena: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "JungleRiverRemnant"
	_stone.begin(Mesh.PRIMITIVE_TRIANGLES)
	_growth.begin(Mesh.PRIMITIVE_TRIANGLES)
	_paving.begin(Mesh.PRIMITIVE_TRIANGLES)
	for wall in arena.terrain.wall_areas:
		if wall.area != RouteTerrain.RIVER_REMNANT: continue
		_gallery_fragment(wall.area, wall.base, wall.height, 1)
		_reclaim_edges(wall.area, wall.base, wall.height, 1)
		root.set_meta("source_wall", wall.duplicate())
	# Low, worn landing courses leave a broad unblocked center facing the water.
	_paving_field(Rect2(2980, 2070, 185, 58), 81.7, Color("a5af97"), 72, 58, 2)
	_paving_field(Rect2(2930, 2135, 235, 48), 81.7, Color("8c9d87"), 82, 48, 4)
	# Flat dressing follows the existing ramp, rather than a new raised ledge.
	_slope_courses(arena, RouteTerrain.GATE_SIGHT_FLOOR)
	_finish_batch(root, _stone, "BrokenBankMasonry", 0, true)
	_finish_batch(root, _paving, "WornLandingAndSightCourses", 1, false)
	_finish_batch(root, _growth, "LowBankGrowth", 2, false)
	root.set_meta("region_hierarchy", ["동남아", "중간 권역 미정·추가 없음", "정글 절벽 관문", "물가 쉼터→북측 잔해→관문 조망", "낮은 포장·기존 석재/식생 군집·빈 통행 공간"])
	root.set_meta("places", RouteTerrain.PLACES.duplicate(true))
	root.set_meta("visual_bounds", Rect2(2930, 1560, 1410, 670))
	root.set_meta("max_floor_lift", 2.55)
	return root

func _slope_courses(arena: Node3D, area: Rect2) -> void:
	for row in 5:
		for column in 3:
			if (row + column) % 4 == 0: continue
			var slab := Rect2(area.position + Vector2(column * 80 + 2, row * 54 + 2), Vector2(75, 48))
			var corners := [slab.position, Vector2(slab.end.x, slab.position.y), slab.end, Vector2(slab.position.x, slab.end.y)]
			var vertices: Array[Vector3] = []
			for point in corners: vertices.append(Vector3(point.x, arena.terrain.height_at(point) + 1.7, point.y))
			_quad(_paving, vertices[0], vertices[1], vertices[2], vertices[3], Color("9da790").lightened(0.02 * (row % 2)))
