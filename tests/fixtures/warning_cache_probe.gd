extends "res://game/hybrid_height.gd"
var uncached := false
var ray_calls := 0
func clear_attack(from: Vector2,to: Vector2) -> bool:
	ray_calls+=1
	return super.clear_attack(from,to)
func _ring_segment_clear(center: Vector2,start_angle: float,end_angle: float,radius: float) -> bool:
	if not uncached:return super._ring_segment_clear(center,start_angle,end_angle,radius)
	for angle in [start_angle,(start_angle+end_angle)*0.5,end_angle]:
		if not clear_attack(center,center+Vector2.from_angle(angle)*radius):return false
	return true
