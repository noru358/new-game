class_name JungleWarden
extends "res://game/gate_boss.gd"

const WARDEN_HEALTH := 2000.0
const SWEEP_WARNING := 0.70
const SWEEP_FORWARD_MIN := -60.0
const SWEEP_FORWARD_MAX := 310.0
const SWEEP_HALF_WIDTH := 240.0
const SWEEP_DAMAGE := 22.0
const GUST_WARNING := 0.85
const GUST_REACH := 560.0
const GUST_DAMAGE := 10.0
const GUST_SAFE_RADIUS := 185.0

var sweep_warning := 0.0
var gust_warning := 0.0
var sweep_burst_time := 0.0
var gust_burst_time := 0.0
var next_attack_gust := false
var engaged := false
var combo_attacks_left := 0
var combo_gap := 0.0
var pending_gust := false


func _ready() -> void:
	super._ready()
	max_health = WARDEN_HEALTH
	health = max_health
	contact_margin = 5.0


func _attack_delay() -> float:
	return 1.45 if phase == 2 else 1.20


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	sweep_burst_time = maxf(0.0, sweep_burst_time - delta)
	gust_burst_time = maxf(0.0, gust_burst_time - delta)


func _beast_velocity(delta: float) -> Vector2:
	if recovery_time > 0.0:
		recovery_time = maxf(0.0, recovery_time - delta)
		return Vector2.ZERO
	if combo_gap > 0.0:
		combo_gap = maxf(0.0, combo_gap - delta)
		if combo_gap <= 0.0: _begin_warden_attack(pending_gust)
		return Vector2.ZERO
	if sweep_warning > 0.0:
		sweep_warning = maxf(0.0, sweep_warning - delta)
		if sweep_warning <= 0.0:
			_strike_sweep()
			sweep_burst_time = 0.16
			attacks_fired += 1
			_after_warden_strike(true)
		return Vector2.ZERO
	if gust_warning > 0.0:
		gust_warning = maxf(0.0, gust_warning - delta)
		if gust_warning <= 0.0:
			_strike_gust()
			gust_burst_time = 0.16
			attacks_fired += 1
			_after_warden_strike(false)
		return Vector2.ZERO
	if not is_instance_valid(target): return Vector2.ZERO
	var distance := global_position.distance_to(target.global_position)
	if not engaged:
		if distance > 680.0: return Vector2.ZERO
		engaged = true
	if attack_cooldown <= 0.0 and _clear_shot_to_player() and distance <= (650.0 if next_attack_gust or distance > 330.0 else 330.0):
		combo_attacks_left = 2 if phase == 2 else 0
		_begin_warden_attack(next_attack_gust or distance > 330.0)
		return Vector2.ZERO
	return _chase_direction(delta) * (270.0 if phase == 2 else 235.0)


func _begin_warden_attack(gust: bool) -> void:
	if not is_instance_valid(target): return
	locked_direction = global_position.direction_to(target.global_position)
	if locked_direction == Vector2.ZERO: locked_direction = Vector2.RIGHT
	warning_duration = 0.70 if phase == 1 else 0.62
	if gust:
		# A broad outer wind forces a different response from the front sweep.
		warning_duration = 0.95 if phase == 1 else 0.85
		gust_warning = warning_duration
	else:
		sweep_warning = 0.70 if phase == 1 else 0.62
	attacks_started += 1


func _after_warden_strike(gust_next: bool) -> void:
	next_attack_gust = gust_next
	if combo_attacks_left > 0:
		combo_attacks_left -= 1
		pending_gust = gust_next
		combo_gap = 0.18
	else:
		recovery_time = _attack_delay()
		attack_cooldown = 0.0


func suspend_encounter() -> void:
	super.suspend_encounter()
	sweep_warning = 0.0
	gust_warning = 0.0
	sweep_burst_time = 0.0
	gust_burst_time = 0.0
	combo_gap = 0.0
	combo_attacks_left = 0


func combat_cue() -> String:
	if recovery_time > 0.0: return ""
	if sweep_warning > 0.0: return "횡쓸기 · 표시된 띠 밖으로"
	if gust_warning > 0.0: return "바깥 강풍 · 보스 가까이 파고들기"
	if combo_gap > 0.0: return "후속 공격 주의"
	return "위치 잡기"


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
	var distance := offset.length()
	if distance < GUST_SAFE_RADIUS or distance > GUST_REACH + (60.0 if phase == 2 else 0.0): return
	var prior_health: float = target.health
	target.receive_hit(GUST_DAMAGE, global_position)
	if target.health < prior_health:
		target.hurt_recoil = offset.normalized() * (530.0 if phase == 2 else 420.0)
