extends RefCounted
## Only the portal is debounced. Movement and held input remain untouched.
var armed := true
var guarding_arrival := false
var released := false
var arrival_input := Vector2.ZERO
var arrival_point := Vector2.ZERO
var threshold := Rect2()
var clearance := 0.0
var body_radius := 0.0

func begin(movement: Vector2, point: Vector2, trigger: Rect2, radius: float) -> void:
	armed = false
	guarding_arrival = true
	released = movement.length_squared() < 0.01
	arrival_input = movement.normalized()
	arrival_point = point
	threshold = trigger
	body_radius = radius
	clearance = radius + 60.0

func permits(movement: Vector2, point: Vector2) -> bool:
	if armed: return not guarding_arrival or movement.length_squared() >= 0.01
	if movement.length_squared() < 0.01:
		released = true
		return false # Releasing alone can never trigger a transition.
	var changed := arrival_input != Vector2.ZERO and movement.normalized().dot(arrival_input) < 0.95
	var cleared := not threshold.grow(clearance).has_point(point) and point.distance_to(arrival_point) > body_radius
	if released or changed or cleared: armed = true
	return armed
