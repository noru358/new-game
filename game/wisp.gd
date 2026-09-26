class_name WispCompanion
extends Node2D

signal shot_fired(target: TrainingEnemy)

const ProjectileScript = preload("res://game/wisp_projectile.gd")
const FOLLOW_OFFSET := Vector2(-42.0, -30.0)

@export var attack_interval := 1.8
@export var attack_range := 520.0
@export var projectile_speed := 620.0
@export var damage_multiplier := 0.65

var player: SandboxPlayer
var fire_cooldown := 0.35
var age := 0.0
var shots_fired := 0
var shot_audio: AudioStreamPlayer2D


func _ready() -> void:
	if is_instance_valid(player):
		global_position = player.global_position + FOLLOW_OFFSET
	shot_audio = AudioStreamPlayer2D.new()
	shot_audio.stream = preload("res://game/audio/wisp_shot.wav")
	shot_audio.volume_db = -11.0
	add_child(shot_audio)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or player.health <= 0.0:
		return
	age += delta
	var bob := Vector2(0.0, sin(age * 5.4) * 3.0)
	global_position = global_position.lerp(player.global_position + FOLLOW_OFFSET + bob, minf(1.0, 13.0 * delta))
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	if fire_cooldown <= 0.0:
		var target := find_target()
		if target != null:
			_fire(target)
			fire_cooldown = attack_interval
	queue_redraw()


func find_target() -> TrainingEnemy:
	var nearest: TrainingEnemy
	var best_distance := attack_range * attack_range
	var screen := get_viewport().get_visible_rect()
	for candidate in get_tree().get_nodes_in_group("training_enemies"):
		if not candidate is TrainingEnemy or candidate.is_queued_for_deletion() or candidate.health <= 0.0:
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance > best_distance:
			continue
		if not screen.has_point(candidate.get_global_transform_with_canvas().origin):
			continue
		if _blocked_by_wall(candidate.global_position):
			continue
		nearest = candidate
		best_distance = distance
	return nearest


func _blocked_by_wall(point: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, point, 4)
	query.hit_from_inside = true
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _fire(target: TrainingEnemy) -> void:
	var direction := global_position.direction_to(target.global_position)
	var projectile: Node2D = ProjectileScript.new()
	projectile.setup(direction, projectile_speed, attack_range, player.ATTACK_DAMAGE * damage_multiplier)
	projectile.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_parent().add_child(projectile)
	projectile.global_position = global_position
	shots_fired += 1
	shot_fired.emit(target)
	if DisplayServer.get_name() != "headless":
		shot_audio.play()


func _draw() -> void:
	var flicker := sin(age * 9.0) * 2.0
	draw_circle(Vector2(0, 12), 10.0, Color(0.03, 0.13, 0.17, 0.28))
	draw_circle(Vector2.ZERO, 15.0 + flicker, Color(0.39, 0.91, 0.81, 0.15))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, 7), Vector2(-7, -5), Vector2(-2, -15 + flicker),
		Vector2(2, -6), Vector2(5, -12 + flicker), Vector2(9, 4), Vector2(3, 10)
	]), Color("55d6cc"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4, 5), Vector2(-2, -4), Vector2(0, -9 + flicker),
		Vector2(5, 4), Vector2(1, 7)
	]), Color("ffdf91"))
