class_name TrainingEnemy
extends CharacterBody2D

signal defeated

enum Role { FRAGMENT, BEAST, LAMP, ZONE, SUPPORT }

const BoltScript = preload("res://game/enemy_bolt.gd")
const ZoneScript = preload("res://game/enemy_zone.gd")
const MAX_HEALTH := 22.0
const MOVE_SPEED := 105.0
const CONTACT_DAMAGE := 10.0
const RADIUS := 17.0
const GATHER_DURATION := 0.12
const GATHER_CONTACT_GRACE := 0.44
const BEAST_SPEED := 125.0
const BEAST_CHARGE_SPEED := 620.0
const BEAST_WARNING := 0.42
const BEAST_CHARGE_DURATION := 0.43
const BEAST_COOLDOWN := 2.8
const LAMP_SPEED := 85.0
const LAMP_WARNING := 0.6
const LAMP_COOLDOWN := 2.5
const ZONE_SPEED := 90.0
const ZONE_COOLDOWN := 3.2
const SUPPORT_SPEED := 100.0
const SUPPORT_RADIUS := 250.0
const SUPPORT_MOVE_MULTIPLIER := 1.25
const SUPPORT_COOLDOWN_MULTIPLIER := 1.3

@export var max_health := MAX_HEALTH
@export var role: Role = Role.FRAGMENT

var health := MAX_HEALTH
var collision_radius := RADIUS
var contact_margin := 0.0
var visual_pitch := 0.0
var target: Node2D
var knockback := Vector2.ZERO
var hit_flash := 0.0
var stagger_time := 0.0
var gather_origin := Vector2.ZERO
var gather_target := Vector2.ZERO
var gather_elapsed := 0.0
var gathering := false
var gather_contact_grace := 0.0
var navigation: ArenaNavigation
var navigation_path := PackedVector2Array()
var navigation_goal := Vector2.ZERO
var navigation_repath_time := 0.0
var attack_cooldown := 0.0
var warning_time := 0.0
var charge_time := 0.0
var locked_direction := Vector2.RIGHT
var charge_has_hit := false
var attacks_started := 0
var attacks_fired := 0
var support_boost := false
var arena_bounds := Rect2(Vector2.ZERO, Vector2(2400, 1400))
var projectile_parent: Node
var zone_path_filter: Callable


func _ready() -> void:
	health = max_health
	add_to_group("training_enemies")


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	hit_flash = maxf(0.0, hit_flash - delta)
	stagger_time = maxf(0.0, stagger_time - delta)
	gather_contact_grace = maxf(0.0, gather_contact_grace - delta)
	support_boost = _has_support_aura()
	attack_cooldown = maxf(0.0, attack_cooldown - delta * (SUPPORT_COOLDOWN_MULTIPLIER if support_boost else 1.0))
	var charging_this_frame := role == Role.BEAST and charge_time > 0.0
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
		var movement := Vector2.ZERO
		if stagger_time <= 0.0:
			match role:
				Role.BEAST: movement = _beast_velocity(delta)
				Role.LAMP: movement = _lamp_velocity(delta)
				Role.ZONE: movement = _zone_velocity(delta)
				Role.SUPPORT: movement = _support_velocity(delta)
				_: movement = _chase_direction(delta) * MOVE_SPEED
			if support_boost and not charging_this_frame:
				movement *= SUPPORT_MOVE_MULTIPLIER
		velocity = movement + knockback
		move_and_slide()
		if charging_this_frame and get_slide_collision_count() > 0:
			for i in range(get_slide_collision_count()):
				if get_slide_collision(i).get_collider() is ViewProp or get_slide_collision(i).get_collider() is TempleBlock:
					charge_time = 0.0
					attack_cooldown = BEAST_COOLDOWN
					break
	global_position = Vector2(
		clampf(global_position.x, arena_bounds.position.x + 24.0, arena_bounds.end.x - 24.0),
		clampf(global_position.y, arena_bounds.position.y + 24.0, arena_bounds.end.y - 24.0)
	)
	if gather_contact_grace <= 0.0 and global_position.distance_to(target.global_position) <= collision_radius + target.collision_radius + contact_margin:
		if role == Role.FRAGMENT:
			target.receive_hit(CONTACT_DAMAGE, global_position)
		elif role == Role.SUPPORT:
			target.receive_hit(7.0, global_position)
		elif role == Role.BEAST and charging_this_frame and not charge_has_hit:
			charge_has_hit = true
			target.receive_hit(15.0, global_position)
	queue_redraw()


func _beast_velocity(delta: float) -> Vector2:
	if charge_time > 0.0:
		charge_time = maxf(0.0, charge_time - delta)
		if charge_time <= 0.0:
			attack_cooldown = BEAST_COOLDOWN
		return locked_direction * BEAST_CHARGE_SPEED
	if warning_time > 0.0:
		warning_time = maxf(0.0, warning_time - delta)
		if warning_time <= 0.0:
			charge_time = BEAST_CHARGE_DURATION
			charge_has_hit = false
			attacks_fired += 1
		return Vector2.ZERO
	if attack_cooldown <= 0.0 and global_position.distance_to(target.global_position) <= 260.0 and _clear_shot_to_player():
		locked_direction = global_position.direction_to(target.global_position)
		warning_time = BEAST_WARNING
		attacks_started += 1
		return Vector2.ZERO
	return _chase_direction(delta) * BEAST_SPEED


func _lamp_velocity(delta: float) -> Vector2:
	if warning_time > 0.0:
		warning_time = maxf(0.0, warning_time - delta)
		if warning_time <= 0.0:
			if global_position.distance_to(target.global_position) <= 520.0 and _clear_shot_to_player():
				_fire_bolt()
				attack_cooldown = LAMP_COOLDOWN
			else:
				attack_cooldown = 0.35
		return Vector2.ZERO
	var distance := global_position.distance_to(target.global_position)
	var clear_shot := _clear_shot_to_player()
	if attack_cooldown <= 0.0 and distance <= 390.0 and clear_shot:
		locked_direction = global_position.direction_to(target.global_position)
		warning_time = LAMP_WARNING
		attacks_started += 1
		return Vector2.ZERO
	if not clear_shot:
		return _chase_direction(delta) * LAMP_SPEED
	if distance < 220.0:
		return _retreat_velocity()
	if distance > 390.0:
		return _chase_direction(delta) * LAMP_SPEED
	return Vector2.ZERO


func _zone_velocity(delta: float) -> Vector2:
	var distance := global_position.distance_to(target.global_position)
	var clear_shot := _clear_shot_to_player()
	if attack_cooldown <= 0.0 and distance <= 340.0 and clear_shot:
		var zone: Node2D = ZoneScript.new()
		zone.setup(self, target)
		zone.damage_path_filter = zone_path_filter
		zone.process_mode = Node.PROCESS_MODE_PAUSABLE
		(get_parent().get_parent() if projectile_parent == null else projectile_parent).add_child(zone)
		zone.global_position = target.global_position
		attack_cooldown = ZONE_COOLDOWN
		attacks_started += 1
		attacks_fired += 1
	if not clear_shot or distance > 340.0:
		return _chase_direction(delta) * ZONE_SPEED
	if distance < 190.0:
		return _retreat_velocity(ZONE_SPEED)
	return Vector2.ZERO


func _support_velocity(delta: float) -> Vector2:
	var distance := global_position.distance_to(target.global_position)
	if distance < 185.0:
		return _retreat_velocity(SUPPORT_SPEED)
	if distance > 310.0 or not _clear_shot_to_player():
		return _chase_direction(delta) * SUPPORT_SPEED
	return Vector2.ZERO


func _has_support_aura() -> bool:
	if role == Role.SUPPORT:
		return false
	for candidate in get_tree().get_nodes_in_group("training_enemies"):
		if candidate is TrainingEnemy and candidate.role == Role.SUPPORT and candidate.health > 0.0 and not candidate.is_queued_for_deletion():
			if global_position.distance_to(candidate.global_position) <= SUPPORT_RADIUS:
				return true
	return false


func _retreat_velocity(speed: float = LAMP_SPEED) -> Vector2:
	var away := target.global_position.direction_to(global_position)
	for direction in [away, away.rotated(PI * 0.5), away.rotated(-PI * 0.5)]:
		if navigation == null or navigation.has_clear_path(global_position, global_position + direction * 55.0):
			return direction * speed
	return Vector2.ZERO


func _clear_shot_to_player() -> bool:
	var ray := PhysicsRayQueryParameters2D.create(global_position, target.global_position, 4)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()


func _fire_bolt() -> void:
	var bolt: Node2D = BoltScript.new()
	bolt.setup(locked_direction, 240.0, 12.0)
	bolt.process_mode = Node.PROCESS_MODE_PAUSABLE
	(get_parent().get_parent() if projectile_parent == null else projectile_parent).add_child(bolt)
	bolt.global_position = global_position + locked_direction * 24.0
	attacks_fired += 1


func _chase_direction(delta: float) -> Vector2:
	var goal := target.global_position
	if navigation == null or navigation.has_clear_path(global_position, goal):
		navigation_path.clear()
		return global_position.direction_to(goal)
	navigation_repath_time -= delta
	if navigation_repath_time <= 0.0 or navigation_path.is_empty() or navigation_goal.distance_to(goal) > 42.0:
		navigation_path = navigation.find_path(global_position, goal)
		navigation_goal = goal
		navigation_repath_time = 0.28
	for i in range(navigation_path.size() - 1, -1, -1):
		if navigation.has_clear_path(global_position, navigation_path[i]):
			return global_position.direction_to(navigation_path[i])
	return Vector2.ZERO


func take_hit(damage: float, push_direction: Vector2, is_finisher: bool, impact_scale: float = 1.0) -> void:
	gathering = false
	_interrupt_special()
	health -= damage
	hit_flash = 0.19
	stagger_time = 0.15 if is_finisher else 0.09 + 0.08 * (impact_scale - 1.0)
	knockback = push_direction * (300.0 if is_finisher else 170.0 * impact_scale)
	if health <= 0.0:
		defeated.emit()
		queue_free()
	else:
		queue_redraw()


func gather_to(point: Vector2) -> void:
	_interrupt_special()
	gather_origin = global_position
	gather_target = point
	gather_elapsed = 0.0
	gathering = true
	gather_contact_grace = GATHER_CONTACT_GRACE
	knockback = Vector2.ZERO
	stagger_time = maxf(stagger_time, 0.38)


func _interrupt_special() -> void:
	if warning_time > 0.0 or charge_time > 0.0:
		warning_time = 0.0
		charge_time = 0.0
		attack_cooldown = maxf(attack_cooldown, 0.8)


func _draw() -> void:
	if warning_time > 0.0:
		var length := 280.0 if role == Role.BEAST else 400.0
		var color := Color(1.0, 0.30, 0.20, 0.38) if role == Role.BEAST else Color(1.0, 0.79, 0.28, 0.36)
		draw_line(Vector2.ZERO, locked_direction * length, color, 12.0 if role == Role.BEAST else 3.0)
		draw_arc(Vector2.ZERO, 25.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - warning_time / (BEAST_WARNING if role == Role.BEAST else LAMP_WARNING)), 24, color.lightened(0.4), 4.0)
	var reinforced := max_health > MAX_HEALTH
	var stone := Color("edf6e8") if hit_flash > 0.0 else Color("b87360") if role == Role.BEAST else Color("f1cb72") if role == Role.LAMP else Color("72d7cf") if role == Role.ZONE else Color("be9fe9") if role == Role.SUPPORT else Color("9aa8c7") if reinforced else Color("8bada0")
	var shade := Color("613c44") if role == Role.BEAST else Color("62527c") if role == Role.LAMP else Color("306f72") if role == Role.ZONE else Color("594f79") if role == Role.SUPPORT else Color("3c5d61")
	if visual_pitch > 0.0:
		var shadow := PackedVector2Array()
		for i in range(25):
			var angle := TAU * float(i) / 24.0
			shadow.append(Vector2(cos(angle) * 20.0, 7.0 + sin(angle) * 9.0))
		draw_colored_polygon(shadow, Color(0.02, 0.09, 0.11, 0.35))
	else:
		draw_circle(Vector2(0, 7), 20.0, Color(0.02, 0.09, 0.11, 0.35))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-17, 9), Vector2(-12, -13), Vector2(0, -21),
		Vector2(16, -11), Vector2(18, 9), Vector2(3, 18)
	]), shade)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, 5), Vector2(-8, -12), Vector2(1, -17),
		Vector2(12, -9), Vector2(13, 6), Vector2(1, 12)
	]), stone)
	if visual_pitch > 0.0:
		var top := -18.0 - visual_pitch * 17.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(-12, -1), Vector2(-10, top), Vector2(3, top - 7),
			Vector2(13, top + 2), Vector2(13, 5), Vector2(1, 12)
		]), stone)
	draw_line(Vector2(-7, -4), Vector2(8, 4), Color("295665"), 3.0)
	var eye := Color("fff3ad") if role == Role.LAMP else Color("ffb073") if role == Role.BEAST or reinforced else Color("e6d2ff") if role == Role.SUPPORT else Color("42d9d4")
	draw_circle(Vector2(-4, -2), 2.0, eye)
	draw_circle(Vector2(7, 0), 2.0, eye)
	if role == Role.BEAST:
		draw_colored_polygon(PackedVector2Array([Vector2(-14, -9), Vector2(-24, -20), Vector2(-12, -17)]), Color("e6b588"))
		draw_colored_polygon(PackedVector2Array([Vector2(11, -11), Vector2(23, -20), Vector2(17, -5)]), Color("e6b588"))
	elif role == Role.LAMP:
		draw_circle(Vector2(0, -18), 13.0, Color(1.0, 0.76, 0.24, 0.22))
		draw_circle(Vector2(0, -18), 5.0, Color("ffe391"))
		draw_line(Vector2(-13, 8), Vector2(13, 8), Color("ffe391"), 3.0)
	elif role == Role.ZONE:
		draw_arc(Vector2(0, -18), 11.0, 0.0, TAU, 20, Color("b5fff4"), 3.0)
		draw_line(Vector2(-12, 8), Vector2(12, 8), Color("b5fff4"), 3.0)
	elif role == Role.SUPPORT:
		draw_arc(Vector2.ZERO, SUPPORT_RADIUS, 0.0, TAU, 48, Color(0.78, 0.51, 0.98, 0.14), 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(0, -31), Vector2(11, -18), Vector2(0, -5), Vector2(-11, -18)]), Color("e2baff"))
	if support_boost:
		draw_arc(Vector2.ZERO, 23.0, 0.0, TAU, 20, Color(0.83, 0.55, 1.0, 0.8), 2.5)
	var health_y := -32.0 - visual_pitch * 18.0
	draw_rect(Rect2(-18, health_y, 36, 4), Color(0.05, 0.16, 0.18, 0.8))
	draw_rect(Rect2(-18, health_y, 36.0 * maxf(health, 0.0) / max_health, 4), Color("f7c066") if role == Role.LAMP else Color("ed9072") if role == Role.BEAST else Color("8fe8d8") if role == Role.ZONE else Color("d4abf7") if role == Role.SUPPORT else Color("f9c06f") if reinforced else Color("8ce2bc"))
