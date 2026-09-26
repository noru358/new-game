class_name WispProjectile
extends Node2D

signal enemy_hit(enemy: TrainingEnemy)

var direction := Vector2.RIGHT
var speed := 620.0
var maximum_distance := 520.0
var damage := 6.5
var distance_traveled := 0.0
var age := 0.0


func setup(new_direction: Vector2, new_speed: float, new_range: float, new_damage: float) -> void:
	direction = new_direction.normalized()
	speed = new_speed
	maximum_distance = new_range
	damage = new_damage
	z_index = 5


func _physics_process(delta: float) -> void:
	var remaining := maximum_distance - distance_traveled
	if remaining <= 0.0:
		queue_free()
		return
	var travel := minf(speed * delta, remaining)
	var destination := global_position + direction * travel
	var query := PhysicsRayQueryParameters2D.create(global_position, destination, 6)
	query.hit_from_inside = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position
		if hit.collider is TrainingEnemy and not hit.collider.is_queued_for_deletion():
			var enemy: TrainingEnemy = hit.collider
			enemy.take_hit(damage, direction, false)
			enemy_hit.emit(enemy)
			var burst := ImpactBurst.new()
			burst.setup(1, false, direction)
			get_parent().add_child(burst)
			burst.global_position = global_position
		queue_free()
		return
	global_position = destination
	distance_traveled += travel
	age += delta
	queue_redraw()


func _draw() -> void:
	var tail := -direction * (12.0 + sin(age * 18.0) * 2.0)
	draw_line(tail, Vector2.ZERO, Color(0.42, 0.91, 0.88, 0.6), 5.0)
	draw_circle(Vector2.ZERO, 7.0, Color(0.42, 0.91, 0.88, 0.3))
	draw_circle(Vector2.ZERO, 4.0, Color("fff0b4"))
