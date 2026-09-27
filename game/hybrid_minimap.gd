class_name HybridMinimap
extends Control

const Terrain = preload("res://game/hybrid_terrain.gd")

var arena: Node3D
var refresh_time := 0.0
var cached_projection_limits := Rect2()


func setup(new_arena: Node3D) -> void:
	arena = new_arena
	cached_projection_limits = Rect2()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


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
	var world_size: Vector2 = arena.terrain.map_size
	var ground_outline := PackedVector2Array([
		_map_point_at(Vector2.ZERO, 0.0),
		_map_point_at(Vector2(world_size.x, 0.0), 0.0),
		_map_point_at(world_size, 0.0),
		_map_point_at(Vector2(0.0, world_size.y), 0.0)
	])
	draw_colored_polygon(ground_outline, Color("76988a"))
	for floor in arena.terrain.floor_areas:
		_draw_world_area(floor.area, func(_p): return 0.7, floor.color)
	for water in arena.terrain.water_areas:
		_draw_world_area(water, func(_p): return 1.0, Color("34848d"))
	for plateau in arena.terrain.plateaus:
		_draw_world_area(plateau.area, func(_p): return plateau.height, _height_color(plateau.height))
	for ramp in arena.terrain.ramps:
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
		_draw_world_area(wall.area, func(_p): return wall.height, wall.color)
	for barrier in arena.terrain.barriers():
		if arena.terrain.water_areas.has(barrier):
			continue
		var visible_wall := false
		for wall in arena.terrain.wall_areas:
			if wall.area == barrier:
				visible_wall = true
				break
		if visible_wall:
			continue
		var barrier_height: float = arena.terrain.height_at(barrier.get_center()) + 2.0
		_draw_world_area(barrier, func(_point): return barrier_height, Color("294743"))
	var footprint := camera_ground_footprint()
	if footprint.size() == 4:
		var plane_height: float = arena.terrain.height_at(arena.player.global_position)
		for i in 4:
			draw_line(_map_point_at(footprint[i], plane_height), _map_point_at(footprint[(i + 1) % 4], plane_height), Color(1.0, 1.0, 1.0, 0.9), 1.4)
	for actor in arena.actors:
		if not actor is TrainingEnemy or not is_instance_valid(actor) or actor.is_queued_for_deletion() or actor.health <= 0.0:
			continue
		var color := Color("e89681") if actor.role == TrainingEnemy.Role.BEAST else Color("f2ce71") if actor.role == TrainingEnemy.Role.LAMP else Color("71dcd3") if actor.role == TrainingEnemy.Role.ZONE else Color("c59adf") if actor.role == TrainingEnemy.Role.SUPPORT else Color("dce4d7")
		draw_circle(_map_point(actor.global_position), 2.7, color)
	if is_instance_valid(arena.player):
		draw_circle(_map_point(arena.player.global_position), 4.7, Color("203f44"))
		draw_circle(_map_point(arena.player.global_position), 3.2, Color.WHITE)
	draw_polyline(PackedVector2Array([ground_outline[0], ground_outline[1], ground_outline[2], ground_outline[3], ground_outline[0]]), Color("dceae0"), 1.5)
	var legend := "물 · 중정 · 테라스 · 뜰 · 회랑 · 성소" if world_size.x > 2500.0 else "청록 물 · 금빛 중정 · 밝은 테라스"
	draw_string(get_theme_default_font(), Vector2(12, 208), legend, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("d8e5dc"))


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
	if cached_projection_limits.size.x > 0.0:
		return cached_projection_limits
	var world_size: Vector2 = arena.terrain.map_size
	var first := Vector2(INF, INF)
	var last := Vector2(-INF, -INF)
	for point in [Vector2.ZERO, Vector2(world_size.x, 0.0), world_size, Vector2(0.0, world_size.y)]:
		var projected := _project(point, 0.0)
		first = first.min(projected)
		last = last.max(projected)
	for plateau in arena.terrain.plateaus:
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
