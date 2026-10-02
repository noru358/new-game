class_name WetlandBoss
extends "res://game/gate_boss.gd"
## A root-bound stone face: place ground tells, move out, then close for a counter.
## Independent candidate. Ordinary temple and jungle bosses remain unchanged.
const RootStrike = preload("res://game/wetland_boss_root.gd")
const ROOT_INTERVAL := 0.65
const ROOT_REACH := 640.0
var roots_remaining := 0
var root_clock := 0.0
var pattern_active := false
var last_root_point := Vector2.ZERO

func suspend_encounter() -> void:
	super.suspend_encounter()
	roots_remaining = 0
	root_clock = 0.0
	pattern_active = false

func _attack_delay() -> float:
	return 1.35

func _beast_velocity(delta: float) -> Vector2:
	if recovery_time > 0.0:
		recovery_time = maxf(0.0, recovery_time - delta)
		return Vector2.ZERO
	if pattern_active:
		root_clock = maxf(0.0, root_clock - delta)
		if root_clock <= 0.0:
			if roots_remaining > 0:
				_place_root()
				roots_remaining -= 1
				root_clock = ROOT_INTERVAL if roots_remaining > 0 else EnemyZone.WARNING
			else:
				pattern_active = false
				recovery_time = _attack_delay()
				attack_cooldown = 0.0
		return Vector2.ZERO
	if not is_instance_valid(target): return Vector2.ZERO
	if attack_cooldown <= 0.0 and global_position.distance_to(target.global_position) <= ROOT_REACH:
		pattern_active = true
		roots_remaining = 3 if phase == 1 else 5
		root_clock = 0.0
		return Vector2.ZERO
	return _chase_direction(delta) * 130.0

func _place_root() -> void:
	if not is_instance_valid(target) or projectile_parent == null: return
	var point := target.global_position
	if encounter_area.has_area():
		var safe := encounter_area.grow(-EnemyZone.RADIUS - 8.0)
		point = point.clamp(safe.position, safe.end)
	var root := RootStrike.new()
	root.position = point
	root.setup(self, target)
	root.damage_path_filter = zone_path_filter
	projectile_parent.add_child(root)
	last_root_point = point
	attacks_started += 1

func combat_cue() -> String:
	return "뿌리 솟음 · 표시 밖으로 이동" if pattern_active else ""
