class_name WispFlash
extends Node2D

var blocked := false
var age := 0.0
var duration := 0.20
var power_rank := 0
var sound_offset := 0.0


func _ready() -> void:
	add_to_group("wisp_flashes")
	if not blocked and DisplayServer.get_name() != "headless":
		var audio := AudioStreamPlayer2D.new()
		audio.stream = preload("res://game/audio/wisp_hit.wav")
		audio.volume_db = -13.0 + 1.5 * float(power_rank) + sound_offset
		add_child(audio)
		audio.play()


func setup(travel_direction: Vector2, hit_wall: bool, rank: int = 0, quieter_db: float = 0.0) -> void:
	rotation = travel_direction.angle()
	blocked = hit_wall
	power_rank = rank
	sound_offset = quieter_db
	z_index = 11


func _process(delta: float) -> void:
	age += delta
	if age >= duration:
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	var progress := clampf(age / duration, 0.0, 1.0)
	var fade := 1.0 - progress
	var radius := (5.0 if blocked else 7.0 + 1.5 * float(power_rank)) + progress * (13.0 if blocked else 19.0 + 2.0 * float(power_rank))
	draw_circle(Vector2.ZERO, 12.0 * fade, Color(0.14, 0.75, 1.0, 0.22 * fade))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 22, Color(0.44, 0.91, 1.0, 0.85 * fade), 2.5 * fade)
	draw_circle(Vector2.ZERO, 4.0 * fade + 1.0, Color(0.88, 1.0, 1.0, 0.95 * fade))
	if power_rank > 0 and not blocked:
		draw_arc(Vector2.ZERO, radius * 0.65, 0.0, TAU, 18, Color(0.79, 0.98, 1.0, 0.7 * fade), 1.5 * fade)
	for i in range(5):
		var angle := (float(i) - 2.0) * 0.40
		var ray := Vector2.RIGHT.rotated(angle)
		var start := ray * (5.0 + progress * 7.0)
		var end := ray * (16.0 + progress * (15.0 if blocked else 25.0))
		draw_line(start, end, Color(0.31, 0.84, 1.0, 0.9 * fade), (2.0 if blocked else 2.7) * fade)
	for i in range(3):
		var angle := 2.2 + float(i) * 0.9
		var spark := Vector2.from_angle(angle) * (10.0 + progress * 15.0)
		draw_circle(spark, 1.5 * fade, Color(0.69, 0.97, 1.0, 0.8 * fade))
