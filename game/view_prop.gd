class_name ViewProp
extends StaticBody2D

@export var footprint_radius := 32.0
var pitch := 0.5
var kind := 0


func configure(new_kind: int, new_pitch: float) -> void:
	kind = new_kind
	pitch = new_pitch
	queue_redraw()


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	var shape := CircleShape2D.new()
	shape.radius = footprint_radius
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)


func _draw() -> void:
	var height := (25.0 + pitch * 45.0) if kind == 0 else (12.0 + pitch * 28.0)
	var half_width := footprint_radius * (1.15 if kind == 0 else 1.55)
	var half_depth := half_width * 0.5
	var top := Vector2(0, -height - half_depth)
	var right := Vector2(half_width, -height)
	var bottom := Vector2(0, -height + half_depth)
	var left := Vector2(-half_width, -height)
	var ground_right := Vector2(half_width, 0)
	var ground_bottom := Vector2(0, half_depth)
	var ground_left := Vector2(-half_width, 0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -half_depth + 12), Vector2(half_width + 15, 12),
		Vector2(0, half_depth + 20), Vector2(-half_width - 18, 12)
	]), Color(0.04, 0.12, 0.14, 0.31))
	draw_colored_polygon(PackedVector2Array([right, bottom, ground_bottom, ground_right]), Color("436a6a"))
	draw_colored_polygon(PackedVector2Array([left, bottom, ground_bottom, ground_left]), Color("607d79"))
	draw_colored_polygon(PackedVector2Array([top, right, bottom, left]), Color("b8c5ad"))
	draw_line(left, bottom, Color("d4dabd"), 3.0)
	draw_line(bottom, right, Color("829e8f"), 3.0)
	if kind == 0:
		draw_colored_polygon(PackedVector2Array([
			Vector2(-7, -height + half_depth + 12), Vector2(7, -height + half_depth + 12),
			Vector2(7, half_depth - 9), Vector2(-7, half_depth - 9)
		]), Color("d1ad74"))
