extends "res://game/enemy_zone.gd"
## The same readable 92-unit ground tell, with boss damage and encounter ownership.
const ROOT_DAMAGE := 18.0
var announced := false
func _physics_process(delta: float) -> void:
	if not is_instance_valid(source) or source.is_queued_for_deletion() or not is_instance_valid(target):
		queue_free()
		return
	if not source.encounter_active or (source.encounter_area.has_area() and not source.encounter_area.has_point(target.global_position)):
		queue_free()
		return
	if warning_time > 0.0:
		warning_time = maxf(0.0, warning_time - delta)
	else:
		if not announced:
			announced = true
			source.attacks_fired += 1
		active_time = maxf(0.0, active_time - delta)
		hit_cooldown = maxf(0.0, hit_cooldown - delta)
		if hit_cooldown <= 0.0 and global_position.distance_to(target.global_position) <= RADIUS and (not damage_path_filter.is_valid() or damage_path_filter.call(global_position, target.global_position)):
			target.receive_hit(ROOT_DAMAGE, global_position)
			hit_cooldown = 0.75
		if active_time <= 0.0: queue_free()
	queue_redraw()
