class_name EnemyZone
extends Node2D

const WARNING := 0.55
const ACTIVE := 1.35
const RADIUS := 92.0
const DAMAGE := 9.0

var source: Node2D
var target: SandboxPlayer
var warning_time := WARNING
var active_time := ACTIVE
var hit_cooldown := 0.0
var damage_path_filter: Callable


func setup(new_source: Node2D, new_target: SandboxPlayer) -> void:
	source = new_source
	target = new_target


func _ready() -> void:
	add_to_group("enemy_zones")


func _physics_process(delta: float) -> void:
	if not is_instance_valid(source) or source.is_queued_for_deletion() or not is_instance_valid(target):
		queue_free()
		return
	if warning_time > 0.0:
		warning_time = maxf(0.0, warning_time - delta)
	else:
		active_time = maxf(0.0, active_time - delta)
		hit_cooldown = maxf(0.0, hit_cooldown - delta)
		if hit_cooldown <= 0.0 and global_position.distance_to(target.global_position) <= RADIUS and (not damage_path_filter.is_valid() or damage_path_filter.call(global_position, target.global_position)):
			target.receive_hit(DAMAGE, global_position)
			hit_cooldown = 0.75
		if active_time <= 0.0:
			queue_free()
	queue_redraw()


func _draw() -> void:
	var active := warning_time <= 0.0
	var color := Color(0.13, 0.86, 0.85, 0.24) if active else Color(0.18, 0.88, 0.84, 0.13)
	draw_circle(Vector2.ZERO, RADIUS, color)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 48, Color("b8fff5") if active else Color("6ee7df"), 5.0 if active else 3.0)
	var progress := 1.0 if active else 1.0 - warning_time / WARNING
	draw_arc(Vector2.ZERO, RADIUS - 12.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 40, Color("ffffff") if active else Color("ddfffb"), 3.0)
