class_name WispCompanion
extends Node2D

signal shot_fired(target: TrainingEnemy)
signal enemy_hit(enemy: TrainingEnemy)

const ProjectileScript = preload("res://game/wisp_projectile.gd")
const FOLLOW_OFFSET := Vector2(-42.0, -30.0)
const BASE_ATTACK_INTERVAL := 1.25
const BASE_DAMAGE_MULTIPLIER := 1.0
const DAMAGE_BONUS_PER_RANK := 0.20

@export var attack_interval := BASE_ATTACK_INTERVAL
@export var attack_range := 520.0
@export var projectile_speed := 620.0
@export var damage_multiplier := BASE_DAMAGE_MULTIPLIER

var player: SandboxPlayer
var navigation: ArenaNavigation
var fire_cooldown := 0.35
var age := 0.0
var shots_fired := 0
var shot_audio: AudioStreamPlayer2D
var muzzle_flash := 0.0
var shot_direction := Vector2.RIGHT
var follow_offset := FOLLOW_OFFSET
var orbit_enabled := false
var orbit_phase := 0.0
var orbit_damage := 3.0
var chain_jumps := 0
var orbit_next_hits: Dictionary = {}
var power_rank := 0


func _ready() -> void:
	if is_instance_valid(player):
		global_position = player.global_position + follow_offset
	shot_audio = AudioStreamPlayer2D.new()
	shot_audio.stream = preload("res://game/audio/wisp_shot.wav")
	shot_audio.volume_db = -11.0
	add_child(shot_audio)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or player.health <= 0.0:
		return
	age += delta
	muzzle_flash = maxf(0.0, muzzle_flash - delta)
	var bob := Vector2(0.0, sin(age * 5.4) * 3.0)
	var offset := Vector2.from_angle(player.companion_orbit_time * 3.0 + orbit_phase) * 64.0 + Vector2(0.0, -20.0) if orbit_enabled else follow_offset
	global_position = _outside_ruins(global_position.lerp(player.global_position + offset + bob, minf(1.0, 13.0 * delta)))
	if orbit_enabled:
		_hit_nearby_enemies()
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	if fire_cooldown <= 0.0:
		var target := find_target()
		if target != null:
			_fire(target)
			fire_cooldown = attack_interval
	queue_redraw()


func _outside_ruins(point: Vector2) -> Vector2:
	if navigation == null:
		return point
	for obstacle in navigation.obstacles:
		var center := Vector2(obstacle.x, obstacle.y)
		var safe_radius := obstacle.z + 12.0
		if point.distance_squared_to(center) >= safe_radius * safe_radius:
			continue
		var outward := player.global_position - center
		if outward.length_squared() < 0.01:
			outward = point - center
		point = center + outward.normalized() * safe_radius
	return point


func find_target() -> TrainingEnemy:
	var nearest: TrainingEnemy
	var best_distance := attack_range * attack_range
	var fallback: TrainingEnemy
	var fallback_distance := best_distance
	var screen := get_viewport().get_visible_rect()
	for candidate in get_tree().get_nodes_in_group("training_enemies"):
		if not candidate is TrainingEnemy or candidate.is_queued_for_deletion() or candidate.health <= 0.0:
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance > best_distance:
			continue
		if not screen.has_point(candidate.get_global_transform_with_canvas().origin):
			continue
		if _visible_aim_point(candidate).is_empty():
			continue
		var incoming_damage := 0.0
		for shot in get_tree().get_nodes_in_group("wisp_projectiles"):
			if shot is WispProjectile and not shot.is_queued_for_deletion() and shot.target == candidate:
				incoming_damage += shot.damage
		if incoming_damage >= candidate.health:
			if distance < fallback_distance:
				fallback = candidate
				fallback_distance = distance
			continue
		nearest = candidate
		best_distance = distance
	return nearest if nearest != null else fallback


func _blocked_by_wall(point: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, point, 4)
	query.hit_from_inside = true
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _visible_aim_point(candidate: TrainingEnemy) -> Dictionary:
	var toward := global_position.direction_to(candidate.global_position)
	var side := toward.orthogonal() * candidate.RADIUS * 0.65
	for point in [candidate.global_position, candidate.global_position + side, candidate.global_position - side]:
		if not _blocked_by_wall(point):
			return {"point": point}
	return {}


func _fire(target: TrainingEnemy) -> void:
	var aim := _visible_aim_point(target)
	if aim.is_empty():
		return
	var direction := global_position.direction_to(aim.point)
	shot_direction = direction
	muzzle_flash = 0.14
	var projectile: WispProjectile = ProjectileScript.new()
	projectile.setup(direction, projectile_speed, attack_range, player.ATTACK_DAMAGE * damage_multiplier)
	projectile.target = target
	projectile.power_rank = power_rank
	projectile.chain_jumps = chain_jumps
	projectile.enemy_hit.connect(_on_projectile_hit)
	projectile.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_parent().add_child(projectile)
	projectile.global_position = global_position
	shots_fired += 1
	shot_fired.emit(target)
	if DisplayServer.get_name() != "headless":
		shot_audio.play()


func _on_projectile_hit(enemy: TrainingEnemy) -> void:
	enemy_hit.emit(enemy)


func _hit_nearby_enemies() -> void:
	for candidate in get_tree().get_nodes_in_group("training_enemies"):
		if not candidate is TrainingEnemy or candidate.is_queued_for_deletion() or candidate.health <= 0.0:
			continue
		if global_position.distance_to(candidate.global_position) > candidate.RADIUS + 13.0:
			continue
		if _blocked_by_wall(candidate.global_position):
			continue
		var id := candidate.get_instance_id()
		if age < float(orbit_next_hits.get(id, 0.0)):
			continue
		orbit_next_hits[id] = age + 0.85
		var direction := global_position.direction_to(candidate.global_position)
		candidate.take_hit(orbit_damage, direction, false)
		enemy_hit.emit(candidate)
		var flash := WispFlash.new()
		flash.setup(direction, false, power_rank, -6.0)
		flash.process_mode = Node.PROCESS_MODE_PAUSABLE
		get_parent().add_child(flash)
		flash.global_position = candidate.global_position


func _draw() -> void:
	var flicker := sin(age * 9.0) * 2.0
	draw_circle(Vector2(0, 12), 10.0, Color(0.03, 0.13, 0.17, 0.28))
	draw_circle(Vector2.ZERO, 15.0 + flicker, Color(0.39, 0.91, 0.81, 0.15))
	draw_circle(Vector2.ZERO, 10.0 + flicker * 0.3, Color(0.19, 0.84, 0.94, 0.22))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, 7), Vector2(-7, -5), Vector2(-2, -15 + flicker),
		Vector2(2, -6), Vector2(5, -12 + flicker), Vector2(9, 4), Vector2(3, 10)
	]), Color("37c9e5"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4, 5), Vector2(-2, -4), Vector2(0, -9 + flicker),
		Vector2(5, 4), Vector2(1, 7)
	]), Color("d7fcff"))
	for i in range(2):
		var spark := Vector2(-11.0 + float(i) * 22.0, -7.0 - sin(age * 8.0 + float(i) * 2.7) * 4.0)
		draw_circle(spark, 1.4, Color(0.57, 0.95, 1.0, 0.7))
	if muzzle_flash > 0.0:
		var alpha := muzzle_flash / 0.14
		var tip := shot_direction * (14.0 + (1.0 - alpha) * 7.0)
		draw_circle(shot_direction * 9.0, 10.0 * alpha, Color(0.29, 0.93, 1.0, 0.28 * alpha))
		draw_line(shot_direction * 2.0, tip, Color(0.82, 1.0, 1.0, 0.9 * alpha), 3.0 * alpha)
		draw_line(tip - shot_direction.rotated(0.7) * 5.0, tip, Color(0.38, 0.9, 1.0, 0.8 * alpha), 2.0 * alpha)
		draw_line(tip - shot_direction.rotated(-0.7) * 5.0, tip, Color(0.38, 0.9, 1.0, 0.8 * alpha), 2.0 * alpha)
