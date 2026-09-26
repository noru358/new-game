class_name ExperienceOrb
extends Node2D

signal collected(amount: int)

var value := 1
var player: SandboxPlayer
var age := 0.0


func setup(amount: int, target: SandboxPlayer) -> void:
	value = amount
	player = target
	z_index = 2
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or player.health <= 0.0:
		return
	age += delta
	var distance := global_position.distance_to(player.global_position)
	if distance < 22.0:
		collected.emit(value)
		queue_free()
		return
	if distance < 145.0:
		var speed := lerpf(360.0, 650.0, 1.0 - distance / 145.0)
		global_position = global_position.move_toward(player.global_position, speed * delta)
	queue_redraw()


func _draw() -> void:
	var bob := sin(age * 6.0) * 3.0
	var point := Vector2(0.0, bob)
	draw_circle(point, 12.0, Color(0.34, 0.88, 0.77, 0.17))
	draw_colored_polygon(PackedVector2Array([
		point + Vector2(0, -9), point + Vector2(7, 0),
		point + Vector2(0, 9), point + Vector2(-7, 0)
	]), Color("6be6bc"))
	draw_circle(point, 2.4, Color("e8fff4"))
