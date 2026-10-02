class_name HybridMinimap
extends Control

const Terrain = preload("res://game/hybrid_terrain.gd")

var arena: Node3D
var refresh_time := 0.0
var cached_projection_limits := Rect2()
var cached_bounds := Rect2()


func setup(new_arena: Node3D) -> void:
	arena = new_arena
	cached_projection_limits = Rect2()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(func(): cached_projection_limits = Rect2())


func _process(delta: float) -> void:
	refresh_time -= delta
	if refresh_time <= 0.0:
		refresh_time = 0.08
		queue_redraw()


func _draw() -> void:
	if not is_instance_valid(arena):
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.13, 0.15, 0.91))
	draw_string(get_theme_default_font(), Vector2(12, 22), "높이·동선", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("e9eee4"))
	var bounds: Rect2 = arena.display_bounds()
	var world_size: Vector2 = bounds.size
	var ground_outline := PackedVector2Array([
		_map_point_at(bounds.position, 0.0),
		_map_point_at(Vector2(bounds.end.x, bounds.position.y), 0.0),
		_map_point_at(bounds.end, 0.0),
		_map_point_at(Vector2(bounds.position.x, bounds.end.y), 0.0)
	])
	draw_colored_polygon(ground_outline, Color("76988a"))
	for floor in arena.terrain.floor_areas:
		if not bounds.intersects(floor.area): continue
		if not _discovered_geometry(floor): continue
		_draw_world_area(floor.area, func(_p): return float(floor.get("height", 0.7)), floor.color)
	for water in arena.terrain.water_areas:
		if not bounds.intersects(water): continue
		_draw_world_area(water, func(_p): return 1.0, Color("34848d"))
	for chasm in arena.terrain.chasm_areas:
		if not bounds.intersects(chasm): continue
		_draw_world_area(chasm, func(_p): return 1.5, Color("263e3d"))
	for plateau in arena.terrain.plateaus:
		if not bounds.intersects(plateau.area): continue
		_draw_world_area(plateau.area, func(_p): return plateau.height, _height_color(plateau.height))
	for ramp in arena.terrain.ramps:
		if not bounds.intersects(ramp.area): continue
		var area: Rect2 = ramp.area
		var pieces: int = Terrain.STONE_COUNT if ramp.get("kind", "") == "stepping_stones" else 10
		for i in pieces:
			var piece := area
			piece.position[ramp.axis] += area.size[ramp.axis] * float(i) / pieces
			piece.size[ramp.axis] = area.size[ramp.axis] / pieces
			var middle := piece.get_center()
			_draw_world_area(piece, func(point): return arena.terrain.ramp_height(ramp, point), _height_color(arena.terrain.ramp_height(ramp, middle)))
		if ramp.get("kind", "") == "stepping_stones":
			for i in range(1, Terrain.STONE_COUNT):
				var seam: float = area.position.y + area.size.y * float(i) / Terrain.STONE_COUNT
				var first := Vector2(area.position.x, seam)
				var last := Vector2(area.end.x, seam)
				draw_line(_map_point_at(first, arena.terrain.ramp_height(ramp, first)), _map_point_at(last, arena.terrain.ramp_height(ramp, last)), Color("244742"), 1.1)
	for wall in arena.terrain.wall_areas:
		if not _wall_visible(wall, bounds): continue
		if wall.get("collidable", true):
			_draw_world_area(wall.area, func(_p): return wall.height, wall.color)
	for plateau in arena.terrain.plateaus:
		if not bounds.intersects(plateau.area): continue
		for edge in arena.terrain.plateau_edge_spans(plateau):
			var horizontal: bool = edge.side == "north" or edge.side == "south"
			var a := Vector2(edge.start, edge.fixed) if horizontal else Vector2(edge.fixed, edge.start)
			var b := Vector2(edge.end, edge.fixed) if horizontal else Vector2(edge.fixed, edge.end)
			draw_line(_map_point_at(a, plateau.height), _map_point_at(b, plateau.height), Color("354c47"), 1.3)
	for ramp in arena.terrain.ramps:
		if not bounds.intersects(ramp.area): continue
		var area: Rect2 = ramp.area
		for edge in [0, 1]:
			var a := Vector2(area.position.x, area.position.y if edge == 0 else area.end.y) if ramp.axis == 0 else Vector2(area.position.x if edge == 0 else area.end.x, area.position.y)
			var b := Vector2(area.end.x, a.y) if ramp.axis == 0 else Vector2(a.x, area.end.y)
			draw_line(_map_point_at(a, arena.terrain.ramp_height(ramp, a)), _map_point_at(b, arena.terrain.ramp_height(ramp, b)), Color("354c47"), 1.1)
	var legend := "물 · 중정 · 테라스 · 뜰 · 회랑 · 성소" if world_size.x > 2500.0 else "청록 물 · 금빛 중정 · 밝은 테라스"
	if bounds.position.x > 5100:
		legend = "물길 · 바위 갈림길 · 안쪽 유적" if arena.region_id == RunProfile.JUNGLE_REGION else "굽은 진입로 · 연못 갈림길 · 안쪽 제단"
	draw_string(get_theme_default_font(), Vector2(12, 208), legend, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("d8e5dc"))
	var footprint := camera_ground_footprint()
	if footprint.size() == 4:
		var plane_height: float = arena.terrain.height_at(arena.player.global_position)
		for i in 4:
			draw_line(_map_point_at(footprint[i], plane_height), _map_point_at(footprint[(i + 1) % 4], plane_height), Color(1.0, 1.0, 1.0, 0.9), 1.4)
	for actor in arena.actors:
		if not is_instance_valid(actor) or not actor is TrainingEnemy or actor.is_queued_for_deletion() or actor.health <= 0.0:
			continue
		if not bounds.has_point(actor.global_position): continue
		var color := Color("e89681") if actor.role == TrainingEnemy.Role.BEAST else Color("f2ce71") if actor.role == TrainingEnemy.Role.LAMP else Color("71dcd3") if actor.role == TrainingEnemy.Role.ZONE else Color("c59adf") if actor.role == TrainingEnemy.Role.SUPPORT else Color("dce4d7")
		draw_circle(_map_point(actor.global_position), 2.7, color)
	if arena.has_method("is_place_discovered") and arena.region_id == RunProfile.TEMPLE_REGION and arena.is_place_discovered("TEMPLE_GARDEN"):
		var garden_point := _map_point(Vector2(3120, 250)) if bounds.position.x < 5100 else _map_point(Vector2(8300, 480))
		draw_circle(garden_point, 3.5, Color("b6f3a0"))
		draw_string(get_theme_default_font(), garden_point + Vector2(5, -5), "정원", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("ddffd0"))
	if arena.has_method("is_place_discovered") and arena.region_id == RunProfile.JUNGLE_REGION and arena.is_place_discovered("JUNGLE_GROTTO"):
		var point := _map_point(Vector2(1300, 685)) if bounds.position.x < 5600 else _map_point(Vector2(8870, 440))
		draw_circle(point, 3.5, Color("a1e8e7"))
		draw_string(get_theme_default_font(), point + Vector2(5, -5), "계곡", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("c5f5ef"))
	if is_instance_valid(arena.player):
		draw_circle(_map_point(arena.player.global_position), 4.7, Color("203f44"))
		draw_circle(_map_point(arena.player.global_position), 3.2, Color.WHITE)
	draw_polyline(PackedVector2Array([ground_outline[0], ground_outline[1], ground_outline[2], ground_outline[3], ground_outline[0]]), Color("dceae0"), 1.5)


func _discovered_geometry(record: Dictionary) -> bool:
	return not record.has("discovery_id") or (arena.has_method("is_place_discovered") and arena.is_place_discovered(String(record.discovery_id)))


func _draw_world_area(area: Rect2, elevation: Callable, color: Color) -> void:
	var corners := [area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)]
	var polygon := PackedVector2Array()
	for point in corners:
		polygon.append(_map_point_at(point, elevation.call(point)))
	draw_colored_polygon(polygon, color)


func _project(point: Vector2, height: float) -> Vector2:
	# Orthographic camera axes give the map exactly the same diamond pitch and
	# left/right directions as the gameplay view, independent of camera travel.
	var world := Vector3(point.x, height, point.y) * Terrain.SCALE
	var basis: Basis = arena.camera.global_transform.basis
	return Vector2(world.dot(basis.x), -world.dot(basis.y))


func _projection_limits() -> Rect2:
	if cached_bounds != arena.display_bounds():
		cached_bounds = arena.display_bounds()
		cached_projection_limits = Rect2()
	if cached_projection_limits.size.x > 0.0:
		return cached_projection_limits
	var bounds: Rect2 = arena.display_bounds()
	var world_size: Vector2 = bounds.size
	var first := Vector2(INF, INF)
	var last := Vector2(-INF, -INF)
	for point in [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]:
		var projected := _project(point, 0.0)
		first = first.min(projected)
		last = last.max(projected)
	for plateau in arena.terrain.plateaus:
		if not bounds.intersects(plateau.area): continue
		var area: Rect2 = plateau.area
		for point in [area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)]:
			var projected := _project(point, plateau.height)
			first = first.min(projected)
			last = last.max(projected)
	cached_projection_limits = Rect2(first, last - first)
	return cached_projection_limits


func _map_point_at(point: Vector2, height: float) -> Vector2:
	var limits := _projection_limits()
	var display := Rect2(Vector2(12.0, 32.0), size - Vector2(24.0, 49.0))
	var scale: float = minf(display.size.x / limits.size.x, display.size.y / limits.size.y)
	return display.get_center() + (_project(point, height) - limits.get_center()) * scale


func _map_point(point: Vector2) -> Vector2:
	return _map_point_at(point, arena.terrain.height_at(point))


func _height_color(height: float) -> Color:
	if height <= 160.0:
		return Color("76988a").lerp(Color("cbbb8c"), clampf(height / 160.0, 0.0, 1.0))
	return Color("cbbb8c").lerp(Color("eee0b9"), clampf((height - 160.0) / 160.0, 0.0, 1.0))


func camera_ground_footprint() -> PackedVector2Array:
	var result := PackedVector2Array()
	if not is_instance_valid(arena) or not is_instance_valid(arena.camera) or not is_instance_valid(arena.player):
		return result
	var view: Vector2 = get_viewport_rect().size
	var plane_y: float = arena.terrain.height_at(arena.player.global_position) * Terrain.SCALE
	for pixel in [Vector2.ZERO, Vector2(view.x, 0.0), view, Vector2(0.0, view.y)]:
		var origin: Vector3 = arena.camera.project_ray_origin(pixel)
		var direction: Vector3 = arena.camera.project_ray_normal(pixel)
		if absf(direction.y) < 0.001:
			return PackedVector2Array()
		var world: Vector3 = origin + direction * ((plane_y - origin.y) / direction.y)
		result.append(Vector2(world.x, world.z) / Terrain.SCALE)
	return result

func _wall_visible(wall: Dictionary, bounds: Rect2) -> bool:
	# Mesh replacement may hide only the primitive, not the obstacle on the map.
	return bool(wall.get("minimap_visible", wall.get("visual", true))) and bounds.intersects(wall.area) and _discovered_geometry(wall)
