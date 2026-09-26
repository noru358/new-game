class_name TempleBlock
extends StaticBody2D

var footprint_size := Vector2(100, 40)
var water := false


func setup(area: Rect2, is_water: bool) -> void:
	global_position = area.get_center()
	footprint_size = area.size
	water = is_water
	queue_redraw()


func navigation_rect() -> Rect2:
	return Rect2(global_position - footprint_size * 0.5, footprint_size)


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = footprint_size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)


func _draw() -> void:
	if water:
		return
	var half := footprint_size * 0.5
	var top := Rect2(-half - Vector2(0, 20), footprint_size)
	draw_rect(Rect2(-half, footprint_size), Color("5e7773"))
	draw_rect(top, Color("bac8b0"))
	draw_line(Vector2(-half.x, top.position.y), Vector2(half.x, top.position.y), Color("e2ddbd"), 4.0)
	draw_line(Vector2(-half.x, half.y), Vector2(half.x, half.y), Color("3d6767"), 3.0)
