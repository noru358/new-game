class_name TrainingEnemy
extends CharacterBody2D

signal defeated

const MAX_HEALTH := 22.0
const MOVE_SPEED := 105.0
const CONTACT_DAMAGE := 10.0
const RADIUS := 17.0
const GATHER_DURATION := 0.12

@export var max_health := MAX_HEALTH

var health := MAX_HEALTH
var target: Node2D
var knockback := Vector2.ZERO
var hit_flash := 0.0
var stagger_time := 0.0
var gather_origin := Vector2.ZERO
var gather_target := Vector2.ZERO
var gather_elapsed := 0.0
var gathering := false


func _ready() -> void:
	health = max_health
	add_to_group("training_enemies")


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	hit_flash = maxf(0.0, hit_flash - delta)
	stagger_time = maxf(0.0, stagger_time - delta)
	if gathering:
		gather_elapsed = minf(GATHER_DURATION, gather_elapsed + delta)
		var fraction := gather_elapsed / GATHER_DURATION
		var eased := fraction * fraction * (3.0 - 2.0 * fraction)
		global_position = gather_origin.lerp(gather_target, eased)
		velocity = Vector2.ZERO
		if gather_elapsed >= GATHER_DURATION:
			gathering = false
	else:
		knockback = knockback.move_toward(Vector2.ZERO, 900.0 * delta)
		var chase := Vector2.ZERO if stagger_time > 0.0 else global_position.direction_to(target.global_position) * MOVE_SPEED
		velocity = chase + knockback
		move_and_slide()
	global_position = Vector2(
		clampf(global_position.x, 24.0, 2376.0),
		clampf(global_position.y, 24.0, 1376.0)
	)
	if global_position.distance_to(target.global_position) <= RADIUS + 18.0:
		target.receive_hit(CONTACT_DAMAGE, global_position)
	queue_redraw()


func take_hit(damage: float, push_direction: Vector2, is_finisher: bool) -> void:
	gathering = false
	health -= damage
	hit_flash = 0.19
	stagger_time = 0.15 if is_finisher else 0.09
	knockback = push_direction * (300.0 if is_finisher else 170.0)
	if health <= 0.0:
		defeated.emit()
		queue_free()
	else:
		queue_redraw()


func gather_to(point: Vector2) -> void:
	gather_origin = global_position
	gather_target = point
	gather_elapsed = 0.0
	gathering = true
	knockback = Vector2.ZERO
	stagger_time = maxf(stagger_time, 0.38)


func _draw() -> void:
	var reinforced := max_health > MAX_HEALTH
	var stone := Color("edf6e8") if hit_flash > 0.0 else Color("9aa8c7") if reinforced else Color("8bada0")
	var shade := Color("3c5d61")
	draw_circle(Vector2(0, 7), 20.0, Color(0.02, 0.09, 0.11, 0.35))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-17, 9), Vector2(-12, -13), Vector2(0, -21),
		Vector2(16, -11), Vector2(18, 9), Vector2(3, 18)
	]), shade)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, 5), Vector2(-8, -12), Vector2(1, -17),
		Vector2(12, -9), Vector2(13, 6), Vector2(1, 12)
	]), stone)
	draw_line(Vector2(-7, -4), Vector2(8, 4), Color("295665"), 3.0)
	draw_circle(Vector2(-4, -2), 2.0, Color("f9c06f") if reinforced else Color("42d9d4"))
	draw_circle(Vector2(7, 0), 2.0, Color("f9c06f") if reinforced else Color("42d9d4"))
	draw_rect(Rect2(-18, -32, 36, 4), Color(0.05, 0.16, 0.18, 0.8))
	draw_rect(Rect2(-18, -32, 36.0 * maxf(health, 0.0) / max_health, 4), Color("f9c06f") if reinforced else Color("8ce2bc"))
