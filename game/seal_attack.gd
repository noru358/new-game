class_name SealAttack
extends Node2D

signal enemy_hit(enemy: TrainingEnemy)

var player: SandboxPlayer
var rank := 1
var cooldown := 0.8
var telegraph := 0.0
var burst_time := 0.0
var radius := 66.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 4


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or player.health <= 0.0:
		return
	burst_time = maxf(0.0, burst_time - delta)
	if telegraph > 0.0:
		telegraph = maxf(0.0, telegraph - delta)
		if telegraph <= 0.0:
			_explode()
	else:
		cooldown = maxf(0.0, cooldown - delta)
		if cooldown <= 0.0:
			var target := _find_target()
			if target != null:
				global_position = target.global_position
				telegraph = 0.45
				cooldown = 3.0
	queue_redraw()


func _find_target() -> TrainingEnemy:
	var nearest: TrainingEnemy
	var best_distance := 500.0 * 500.0
	var screen := get_viewport().get_visible_rect()
	for candidate in get_tree().get_nodes_in_group("training_enemies"):
		if not candidate is TrainingEnemy or candidate.is_queued_for_deletion() or candidate.health <= 0.0:
			continue
		var distance := player.global_position.distance_squared_to(candidate.global_position)
		if distance > best_distance or not screen.has_point(candidate.get_global_transform_with_canvas().origin):
			continue
		var ray := PhysicsRayQueryParameters2D.create(player.global_position, candidate.global_position, 4)
		if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		nearest = candidate
		best_distance = distance
	return nearest


func _explode() -> void:
	burst_time = 0.19
	for candidate in get_tree().get_nodes_in_group("training_enemies"):
		if not candidate is TrainingEnemy or candidate.is_queued_for_deletion() or candidate.health <= 0.0:
			continue
		if global_position.distance_to(candidate.global_position) > radius + candidate.RADIUS:
			continue
		var ray := PhysicsRayQueryParameters2D.create(global_position, candidate.global_position, 4)
		if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		var direction := global_position.direction_to(candidate.global_position)
		candidate.take_hit(12.0 * (1.0 + 0.25 * float(rank - 1)), direction, false)
		enemy_hit.emit(candidate)


func _draw() -> void:
	if telegraph > 0.0:
		var progress := 1.0 - telegraph / 0.45
		draw_circle(Vector2.ZERO, radius, Color(0.5, 0.2, 0.84, 0.07 + progress * 0.08))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 36, Color(0.8, 0.58, 1.0, 0.55 + progress * 0.35), 2.0 + progress * 2.0)
		draw_arc(Vector2.ZERO, radius * (1.0 - progress * 0.65), 0.0, TAU, 30, Color(0.95, 0.85, 1.0, 0.75), 3.0)
	elif burst_time > 0.0:
		var fade := burst_time / 0.19
		draw_circle(Vector2.ZERO, radius, Color(0.72, 0.45, 1.0, 0.23 * fade))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 36, Color(0.96, 0.8, 1.0, fade), 5.0 * fade)
