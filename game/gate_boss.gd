class_name GateBoss
extends "res://game/enemy.gd"

const BOSS_HEALTH := 700.0
const PHASE_TWO_RATIO := 0.60
const SHOCK_RADIUS := 215.0
const SHOCK_WARNING := 0.75
const SHOCK_DAMAGE := 18.0
const RING_INNER_RADIUS := 140.0
const RING_OUTER_RADIUS := 315.0
const RING_WARNING := 0.90
const RING_DAMAGE := 22.0

var encounter_active := true
var encounter_area := Rect2()
var shock_warning := 0.0
var ring_warning := 0.0
var next_attack_shock := false
var phase := 1
var flank_sign := 1.0


func _ready() -> void:
	role = Role.BEAST
	max_health = BOSS_HEALTH
	charge_damage = 20.0
	super._ready()


func take_hit(damage: float, _push_direction: Vector2, _is_finisher: bool, _impact_scale: float = 1.0) -> void:
	if not encounter_active or (encounter_area.has_area() and is_instance_valid(target) and not encounter_area.has_point(target.global_position)): return
	# Regular enemies lose their warning and charge on every hit. The boss keeps
	# acting while damage remains fully effective, so attacking is never wasted.
	health -= damage
	hit_flash = 0.19
	if health <= 0.0:
		defeated.emit()
		queue_free()
		return
	if phase == 1 and health <= max_health * PHASE_TWO_RATIO:
		phase = 2
		charge_damage = 25.0
		attack_cooldown = minf(attack_cooldown, 0.55)
	queue_redraw()


func gather_to(_point: Vector2) -> void:
	# Third-hit damage still lands, but its pull cannot cancel boss attacks.
	pass


func charge_reach() -> float:
	return BEAST_CHARGE_SPEED * BEAST_CHARGE_DURATION * (1.25 if phase == 2 else 1.0)


func suspend_encounter() -> void:
	encounter_active = false
	velocity = Vector2.ZERO
	warning_time = 0.0
	charge_time = 0.0
	shock_warning = 0.0
	ring_warning = 0.0
	attack_cooldown = 1.0


func _attack_delay() -> float:
	return 1.25 if phase == 2 else 1.55


func _physics_process(delta: float) -> void:
	if not encounter_active or (encounter_area.has_area() and is_instance_valid(target) and not encounter_area.has_point(target.global_position)): return
	super._physics_process(delta)
	# The shared enemy mover applies its own long cooldown after a wall hit.
	if charge_time <= 0.0 and warning_time <= 0.0 and shock_warning <= 0.0 and ring_warning <= 0.0:
		attack_cooldown = minf(attack_cooldown, _attack_delay())


func _beast_velocity(delta: float) -> Vector2:
	if ring_warning > 0.0:
		ring_warning = maxf(0.0, ring_warning - delta)
		if ring_warning <= 0.0:
			_strike_ring()
			attack_cooldown = _attack_delay()
			next_attack_shock = false
			attacks_fired += 1
		return Vector2.ZERO
	if shock_warning > 0.0:
		shock_warning = maxf(0.0, shock_warning - delta)
		if shock_warning <= 0.0:
			if is_instance_valid(target) and global_position.distance_to(target.global_position) <= SHOCK_RADIUS and _damage_path_clear():
				target.receive_hit(SHOCK_DAMAGE, global_position)
			attacks_fired += 1
			if phase == 2:
				ring_warning = RING_WARNING
			else:
				attack_cooldown = _attack_delay()
				next_attack_shock = false
		return Vector2.ZERO
	if charge_time > 0.0 or warning_time > 0.0:
		var charging := charge_time > 0.0
		var motion := super._beast_velocity(delta)
		if charging and charge_time <= 0.0: attack_cooldown = _attack_delay()
		return motion * (1.25 if phase == 2 else 1.0) if charging else motion
	if not is_instance_valid(target): return Vector2.ZERO
	var distance := global_position.distance_to(target.global_position)
	var clear := _clear_shot_to_player()
	if attack_cooldown <= 0.0 and clear:
		if next_attack_shock and distance <= (300.0 if phase == 2 else 260.0):
			shock_warning = SHOCK_WARNING
			attacks_started += 1
			flank_sign = -flank_sign
			return Vector2.ZERO
		if not next_attack_shock and distance <= (330.0 if phase == 2 else 260.0):
			locked_direction = global_position.direction_to(target.global_position)
			warning_time = 0.48 if phase == 2 else 0.55
			next_attack_shock = true
			attacks_started += 1
			flank_sign = -flank_sign
			return Vector2.ZERO
	var toward := _chase_direction(delta)
	if phase == 2 and distance < 500.0 and clear:
		var flank := (toward * 0.60 + toward.orthogonal() * flank_sign * 0.80).normalized()
		var flank_point := global_position + flank * 80.0
		if navigation == null or navigation.has_clear_path(global_position, flank_point):
			return flank * 165.0
	return toward * (165.0 if phase == 2 else 135.0)


func _strike_ring() -> void:
	if not is_instance_valid(target): return
	var distance := global_position.distance_to(target.global_position)
	if distance >= RING_INNER_RADIUS and distance <= RING_OUTER_RADIUS and _damage_path_clear():
		target.receive_hit(RING_DAMAGE, global_position)


func _damage_path_clear() -> bool:
	return not zone_path_filter.is_valid() or zone_path_filter.call(global_position, target.global_position)
