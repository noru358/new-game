class_name HybridMinimap
extends Control

const Terrain = preload("res://game/hybrid_terrain.gd")

var arena: Node3D
var refresh_time := 0.0


func setup(new_arena: Node3D) -> void:
	arena = new_arena
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
	var map := _map_bounds()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.13, 0.15, 0.91))
	draw_string(get_theme_default_font(), Vector2(12, 22), "높이·동선", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("e9eee4"))
	draw_rect(map, Color("76988a"))
	for water in arena.terrain.water_areas:
		_draw_world_rect(water, Color("34848d"))
	for plateau in arena.terrain.plateaus:
		_draw_world_rect(plateau.area, _height_color(plateau.height))
	for ramp in arena.terrain.ramps:
		var area: Rect2 = ramp.area
		var pieces: int = Terrain.STONE_COUNT if ramp.get("kind", "") == "stepping_stones" else 10
		for i in pieces:
			var piece := area
			piece.position[ramp.axis] += area.size[ramp.axis] * float(i) / pieces
			piece.size[ramp.axis] = area.size[ramp.axis] / pieces
			var middle := piece.get_center()
			_draw_world_rect(piece, _height_color(arena.terrain.ramp_height(ramp, middle)))
		if ramp.get("kind", "") == "stepping_stones":
			for i in range(1, Terrain.STONE_COUNT):
				var seam := area.position.y + area.size.y * float(i) / Terrain.STONE_COUNT
				_draw_world_line(Vector2(area.position.x, seam), Vector2(area.end.x, seam), Color("244742"), 1.1)
	for barrier in arena.terrain.barriers():
		if arena.terrain.water_areas.has(barrier):
			continue
		_draw_world_rect(barrier, Color("294743"), 1.4)
	var footprint := camera_ground_footprint()
	if footprint.size() == 4:
		for i in 4:
			_draw_world_line(footprint[i], footprint[(i + 1) % 4], Color(1.0, 1.0, 1.0, 0.9), 1.4)
	for actor in arena.actors:
		if not actor is TrainingEnemy or not is_instance_valid(actor) or actor.is_queued_for_deletion() or actor.health <= 0.0:
			continue
		var color := Color("e89681") if actor.role == TrainingEnemy.Role.BEAST else Color("f2ce71") if actor.role == TrainingEnemy.Role.LAMP else Color("71dcd3") if actor.role == TrainingEnemy.Role.ZONE else Color("c59adf") if actor.role == TrainingEnemy.Role.SUPPORT else Color("dce4d7")
		draw_circle(_map_point(actor.global_position), 2.7, color)
	if is_instance_valid(arena.player):
		draw_circle(_map_point(arena.player.global_position), 4.7, Color("203f44"))
		draw_circle(_map_point(arena.player.global_position), 3.2, Color.WHITE)
	draw_rect(map, Color("dceae0"), false, 1.5)
	draw_string(get_theme_default_font(), Vector2(12, 208), "청록 물  ·  금빛 중정  ·  밝은 테라스", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("d8e5dc"))


func _map_bounds() -> Rect2:
	var scale: float = minf((size.x - 24.0) / Terrain.SIZE.x, (size.y - 53.0) / Terrain.SIZE.y)
	var extent: Vector2 = Terrain.SIZE * scale
	return Rect2(Vector2((size.x - extent.x) * 0.5, 34.0), extent)


func _map_point(point: Vector2) -> Vector2:
	var map := _map_bounds()
	return map.position + Vector2(point.x / Terrain.SIZE.x * map.size.x, point.y / Terrain.SIZE.y * map.size.y)


func _draw_world_rect(world: Rect2, color: Color, minimum_width: float = 0.0) -> void:
	var first := _map_point(world.position)
	var last := _map_point(world.end)
	draw_rect(Rect2(first, Vector2(maxf(last.x - first.x, minimum_width), maxf(last.y - first.y, minimum_width))), color)


func _draw_world_line(first: Vector2, last: Vector2, color: Color, width: float) -> void:
	var map := _map_bounds()
	var a := _map_point(first).clamp(map.position, map.end)
	var b := _map_point(last).clamp(map.position, map.end)
	if a.distance_squared_to(b) > 0.01:
		draw_line(a, b, color, width)


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
