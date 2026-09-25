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
	var half_width := footprint_radius if kind == 0 else footprint_radius * 1.55
	var top_depth := lerpf(footprint_radius * 0.82, footprint_radius * 0.38, pitch)
	var stone := Color("99b1a9") if kind == 0 else Color("9ba89d")
	var front := Color("607d79") if kind == 0 else Color("667c72")
	var side := Color("3d6268")
	var cap := Color("c9d3b2")
	draw_colored_polygon(PackedVector2Array([
		Vector2(-half_width - 13, 4), Vector2(half_width + 13, 4),
		Vector2(half_width + 22, 17), Vector2(-half_width - 20, 17)
	]), Color(0.04, 0.12, 0.14, 0.35))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-half_width, -height), Vector2(half_width, -height),
		Vector2(half_width, top_depth), Vector2(-half_width, top_depth)
	]), front)
	draw_colored_polygon(PackedVector2Array([
		Vector2(half_width, -height), Vector2(half_width + 11, -height - 9),
		Vector2(half_width + 11, top_depth - 9), Vector2(half_width, top_depth)
	]), side)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-half_width, -height), Vector2(-half_width + 11, -height - top_depth),
		Vector2(half_width + 11, -height - top_depth), Vector2(half_width, -height)
	]), stone)
	draw_line(Vector2(-half_width + 4, -height + 5), Vector2(half_width - 4, -height + 5), cap, 3.0)
	draw_line(Vector2(-half_width + 4, top_depth - 5), Vector2(half_width - 4, top_depth - 5), Color("344e55"), 3.0)
	if kind == 0:
		draw_rect(Rect2(-7, -height + 16, 14, 18), Color("d1ad74"))
