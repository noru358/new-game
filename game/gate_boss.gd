class_name GateBoss
extends "res://game/enemy.gd"

const SHOCK_RADIUS := 215.0
const SHOCK_WARNING := 0.75
const SHOCK_DAMAGE := 18.0

var shock_warning := 0.0
var next_attack_shock := false


func _ready() -> void:
	role = Role.BEAST
	max_health = 900.0
	charge_damage = 20.0
	super._ready()


func _beast_velocity(delta: float) -> Vector2:
	if shock_warning > 0.0:
		shock_warning = maxf(0.0, shock_warning - delta)
		if shock_warning <= 0.0:
			if is_instance_valid(target) and global_position.distance_to(target.global_position) <= SHOCK_RADIUS and (not zone_path_filter.is_valid() or zone_path_filter.call(global_position, target.global_position)):
				target.receive_hit(SHOCK_DAMAGE, global_position)
			attack_cooldown = BEAST_COOLDOWN
			next_attack_shock = false
			attacks_fired += 1
		return Vector2.ZERO
	if charge_time > 0.0 or warning_time > 0.0:
		return super._beast_velocity(delta)
	if next_attack_shock and attack_cooldown <= 0.0 and global_position.distance_to(target.global_position) <= 260.0 and _clear_shot_to_player():
		shock_warning = SHOCK_WARNING
		attacks_started += 1
		return Vector2.ZERO
	var was_charging := charge_time > 0.0
	var was_warning := warning_time > 0.0
	var motion := super._beast_velocity(delta)
	if not was_charging and not was_warning and warning_time > 0.0:
		next_attack_shock = true
	if not was_charging and not was_warning and charge_time <= 0.0 and warning_time <= 0.0:
		motion *= 85.0 / BEAST_SPEED
	return motion
