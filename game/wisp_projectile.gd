class_name WispProjectile
extends Node2D

signal enemy_hit(enemy: TrainingEnemy)

const FlashScript = preload("res://game/wisp_flash.gd")
const ChainArcScript = preload("res://game/wisp_chain_arc.gd")

var direction := Vector2.RIGHT
var speed := 620.0
var maximum_distance := 520.0
var damage := 6.5
var distance_traveled := 0.0
var age := 0.0
var trail_points: Array[Vector2] = []
var chain_jumps := 0


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
	trail_points.append(global_position)
	if trail_points.size() > 5:
		trail_points.pop_front()
	var query := PhysicsRayQueryParameters2D.create(global_position, destination, 6)
	query.hit_from_inside = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position
		var flash: Node2D = FlashScript.new()
		flash.setup(direction, not hit.collider is TrainingEnemy)
		flash.process_mode = Node.PROCESS_MODE_PAUSABLE
		get_parent().add_child(flash)
		flash.global_position = global_position
		if hit.collider is TrainingEnemy and not hit.collider.is_queued_for_deletion():
			var enemy: TrainingEnemy = hit.collider
			enemy.take_hit(damage, direction, false)
			enemy_hit.emit(enemy)
			if chain_jumps > 0:
				_chain_from(enemy)
		queue_free()
		return
	global_position = destination
	distance_traveled += travel
	age += delta
	queue_redraw()


func _chain_from(first_enemy: TrainingEnemy) -> void:
	var current_position := first_enemy.global_position
	var visited := {first_enemy.get_instance_id(): true}
	var screen := get_viewport().get_visible_rect()
	for jump in range(chain_jumps):
		var nearest: TrainingEnemy
		var best_distance := 155.0 * 155.0
		for candidate in get_tree().get_nodes_in_group("training_enemies"):
			if not candidate is TrainingEnemy or candidate.is_queued_for_deletion() or candidate.health <= 0.0:
				continue
			if visited.has(candidate.get_instance_id()):
				continue
			var distance := current_position.distance_squared_to(candidate.global_position)
			if distance > best_distance or not screen.has_point(candidate.get_global_transform_with_canvas().origin):
				continue
			var wall_ray := PhysicsRayQueryParameters2D.create(current_position, candidate.global_position, 4)
			if not get_world_2d().direct_space_state.intersect_ray(wall_ray).is_empty():
				continue
			nearest = candidate
			best_distance = distance
		if nearest == null:
			break
		var next_position := nearest.global_position
		var arc: Node2D = ChainArcScript.new()
		arc.setup(current_position, next_position)
		arc.process_mode = Node.PROCESS_MODE_PAUSABLE
		get_parent().add_child(arc)
		var chain_direction := current_position.direction_to(next_position)
		nearest.take_hit(damage * pow(0.6, float(jump + 1)), chain_direction, false)
		enemy_hit.emit(nearest)
		visited[nearest.get_instance_id()] = true
		current_position = next_position


func _draw() -> void:
	for i in range(trail_points.size()):
		var strength := float(i + 1) / float(trail_points.size() + 1)
		var from := to_local(trail_points[i])
		var to := to_local(trail_points[i + 1]) if i + 1 < trail_points.size() else Vector2.ZERO
		draw_line(from, to, Color(0.13, 0.72, 0.97, strength * 0.45), 3.0 + strength * 5.0)
		draw_line(from, to, Color(0.75, 0.99, 1.0, strength * 0.75), 1.0 + strength * 1.6)
	var tail := -direction * (13.0 + sin(age * 22.0) * 2.0)
	draw_line(tail, Vector2.ZERO, Color(0.27, 0.82, 1.0, 0.8), 5.0)
	draw_circle(Vector2.ZERO, 9.0, Color(0.12, 0.68, 0.96, 0.25))
	draw_circle(Vector2.ZERO, 5.0, Color("66dfff"))
	draw_circle(Vector2.ZERO, 2.4, Color("f2ffff"))
	var side := direction.orthogonal()
	for i in range(2):
		var side_sign := -1.0 if i == 0 else 1.0
		var spark := -direction * (8.0 + sin(age * 19.0 + float(i)) * 3.0) + side * side_sign * (5.0 + sin(age * 13.0 + float(i)) * 2.0)
		draw_circle(spark, 1.5, Color(0.6, 0.95, 1.0, 0.8))
