class_name ImpactBurst
extends Node2D

var combo_step := 1
var is_hurt := false
var push_direction := Vector2.RIGHT
var age := 0.0
var duration := 0.18


func setup(step: int, hurt: bool, direction: Vector2) -> void:
	combo_step = step
	is_hurt = hurt
	push_direction = direction.normalized() if direction.length_squared() > 0.0 else Vector2.RIGHT
	duration = 0.24 if step == 4 else 0.22 if hurt or step == 3 else 0.16
	z_index = 10


func _process(delta: float) -> void:
	age += delta
	if age >= duration:
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	var progress := clampf(age / duration, 0.0, 1.0)
	var tone := Color("ff9e91") if is_hurt else Color("fff0b4") if combo_step >= 3 else Color("bdfaff")
	var ring := tone
	ring.a = (1.0 - progress) * (0.7 if is_hurt else 0.8)
	draw_arc(Vector2.ZERO, 7.0 + progress * (37.0 if combo_step == 4 else 30.0 if is_hurt or combo_step == 3 else 22.0), 0.0, TAU, 24, ring, 3.0)
	var core := tone
	core.a = (1.0 - progress) * 0.9
	draw_circle(Vector2.ZERO, 5.5 * (1.0 - progress) + 1.0, core)
	for i in range(5):
		var angle := push_direction.angle() + (float(i) - 2.0) * 0.45
		var ray := Vector2.from_angle(angle)
		var inner := ray * (7.0 + progress * 12.0)
		var outer := ray * (17.0 + progress * (34.0 if combo_step == 4 else 27.0 if combo_step == 3 else 18.0))
		draw_line(inner, outer, ring, 2.5 if combo_step >= 3 else 2.0)
