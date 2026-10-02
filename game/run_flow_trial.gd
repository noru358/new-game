extends RefCounted
## Unmounted developer comparison. No scene, profile, rewards, or clock writes.
## The integrator owns boss preparation and its existing warning/safety checks.
const BASELINE_DEADLINE := 300.0
const COMPRESSED_DEADLINE := 240.0
var enabled := false


func boss_deadline() -> float:
	return COMPRESSED_DEADLINE if enabled else BASELINE_DEADLINE


func should_prepare_boss(active_seconds: float, _inside_destination: bool, _in_side_area: bool) -> bool:
	return active_seconds >= boss_deadline()


static func xp_for_choices(count: int) -> int:
	var n := maxi(0, count)
	return n * (n + 7)
