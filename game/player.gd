class_name SandboxPlayer
extends CharacterBody2D

signal defeated
signal health_changed
signal attack_landed(hit_position: Vector2, direction: Vector2, combo_step: int, finisher: bool)
signal hurt_received(hit_position: Vector2, direction: Vector2)

const MAX_HEALTH := 100.0
const MOVE_SPEED := 300.0
const DASH_DISTANCE := 130.0
const DASH_DURATION := 0.16
const DASH_COOLDOWN := 1.2
const DASH_INVULNERABILITY := 0.10
const HURT_INVULNERABILITY := 0.70
const COMBO_RESET_TIME := 0.75
const ATTACK_BUFFER_TIME := 0.18
const ATTACK_DAMAGE := 10.0
const GATHER_FORWARD_OFFSET := 65.0

const ATTACKS := [
	{"windup": 0.06, "active": 0.06, "recovery": 0.16, "radius": 100.0, "angle": 100.0, "multiplier": 1.0},
	{"windup": 0.06, "active": 0.06, "recovery": 0.17, "radius": 105.0, "angle": 100.0, "multiplier": 1.2},
	{"windup": 0.06, "active": 0.06, "recovery": 0.16, "radius": 130.0, "angle": 125.0, "multiplier": 0.5},
	{"windup": 0.08, "active": 0.08, "recovery": 0.20, "radius": 120.0, "angle": 125.0, "multiplier": 1.5},
]

var health := MAX_HEALTH
var visual_pitch := 0.0
var facing := Vector2.RIGHT
var attack_direction := Vector2.RIGHT
var attack_step := 0
var next_combo_step := 1
var combo_rank := 0
var attack_elapsed := 0.0
var gather_target_global := Vector2.ZERO
var gather_sources: Array[Vector2] = []
var gathered_enemies: Array[TrainingEnemy] = []
var combo_wait := 0.0
var attack_lock := 0.0
var queued_attack := false
var attack_buffer_time := 0.0
var dash_requested := false
var attack_blocked_until_release := false
var dash_time := 0.0
var dash_elapsed := 0.0
var dash_cooldown := 0.0
var dash_charges := 1
var dash_max_charges := 1
var dash_direction := Vector2.RIGHT
var hurt_immunity := 0.0
var hit_flash := 0.0
var hurt_stun_time := 0.0
var hurt_recoil := Vector2.ZERO
var impact_played_this_attack := false
var hit_targets: Dictionary = {}
var basic_damage_bonus := 0.0
var basic_speed_bonus := 0.0
var basic_reach_bonus := 0.0
var dash_cooldown_reduction := 0.0
var companion_orbit_time := 0.0
var arena_bounds := Rect2(Vector2.ZERO, Vector2(2400, 1400))
var input_rotation := 0.0
var attack_path_filter: Callable

@onready var attack_audio: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var impact_audio: AudioStreamPlayer = AudioStreamPlayer.new()


func _ready() -> void:
	add_child(attack_audio)
	add_child(impact_audio)
	attack_audio.volume_db = -7.0
	impact_audio.volume_db = -8.0
	attack_audio.max_polyphony = 1
	impact_audio.max_polyphony = 1


func _exit_tree() -> void:
	attack_audio.stop()
	impact_audio.stop()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("attack") and not attack_blocked_until_release:
		queued_attack = true
		attack_buffer_time = ATTACK_BUFFER_TIME
	if event.is_action_pressed("dash"):
		dash_requested = true


func _physics_process(delta: float) -> void:
	if health <= 0.0:
		return
	companion_orbit_time += delta
	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down").rotated(input_rotation)
	if movement.length_squared() > 0.0:
		facing = movement.normalized()
		if attack_step > 0 and (attack_step != 3 or gathered_enemies.is_empty()):
			if attack_step == 3 and not facing.is_equal_approx(attack_direction):
				gather_target_global = global_position + facing * GATHER_FORWARD_OFFSET
			attack_direction = facing
	if attack_blocked_until_release:
		if not Input.is_action_pressed("attack"):
			attack_blocked_until_release = false

	if dash_charges < dash_max_charges:
		dash_cooldown = maxf(0.0, dash_cooldown - delta)
		if dash_cooldown <= 0.0:
			dash_charges += 1
			if dash_charges < dash_max_charges:
				dash_cooldown = dash_recharge_duration()
	else:
		dash_cooldown = 0.0
	if queued_attack:
		attack_buffer_time -= delta
		if attack_buffer_time <= 0.0:
			queued_attack = false
	attack_lock = maxf(0.0, attack_lock - delta)
	hurt_immunity = maxf(0.0, hurt_immunity - delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	hurt_stun_time = maxf(0.0, hurt_stun_time - delta)
	hurt_recoil = hurt_recoil.move_toward(Vector2.ZERO, 2100.0 * delta)

	if dash_requested and dash_charges > 0:
		_start_dash(movement)
	dash_requested = false

	if dash_time > 0.0:
		var dash_motion_time := minf(delta, dash_time)
		dash_elapsed += dash_motion_time
		dash_time = maxf(0.0, dash_time - delta)
		velocity = dash_direction * (DASH_DISTANCE / DASH_DURATION) * (dash_motion_time / delta)
	else:
		velocity = movement * MOVE_SPEED * (0.35 if hurt_stun_time > 0.0 else 1.0) + hurt_recoil
		_update_attack(delta)
	move_and_slide()
	global_position = Vector2(
		clampf(global_position.x, arena_bounds.position.x + 25.0, arena_bounds.end.x - 25.0),
		clampf(global_position.y, arena_bounds.position.y + 25.0, arena_bounds.end.y - 25.0)
	)
	_maintain_gather_spacing()
	queue_redraw()


func _start_dash(movement: Vector2) -> void:
	dash_direction = movement.normalized() if movement.length_squared() > 0.0 else facing
	dash_time = DASH_DURATION
	dash_elapsed = 0.0
	if dash_charges == dash_max_charges:
		dash_cooldown = dash_recharge_duration()
	dash_charges -= 1
	if attack_step > 0:
		var attack := _attack_spec(attack_step)
		var remaining: float = attack.windup + attack.active + attack.recovery - attack_elapsed
		attack_lock = maxf(attack_lock, remaining)
	attack_step = 0
	next_combo_step = 1
	combo_wait = 0.0
	queued_attack = false
	attack_buffer_time = 0.0
	hit_targets.clear()
	gather_sources.clear()
	gathered_enemies.clear()
	_play_sound("res://game/audio/dash.wav", attack_audio)


func dash_recharge_duration() -> float:
	return DASH_COOLDOWN * (1.0 - dash_cooldown_reduction)


func set_dash_upgrade(rank: int) -> void:
	var previous_duration := dash_recharge_duration()
	var previous_capacity := dash_max_charges
	dash_cooldown_reduction = 0.15 if rank == 1 or rank == 2 else 0.30 if rank >= 3 else 0.0
	dash_max_charges = 2 if rank >= 2 else 1
	dash_charges = mini(dash_max_charges, dash_charges + dash_max_charges - previous_capacity)
	if dash_charges >= dash_max_charges:
		dash_cooldown = 0.0
	elif dash_cooldown > 0.0:
		dash_cooldown *= dash_recharge_duration() / previous_duration


func combo_limit() -> int:
	return 2 + combo_rank


func _attack_spec(step: int) -> Dictionary:
	var attack: Dictionary = ATTACKS[step - 1].duplicate()
	var speed_scale := 1.0 + basic_speed_bonus
	attack.windup /= speed_scale
	attack.active /= speed_scale
	attack.recovery /= speed_scale
	attack.radius *= 1.0 + basic_reach_bonus
	return attack


func set_combo_rank(rank: int) -> void:
	combo_rank = clampi(rank, 0, 2)
	attack_step = 0
	next_combo_step = 1
	queued_attack = false
	attack_buffer_time = 0.0
	hit_targets.clear()
	gather_sources.clear()
	gathered_enemies.clear()
	queue_redraw()


func _update_attack(delta: float) -> void:
	if attack_step > 0:
		attack_elapsed += delta
		var attack := _attack_spec(attack_step)
		if attack_elapsed >= attack.windup and attack_elapsed < attack.windup + attack.active:
			_hit_enemies(attack)
		if attack_elapsed >= attack.windup + attack.active + attack.recovery:
			attack_step = 0
			combo_wait = 0.0
	else:
		combo_wait += delta
		if combo_wait > COMBO_RESET_TIME:
			next_combo_step = 1
		if attack_lock <= 0.0 and not attack_blocked_until_release:
			if queued_attack or Input.is_action_pressed("attack"):
				_start_attack()


func _start_attack() -> void:
	attack_step = next_combo_step
	next_combo_step = 1 if attack_step >= combo_limit() else attack_step + 1
	attack_elapsed = 0.0
	attack_direction = facing
	if attack_step == 3:
		gather_target_global = global_position + attack_direction * GATHER_FORWARD_OFFSET
	queued_attack = false
	attack_buffer_time = 0.0
	hit_targets.clear()
	gather_sources.clear()
	gathered_enemies.clear()
	impact_played_this_attack = false
	_play_sound("res://game/audio/attack_%d.wav" % attack_step, attack_audio)


func _hit_enemies(attack: Dictionary) -> void:
	var new_gathered := false
	for enemy in get_tree().get_nodes_in_group("training_enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		var id := enemy.get_instance_id()
		if hit_targets.has(id):
			continue
		var offset: Vector2 = enemy.global_position - global_position
		if offset.length() > attack.radius + enemy.RADIUS:
			continue
		var angle_difference := absf(wrapf(offset.angle() - attack_direction.angle(), -PI, PI))
		if angle_difference > deg_to_rad(attack.angle * 0.5):
			continue
		if attack_path_filter.is_valid() and not attack_path_filter.call(global_position, enemy.global_position):
			continue
		var push_direction := offset.normalized() if offset.length_squared() > 0.01 else attack_direction
		var finisher := attack_step == combo_limit()
		hit_targets[id] = true
		if attack_step == 3:
			gather_sources.append(enemy.global_position)
		enemy.take_hit(ATTACK_DAMAGE * (1.0 + basic_damage_bonus) * attack.multiplier, push_direction, finisher)
		if attack_step == 3 and not enemy.is_queued_for_deletion():
			gathered_enemies.append(enemy)
			new_gathered = true
		var effect_direction: Vector2 = (gather_target_global - enemy.global_position).normalized() if attack_step == 3 else push_direction
		attack_landed.emit(enemy.global_position, effect_direction, attack_step, finisher)
		if not impact_played_this_attack:
			impact_played_this_attack = true
			impact_audio.pitch_scale = 1.22 if attack_step == 3 else 0.82 if finisher else 1.13 if attack_step == 1 else 0.98
			_play_sound("res://game/audio/hit.wav", impact_audio)
	if new_gathered:
		_arrange_gathered_enemies()


func _arrange_gathered_enemies() -> void:
	var living: Array[TrainingEnemy] = []
	for enemy in gathered_enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			living.append(enemy)
	living.sort_custom(func(a: TrainingEnemy, b: TrainingEnemy) -> bool:
		return (a.global_position - gather_target_global).angle() < (b.global_position - gather_target_global).angle()
	)
	gathered_enemies = living
	var count := living.size()
	if count == 0:
		return
	var ring_radius := _gather_ring_radius(count)
	for index in range(count):
		var angle := attack_direction.angle() - PI * 0.5 + float(index) * TAU / float(count)
		living[index].gather_to(gather_target_global + Vector2.from_angle(angle) * ring_radius)


func _gather_ring_radius(count: int) -> float:
	return 0.0 if count <= 1 else maxf(20.0, 20.0 / sin(PI / float(count)))


func _maintain_gather_spacing() -> void:
	if attack_step != 3 or gathered_enemies.is_empty():
		return
	var pulling := false
	for enemy in gathered_enemies:
		if is_instance_valid(enemy) and enemy.gathering:
			pulling = true
			break
	if not pulling:
		return
	var distance_to_center := gather_target_global - global_position
	var forward := distance_to_center.dot(attack_direction)
	var side := (distance_to_center - attack_direction * forward).length()
	var minimum := maxf(GATHER_FORWARD_OFFSET, 45.0 + _gather_ring_radius(gathered_enemies.size()))
	if side >= minimum:
		return
	var needed_forward := sqrt(minimum * minimum - side * side)
	var shift := maxf(0.0, needed_forward - forward)
	if shift <= 0.0:
		return
	var movement := attack_direction * shift
	gather_target_global += movement
	for enemy in gathered_enemies:
		if is_instance_valid(enemy) and enemy.gathering:
			enemy.gather_target += movement


func receive_hit(damage: float, source_position: Vector2 = Vector2.ZERO) -> void:
	if health <= 0.0 or hurt_immunity > 0.0:
		return
	if dash_time > 0.0 and dash_elapsed <= DASH_INVULNERABILITY:
		return
	health = maxf(0.0, health - damage)
	hurt_immunity = HURT_INVULNERABILITY
	hit_flash = 0.25
	hurt_stun_time = 0.11
	var push := global_position - source_position
	if push.length_squared() < 0.01:
		push = -facing
	hurt_recoil = push.normalized() * 225.0
	dash_time = 0.0
	health_changed.emit()
	hurt_received.emit(global_position, push.normalized())
	impact_audio.pitch_scale = 1.0
	_play_sound("res://game/audio/hurt.wav", impact_audio)
	if health <= 0.0:
		defeated.emit()


func require_attack_release() -> void:
	queued_attack = false
	attack_buffer_time = 0.0
	attack_blocked_until_release = true


func _play_sound(path: String, player: AudioStreamPlayer) -> void:
	if DisplayServer.get_name() == "headless":
		return
	player.stop()
	player.stream = load(path)
	player.play()


func _draw() -> void:
	if attack_step > 0:
		_draw_attack()
	var body_color := Color("f5f5e8") if hit_flash > 0.0 else Color("f5db9a")
	if dash_time > 0.0:
		draw_circle(-dash_direction * 25.0, 19.0, Color(0.30, 0.88, 0.86, 0.28))
	if visual_pitch > 0.0:
		var shadow := PackedVector2Array()
		for i in range(25):
			var angle := TAU * float(i) / 24.0
			shadow.append(Vector2(cos(angle) * 20.0, 8.0 + sin(angle) * 10.0))
		draw_colored_polygon(shadow, Color(0.03, 0.10, 0.13, 0.4))
	else:
		draw_circle(Vector2(0, 8), 20.0, Color(0.03, 0.10, 0.13, 0.4))
	draw_circle(Vector2.ZERO, 18.0, Color("355b67"))
	draw_circle(Vector2(0, -4), 13.0, body_color)
	if visual_pitch > 0.0:
		var top := -17.0 - visual_pitch * 19.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(-12, 6), Vector2(-12, top + 12),
			Vector2(12, top + 12), Vector2(12, 6)
		]), Color("355b67"))
		draw_circle(Vector2(0, top + 8), 12.0, body_color)
		draw_circle(Vector2(6, top + 7), 2.8, Color("183944"))
	draw_colored_polygon(PackedVector2Array([
		facing * 23.0,
		facing.rotated(2.4) * 12.0,
		facing.rotated(-2.4) * 12.0
	]), Color("34c8c2"))
	draw_circle(facing * 10.0 + Vector2(0, -5), 3.0, Color("183944"))
	if attack_step > 0:
		_draw_hand_gesture()
	if hit_flash > 0.0:
		draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 30, Color(1.0, 0.32, 0.30, hit_flash * 2.7), 4.0)
	if hurt_immunity > 0.0:
		draw_arc(Vector2.ZERO, 23.0, 0.0, TAU, 32, Color(0.95, 0.86, 0.54, 0.55), 2.0)


func _draw_attack() -> void:
	var attack := _attack_spec(attack_step)
	var windup: float = attack.windup
	var active: float = attack.active
	var recovery: float = attack.recovery
	var radius: float = attack.radius
	var fade := 1.0 if attack_elapsed <= windup + active else 1.0 - (attack_elapsed - windup - active) / recovery
	fade = clampf(fade, 0.0, 1.0)
	if attack_step == 3:
		_draw_gather(attack, fade)
		return
	var center_angle := attack_direction.angle()
	var half_angle := deg_to_rad(attack.angle * 0.5)
	var start_angle := center_angle - half_angle
	var end_angle := center_angle + half_angle
	var color := Color("4edbde") if attack_step == 1 else Color("b392fa") if attack_step == 2 else Color("ffdc82")
	if attack_elapsed < windup:
		var charge := attack_elapsed / windup
		var charge_color := color
		charge_color.a = 0.5 + charge * 0.35
		draw_arc(attack_direction * 23.0, 10.0 + 5.0 * charge, center_angle - 1.0, center_angle + 1.0, 14, charge_color, 3.0)
		return
	var progress := clampf((attack_elapsed - windup) / active, 0.0, 1.0)
	var fill := color
	fill.a = 0.10 * fade
	var vertices := PackedVector2Array([Vector2.ZERO])
	for i in range(25):
		var angle := lerpf(start_angle, end_angle, float(i) / 24.0)
		vertices.append(Vector2.from_angle(angle) * radius)
	draw_colored_polygon(vertices, fill)
	var outline := color
	outline.a = 0.9 * fade
	if attack_step == 4:
		var wave_radius := lerpf(radius * 0.5, radius, progress)
		draw_arc(Vector2.ZERO, wave_radius, start_angle, end_angle, 32, outline, 8.0)
		draw_arc(Vector2.ZERO, wave_radius * 0.77, start_angle, end_angle, 28, outline * Color(1, 1, 1, 0.48), 3.0)
	else:
		var sweep := lerpf(start_angle, end_angle, progress) if attack_step == 1 else lerpf(end_angle, start_angle, progress)
		var tail := sweep - 0.48 if attack_step == 1 else sweep + 0.48
		var arc_start := minf(sweep, tail)
		var arc_end := maxf(sweep, tail)
		var ribbon := PackedVector2Array()
		for i in range(13):
			ribbon.append(Vector2.from_angle(lerpf(arc_start, arc_end, float(i) / 12.0)) * radius)
		for i in range(12, -1, -1):
			ribbon.append(Vector2.from_angle(lerpf(arc_start, arc_end, float(i) / 12.0)) * (radius - 22.0))
		var ribbon_color := color
		ribbon_color.a = 0.48 * fade
		draw_colored_polygon(ribbon, ribbon_color)
		draw_arc(Vector2.ZERO, radius, arc_start, arc_end, 16, outline, 6.0)


func _draw_gather(attack: Dictionary, fade: float) -> void:
	var target := to_local(gather_target_global)
	var windup: float = attack.windup
	var active: float = attack.active
	var radius: float = attack.radius
	var center_angle := attack_direction.angle()
	var half_angle := deg_to_rad(attack.angle * 0.5)
	var color := Color("db9bfa")
	if attack_elapsed < windup:
		var cue := color
		cue.a = 0.5 + attack_elapsed / windup * 0.3
		draw_arc(Vector2.ZERO, radius, center_angle - half_angle, center_angle + half_angle, 30, cue, 3.0)
		draw_circle(target, 9.0, cue)
		return
	var progress := clampf((attack_elapsed - windup) / active, 0.0, 1.0)
	var fan := PackedVector2Array([Vector2.ZERO])
	for i in range(25):
		fan.append(Vector2.from_angle(lerpf(center_angle - half_angle, center_angle + half_angle, float(i) / 24.0)) * radius)
	var fill := color
	fill.a = 0.10 * fade
	draw_colored_polygon(fan, fill)
	var pull_color := color
	pull_color.a = 0.72 * fade
	draw_arc(Vector2.ZERO, radius * (1.0 - progress * 0.55), center_angle - half_angle, center_angle + half_angle, 30, pull_color, 4.0)
	for source in gather_sources:
		draw_line(to_local(source), target, pull_color, 3.0)
	draw_arc(target, lerpf(19.0, 8.0, progress), 0.0, TAU, 24, pull_color, 4.0)
	draw_circle(target, 6.0 * fade, Color(0.98, 0.85, 1.0, 0.75 * fade))


func _draw_hand_gesture() -> void:
	var attack := _attack_spec(attack_step)
	var progress: float = clampf((attack_elapsed - attack.windup) / attack.active, 0.0, 1.0)
	var perpendicular := attack_direction.orthogonal()
	if attack_step == 3:
		var reach := lerpf(18.0, 35.0, progress * 2.0) if progress < 0.5 else lerpf(35.0, 18.0, (progress - 0.5) * 2.0)
		var hand := attack_direction * reach
		draw_line(Vector2.ZERO, hand, Color("f5db9a"), 5.0)
		draw_circle(hand, 5.0, Color("f7e9ff"))
		if progress < 0.5:
			for side in [-1.0, 0.0, 1.0]:
				draw_line(hand, hand + attack_direction * 7.0 + perpendicular * side * 5.0, Color("f7e9ff"), 2.5)
		else:
			draw_arc(hand, 7.0, 0.0, TAU, 16, Color("b158d7"), 3.0)
	elif attack_step == 4:
		for side in [-1.0, 1.0]:
			var shoulder: Vector2 = perpendicular * side * 8.0
			var hand: Vector2 = attack_direction * (17.0 + progress * 14.0) + perpendicular * side * 7.0
			draw_line(shoulder, hand, Color("f5db9a"), 5.0)
			draw_circle(hand, 5.0, Color("fff1c7"))
	else:
		var sweep_side := lerpf(-1.0, 1.0, progress) if attack_step == 1 else lerpf(1.0, -1.0, progress)
		var shoulder := perpendicular * (-sweep_side) * 8.0
		var hand := attack_direction * 25.0 + perpendicular * sweep_side * 14.0
		draw_line(shoulder, hand, Color("f5db9a"), 5.0)
		draw_circle(hand, 5.0, Color("e9ffff") if attack_step == 1 else Color("f1e8ff"))
