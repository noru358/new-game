class_name WispChainArc
extends Node2D

var end_point := Vector2.ZERO
var age := 0.0
var duration := 0.17

func _ready() -> void:
	add_to_group("wisp_chain_arcs")


func setup(start: Vector2, finish: Vector2) -> void:
	position = start
	end_point = finish - start
	z_index = 12


func _process(delta: float) -> void:
	age += delta
	if age >= duration:
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	var alpha := 1.0 - age / duration
	var bend := end_point.orthogonal().normalized() * 12.0 * alpha
	var mid := end_point * 0.5 + bend
	draw_line(Vector2.ZERO, mid, Color(0.25, 0.75, 1.0, 0.35 * alpha), 8.0 * alpha)
	draw_line(mid, end_point, Color(0.25, 0.75, 1.0, 0.35 * alpha), 8.0 * alpha)
	draw_line(Vector2.ZERO, mid, Color(0.84, 1.0, 1.0, 0.95 * alpha), 2.5 * alpha)
	draw_line(mid, end_point, Color(0.84, 1.0, 1.0, 0.95 * alpha), 2.5 * alpha)
	draw_circle(end_point, 4.0 * alpha, Color(0.45, 0.9, 1.0, alpha))
