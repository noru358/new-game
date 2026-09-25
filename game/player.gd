class_name SandboxPlayer
extends CharacterBody2D

signal defeated
signal health_changed

const MAX_HEALTH := 100.0
const MOVE_SPEED := 300.0
const DASH_DISTANCE := 130.0
const DASH_DURATION := 0.16
const DASH_COOLDOWN := 1.2
const DASH_INVULNERABILITY := 0.10
const HURT_INVULNERABILITY := 0.55
const COMBO_RESET_TIME := 0.75
const ATTACK_DAMAGE := 10.0

const ATTACKS := [
	{"windup": 0.06, "active": 0.06, "recovery": 0.16, "radius": 100.0, "angle": 100.0, "multiplier": 1.0},
	{"windup": 0.06, "active": 0.06, "recovery": 0.16, "radius": 100.0, "angle": 100.0, "multiplier": 1.0},
	{"windup": 0.08, "active": 0.08, "recovery": 0.20, "radius": 120.0, "angle": 125.0, "multiplier": 1.5},
]

var health := MAX_HEALTH
var facing := Vector2.RIGHT
var attack_direction := Vector2.RIGHT
var attack_step := 0
var next_combo_step := 1
var attack_elapsed := 0.0
var combo_wait := 0.0
var attack_lock := 0.0
var queued_attack := false
var dash_requested := false
var attack_blocked_until_release := false
var dash_time := 0.0
var dash_elapsed := 0.0
var dash_cooldown := 0.0
var dash_direction := Vector2.RIGHT
var hurt_immunity := 0.0
var hit_flash := 0.0
var hit_targets: Dictionary = {}

@onready var attack_audio: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var impact_audio: AudioStreamPlayer = AudioStreamPlayer.new()


func _ready() -> void:
	add_child(attack_audio)
	add_child(impact_audio)
	attack_audio.volume_db = -7.0
	impact_audio.volume_db = -8.0
	attack_audio.max_polyphony = 4
	impact_audio.max_polyphony = 4


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("attack") and not attack_blocked_until_release:
		queued_attack = true
	if event.is_action_pressed("dash"):
		dash_requested = true


func _physics_process(delta: float) -> void:
	if health <= 0.0:
		return
	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if movement.length_squared() > 0.0:
		facing = movement.normalized()
	if attack_blocked_until_release:
		if not Input.is_action_pressed("attack"):
			attack_blocked_until_release = false

	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	attack_lock = maxf(0.0, attack_lock - delta)
	hurt_immunity = maxf(0.0, hurt_immunity - delta)
	hit_flash = maxf(0.0, hit_flash - delta)

	if dash_requested and dash_cooldown <= 0.0:
		_start_dash(movement)
	dash_requested = false

	if dash_time > 0.0:
		var dash_motion_time := minf(delta, dash_time)
		dash_elapsed += dash_motion_time
		dash_time = maxf(0.0, dash_time - delta)
		velocity = dash_direction * (DASH_DISTANCE / DASH_DURATION) * (dash_motion_time / delta)
	else:
		velocity = movement * MOVE_SPEED
		_update_attack(delta)
	move_and_slide()
	global_position = Vector2(
		clampf(global_position.x, 25.0, 2375.0),
		clampf(global_position.y, 25.0, 1375.0)
	)
	queue_redraw()


func _start_dash(movement: Vector2) -> void:
	dash_direction = movement.normalized() if movement.length_squared() > 0.0 else facing
	dash_time = DASH_DURATION
	dash_elapsed = 0.0
	dash_cooldown = DASH_COOLDOWN
	if attack_step > 0:
		var attack: Dictionary = ATTACKS[attack_step - 1]
		var remaining: float = attack.windup + attack.active + attack.recovery - attack_elapsed
		attack_lock = maxf(attack_lock, remaining)
	attack_step = 0
	next_combo_step = 1
	combo_wait = 0.0
	queued_attack = false
	hit_targets.clear()
	_play_sound("res://game/audio/dash.wav", attack_audio)


func _update_attack(delta: float) -> void:
	if attack_step > 0:
		attack_elapsed += delta
		var attack: Dictionary = ATTACKS[attack_step - 1]
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
	next_combo_step = 1 if attack_step == 3 else attack_step + 1
	attack_elapsed = 0.0
	attack_direction = facing
	queued_attack = false
	hit_targets.clear()
	_play_sound("res://game/audio/attack_%d.wav" % attack_step, attack_audio)


func _hit_enemies(attack: Dictionary) -> void:
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
		hit_targets[id] = true
		enemy.take_hit(ATTACK_DAMAGE * attack.multiplier, offset.normalized(), attack_step == 3)
		_play_sound("res://game/audio/hit.wav", impact_audio)


func receive_hit(damage: float) -> void:
	if health <= 0.0 or hurt_immunity > 0.0:
		return
	if dash_time > 0.0 and dash_elapsed <= DASH_INVULNERABILITY:
		return
	health = maxf(0.0, health - damage)
	hurt_immunity = HURT_INVULNERABILITY
	hit_flash = 0.16
	health_changed.emit()
	_play_sound("res://game/audio/hurt.wav", impact_audio)
	if health <= 0.0:
		defeated.emit()


func require_attack_release() -> void:
	queued_attack = false
	attack_blocked_until_release = true


func _play_sound(path: String, player: AudioStreamPlayer) -> void:
	player.stream = load(path)
	player.play()


func _draw() -> void:
	if attack_step > 0:
		_draw_attack()
	var body_color := Color("f5f5e8") if hit_flash > 0.0 else Color("f5db9a")
	if dash_time > 0.0:
		draw_circle(-dash_direction * 25.0, 19.0, Color(0.30, 0.88, 0.86, 0.28))
	draw_circle(Vector2(0, 8), 20.0, Color(0.03, 0.10, 0.13, 0.4))
	draw_circle(Vector2.ZERO, 18.0, Color("355b67"))
	draw_circle(Vector2(0, -4), 13.0, body_color)
	draw_colored_polygon(PackedVector2Array([
		facing * 23.0,
		facing.rotated(2.4) * 12.0,
		facing.rotated(-2.4) * 12.0
	]), Color("34c8c2"))
	draw_circle(facing * 10.0 + Vector2(0, -5), 3.0, Color("183944"))
	if hurt_immunity > 0.0:
		draw_arc(Vector2.ZERO, 23.0, 0.0, TAU, 32, Color(0.95, 0.86, 0.54, 0.55), 2.0)


func _draw_attack() -> void:
	var attack: Dictionary = ATTACKS[attack_step - 1]
	var fade: float = 1.0 - attack_elapsed / (attack.windup + attack.active + attack.recovery)
	var alpha: float = clampf(fade, 0.0, 1.0) * 0.42
	var center_angle := attack_direction.angle()
	var half_angle := deg_to_rad(attack.angle * 0.5)
	var start_angle := center_angle - half_angle
	var end_angle := center_angle + half_angle
	var color := Color("4edbde") if attack_step == 1 else Color("b392fa") if attack_step == 2 else Color("ffdc82")
	var fill := color
	fill.a = alpha
	var vertices := PackedVector2Array([Vector2.ZERO])
	for i in range(25):
		var angle := lerpf(start_angle, end_angle, float(i) / 24.0)
		vertices.append(Vector2.from_angle(angle) * attack.radius)
	draw_colored_polygon(vertices, fill)
	var outline := color
	outline.a = minf(1.0, alpha * 2.0)
	draw_arc(Vector2.ZERO, attack.radius, start_angle, end_angle, 32, outline, 5.0 if attack_step == 3 else 3.0)
	if attack_step == 2:
		draw_arc(Vector2.ZERO, attack.radius * 0.7, start_angle, end_angle, 24, outline, 2.0)
	elif attack_step == 3:
		draw_arc(Vector2.ZERO, attack.radius * 0.55, start_angle, end_angle, 24, outline, 3.0)
