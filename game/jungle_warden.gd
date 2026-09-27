class_name JungleWarden
extends "res://game/gate_boss.gd"

const SWEEP_WARNING := 0.70
const SWEEP_FORWARD_MIN := 35.0
const SWEEP_FORWARD_MAX := 230.0
const SWEEP_HALF_WIDTH := 240.0
const SWEEP_DAMAGE := 22.0
const GUST_WARNING := 0.85
const GUST_REACH := 440.0
const GUST_DAMAGE := 10.0

var sweep_warning := 0.0
var gust_warning := 0.0
var sweep_burst_time := 0.0
var gust_burst_time := 0.0
var next_attack_gust := false


func _ready() -> void:
	super._ready()
	max_health = 760.0
	health = max_health
	contact_margin = 5.0


func _attack_delay() -> float:
	return 1.05 if phase == 2 else 1.35


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	sweep_burst_time = maxf(0.0, sweep_burst_time - delta)
	gust_burst_time = maxf(0.0, gust_burst_time - delta)


func _beast_velocity(delta: float) -> Vector2:
	if sweep_warning > 0.0:
		sweep_warning = maxf(0.0, sweep_warning - delta)
		if sweep_warning <= 0.0:
			_strike_sweep()
			sweep_burst_time = 0.15
			attacks_fired += 1
			attack_cooldown = _attack_delay()
			next_attack_gust = true
		return Vector2.ZERO
	if gust_warning > 0.0:
		gust_warning = maxf(0.0, gust_warning - delta)
		if gust_warning <= 0.0:
			_strike_gust()
			gust_burst_time = 0.20
			attacks_fired += 1
			attack_cooldown = _attack_delay()
			next_attack_gust = false
		return Vector2.ZERO
	if not is_instance_valid(target): return Vector2.ZERO
	var offset := target.global_position - global_position
	var distance := offset.length()
	if attack_cooldown <= 0.0 and _clear_shot_to_player():
		if next_attack_gust and distance <= (500.0 if phase == 2 else 420.0):
			locked_direction = offset.normalized()
			gust_warning = GUST_WARNING * (0.8 if phase == 2 else 1.0)
			attacks_started += 1
			return Vector2.ZERO
		if not next_attack_gust and distance <= 310.0:
			locked_direction = offset.normalized()
			sweep_warning = SWEEP_WARNING * (0.8 if phase == 2 else 1.0)
			attacks_started += 1
			return Vector2.ZERO
	var toward := _chase_direction(delta)
	return toward * (160.0 if phase == 2 else 125.0)


func _strike_sweep() -> void:
	if not is_instance_valid(target) or not _damage_path_clear(): return
	var offset := target.global_position - global_position
	var forward := offset.dot(locked_direction)
	var side := absf(offset.dot(locked_direction.orthogonal()))
	if forward >= SWEEP_FORWARD_MIN and forward <= SWEEP_FORWARD_MAX and side <= SWEEP_HALF_WIDTH + (35.0 if phase == 2 else 0.0):
		target.receive_hit(SWEEP_DAMAGE, global_position)


func _strike_gust() -> void:
	if not is_instance_valid(target) or not _damage_path_clear(): return
	var offset := target.global_position - global_position
	var forward := offset.dot(locked_direction)
	var side := absf(offset.dot(locked_direction.orthogonal()))
	if forward < 0.0 or forward > GUST_REACH + (60.0 if phase == 2 else 0.0) or side > maxf(55.0, forward * 0.58): return
	var prior_health: float = target.health
	target.receive_hit(GUST_DAMAGE, global_position)
	if target.health < prior_health:
		target.hurt_recoil = locked_direction * (530.0 if phase == 2 else 420.0)
