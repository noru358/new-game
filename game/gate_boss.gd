class_name GateBoss
extends "res://game/enemy.gd"

signal counter_struck(point: Vector2)

const BOSS_HEALTH := 1800.0
const PHASE_TWO_RATIO := 0.60
const SHOCK_RADIUS := 215.0
const SHOCK_WARNING := 0.55
const SHOCK_DAMAGE := 18.0
const RING_INNER_RADIUS := 140.0
const RING_OUTER_RADIUS := 315.0
const RING_WARNING := 0.75
const RING_DAMAGE := 22.0

var warning_duration := 0.60
var encounter_active := true
var encounter_area := Rect2()
var shock_warning := 0.0
var ring_warning := 0.0
var next_attack_shock := false
var phase := 1
var recovery_time := 0.0
var charge_followups := 0
var charge_pending := false
var planned_charge_distance := 260.0
var impact_flash := 0.0
var impact_is_ring := false
var counter_flash := 0.0
const COUNTER_DAMAGE_MULTIPLIER := 1.30
const DUEL_CHARGE_SPEED := 1000.0
const REENTRY_WARNING_FLOOR := 0.35

@export var brisk_cadence := true


func _ready() -> void:
	role = Role.BEAST
	max_health = BOSS_HEALTH
	charge_damage = 20.0
	super._ready()


func take_direct_hit(damage: float, direction: Vector2, finisher: bool, impact_scale: float = 1.0) -> bool:
	if not encounter_active or health <= 0.0 or (encounter_area.has_area() and is_instance_valid(target) and not encounter_area.has_point(target.global_position)): return false
	var counter := recovery_time > 0.0
	if counter:
		counter_flash = 0.22
		counter_struck.emit(global_position)
	take_hit(damage * (COUNTER_DAMAGE_MULTIPLIER if counter else 1.0), direction, finisher, impact_scale)
	return counter


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


func _interrupt_special() -> void:
	# All ordinary hit paths, including companion projectiles, share this
	# inherited hook. Only leaving the encounter can pause a boss pattern.
	pass


func charge_reach() -> float:
	return planned_charge_distance


func pause_for_boundary() -> void:
	# Free exit preserves health and the unfinished pattern. A charge already in
	# motion needs a fresh visible warning before it can resume on re-entry.
	encounter_active = false
	velocity = Vector2.ZERO
	if charge_time > 0.0:
		charge_time = 0.0
		charge_pending = false
		warning_time = maxf(warning_duration, REENTRY_WARNING_FLOOR)


func resume_from_boundary() -> void:
	encounter_active = true
	if warning_time > 0.0: warning_time = maxf(warning_time, REENTRY_WARNING_FLOOR)
	if shock_warning > 0.0: shock_warning = maxf(shock_warning, REENTRY_WARNING_FLOOR)
	if ring_warning > 0.0: ring_warning = maxf(ring_warning, REENTRY_WARNING_FLOOR)


func suspend_encounter() -> void:
	encounter_active = false
	velocity = Vector2.ZERO
	warning_time = 0.0
	charge_time = 0.0
	shock_warning = 0.0
	ring_warning = 0.0
	attack_cooldown = 0.4
	recovery_time = 0.0
	charge_followups = 0
	charge_pending = false
	impact_flash = 0.0
	counter_flash = 0.0


func _attack_delay() -> float:
	# Only the exposed counter window changes. Full directional/area warnings,
	# attack shapes and HP stay the same; disable this for A/B comparison.
	return (1.20 if phase == 2 else 1.00) if brisk_cadence else (1.45 if phase == 2 else 1.20)


func _physics_process(delta: float) -> void:
	if not encounter_active or (encounter_area.has_area() and is_instance_valid(target) and not encounter_area.has_point(target.global_position)): return
	impact_flash = maxf(0.0, impact_flash - delta)
	counter_flash = maxf(0.0, counter_flash - delta)
	super._physics_process(delta)
	# The shared enemy mover applies its own long cooldown after a wall hit.
	if charge_time <= 0.0 and warning_time <= 0.0 and shock_warning <= 0.0 and ring_warning <= 0.0:
		attack_cooldown = minf(attack_cooldown, _attack_delay())


func _beast_velocity(delta: float) -> Vector2:
	if recovery_time > 0.0:
		recovery_time = maxf(0.0, recovery_time - delta)
		return Vector2.ZERO
	if ring_warning > 0.0:
		ring_warning = maxf(0.0, ring_warning - delta)
		if ring_warning <= 0.0:
			_strike_ring()
			impact_is_ring = true
			attacks_fired += 1
			impact_flash = 0.18
			_finish_pattern(true)
		return Vector2.ZERO
	if shock_warning > 0.0:
		shock_warning = maxf(0.0, shock_warning - delta)
		if shock_warning <= 0.0:
			if is_instance_valid(target) and global_position.distance_to(target.global_position) <= SHOCK_RADIUS and _damage_path_clear():
				target.receive_hit(SHOCK_DAMAGE, global_position)
			attacks_fired += 1
			impact_flash = 0.18
			impact_is_ring = false
			if phase == 2:
				ring_warning = RING_WARNING
			else:
				_finish_pattern(true)
		return Vector2.ZERO
	if charge_time > 0.0:
		charge_time = maxf(0.0, charge_time - delta)
		return locked_direction * DUEL_CHARGE_SPEED
	if charge_pending:
		# Wall collisions also end a charge; always resolve its follow-up.
		charge_pending = false
		if charge_followups > 0:
			charge_followups -= 1
			_begin_charge(0.52)
		else:
			_finish_pattern()
		return Vector2.ZERO
	if warning_time > 0.0:
		warning_time = maxf(0.0, warning_time - delta)
		if warning_time <= 0.0:
			charge_time = planned_charge_distance / DUEL_CHARGE_SPEED
			charge_pending = true
			charge_has_hit = false
			attacks_fired += 1
		return Vector2.ZERO
	if not is_instance_valid(target): return Vector2.ZERO
	var distance := global_position.distance_to(target.global_position)
	if attack_cooldown <= 0.0 and _clear_shot_to_player():
		if next_attack_shock and distance <= 280.0:
			shock_warning = SHOCK_WARNING
			attacks_started += 1
			return Vector2.ZERO
		if distance <= 720.0:
			charge_followups = 1 if phase == 2 else 0
			next_attack_shock = true
			_begin_charge(0.60 if phase == 1 else 0.52)
			return Vector2.ZERO
	return _chase_direction(delta) * (250.0 if phase == 2 else 220.0)


func _begin_charge(warning: float) -> void:
	if not is_instance_valid(target): return
	locked_direction = global_position.direction_to(target.global_position)
	if locked_direction == Vector2.ZERO: locked_direction = Vector2.RIGHT
	planned_charge_distance = clampf(global_position.distance_to(target.global_position) + 75.0, 140.0, 650.0)
	warning_time = warning
	warning_duration = warning
	attacks_started += 1


func _finish_pattern(pulse := false) -> void:
	if not pulse and brisk_cadence and phase == 1 and next_attack_shock and is_instance_valid(target) and global_position.distance_to(target.global_position) <= 280.0 and _clear_shot_to_player():
		# Staying close after the charge earns a second, separately warned pulse.
		# The counter window begins after the full pair, not between the tells.
		shock_warning = SHOCK_WARNING
		attacks_started += 1
		return
	recovery_time = _attack_delay()
	attack_cooldown = 0.0
	if pulse:
		next_attack_shock = false


func combat_cue() -> String:
	if recovery_time > 0.0: return ""
	if warning_time > 0.0: return "돌진 예고 · 띠 옆으로" + (" / 후속 돌진 주의" if phase == 2 else "")
	if shock_warning > 0.0: return "충격파 · 원 밖으로"
	if ring_warning > 0.0: return "바깥 고리 · 안으로 파고들기"
	if charge_time > 0.0: return "돌진 중"
	return "접근 중"


func _strike_ring() -> void:
	if not is_instance_valid(target): return
	var distance := global_position.distance_to(target.global_position)
	if distance >= RING_INNER_RADIUS and distance <= RING_OUTER_RADIUS and _damage_path_clear():
		target.receive_hit(RING_DAMAGE, global_position)


func _damage_path_clear() -> bool:
	return not zone_path_filter.is_valid() or zone_path_filter.call(global_position, target.global_position)
