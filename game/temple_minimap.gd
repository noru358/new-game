class_name TempleMinimap
extends Control

var region: Node2D
var refresh_time := 0.0


func setup(new_region: Node2D) -> void:
	region = new_region
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	refresh_time -= delta
	if refresh_time <= 0.0:
		refresh_time = 0.08
		queue_redraw()


func _draw() -> void:
	if not is_instance_valid(region):
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("b7cdb8"))
	_draw_plaza(region.WEST_COURT_CENTER, region.WEST_COURT_HALF.x, region.WEST_COURT_HALF.y, Color("cdd2bb"))
	_draw_plaza(Vector2(1830, 1080), 820.0, 385.0, Color("ebd5a8"))
	_draw_plaza(Vector2(3130, 1080), 400.0, 280.0, Color("e8d3a3"))
	_draw_plaza(region.UPPER_TERRACE_CENTER, region.UPPER_TERRACE_HALF.x, region.UPPER_TERRACE_HALF.y, Color("f3eacb"))
	for i in range(region.WATER_AREAS.size()):
		var world_points: PackedVector2Array = region.rotated_rect_points(region.WATER_AREAS[i], region.WATER_ANGLES[i])
		draw_colored_polygon(_map_points(world_points), Color("388c94"))
	for i in range(region.WALL_AREAS.size()):
		var world_points: PackedVector2Array = region.rotated_rect_points(region.WALL_AREAS[i], region.WALL_ANGLES[i])
		draw_colored_polygon(_map_points(world_points), Color("526d68"))
	for prop in region.view_props:
		if prop is ViewProp:
			var footprint := _map_point(prop.global_position)
			draw_rect(Rect2(footprint - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), Color("65716a"))
	var view_size: Vector2 = Vector2(1280, 720) / region.camera.zoom
	var view_center: Vector2 = region.camera.get_screen_center_position()
	var world_view := Rect2(view_center - view_size * 0.5, view_size)
	draw_rect(_map_rect(world_view), Color(1.0, 1.0, 1.0, 0.78), false, 1.6)
	for enemy in region.get_node("Enemies").get_children():
		if not enemy is TrainingEnemy or enemy.is_queued_for_deletion() or enemy.health <= 0.0:
			continue
		var color := Color("c94e48") if enemy.role == TrainingEnemy.Role.BEAST else Color("e6b650") if enemy.role == TrainingEnemy.Role.LAMP else Color("4cc9c6") if enemy.role == TrainingEnemy.Role.ZONE else Color("c38ce4") if enemy.role == TrainingEnemy.Role.SUPPORT else Color("596d74")
		draw_circle(_map_point(enemy.global_position), 3.2, color)
	var player_point := _map_point(region.player.global_position)
	draw_circle(player_point, 5.4, Color("ffffff"))
	draw_circle(player_point, 3.4, Color("147e89"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("e7eee0"), false, 2.0)


func _map_point(world_point: Vector2) -> Vector2:
	return Vector2(world_point.x / region.REGION_SIZE.x * size.x, world_point.y / region.REGION_SIZE.y * size.y)


func _map_rect(world_rect: Rect2) -> Rect2:
	return Rect2(_map_point(world_rect.position), Vector2(world_rect.size.x / region.REGION_SIZE.x * size.x, world_rect.size.y / region.REGION_SIZE.y * size.y))


func _map_points(world_points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in world_points:
		result.append(_map_point(point))
	return result


func _draw_plaza(center: Vector2, half_width: float, half_height: float, color: Color) -> void:
	draw_colored_polygon(_map_points(PackedVector2Array([
		center + Vector2(0, -half_height), center + Vector2(half_width, 0),
		center + Vector2(0, half_height), center + Vector2(-half_width, 0)
	])), color)
