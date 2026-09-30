extends RefCounted
## Opt-in, local-only run measurements. No profile writes or gameplay decisions.
## Start a campaign with: godot --path . -- --run-diagnostics
## Run completion prints one RUN_DIAGNOSTICS JSON line to the local console.

var clock: Callable
var started_usec := 0
var last_usec := 0
var mode := "active"
var wall_usec := {"active": 0, "choice": 0, "pause": 0}
var level_heal := 0.0
var level_heal_events := 0
var damage_taken := 0.0
var damage_events := 0
var boss_times: Dictionary = {}
var boss_engagements := 0
var time_scale_min := 1.0
var time_scale_max := 1.0
var finished := false
var result := "IN_PROGRESS"
var final_report: Dictionary = {}


func _init(time_source: Callable = Callable()) -> void:
	clock = time_source if time_source.is_valid() else func(): return Time.get_ticks_usec()
	started_usec = int(clock.call())
	last_usec = started_usec
	time_scale_min = Engine.time_scale
	time_scale_max = Engine.time_scale


func _advance() -> void:
	if finished: return
	var now := maxi(last_usec, int(clock.call()))
	wall_usec[mode] += now - last_usec
	last_usec = now


func observe(arena) -> void:
	if finished: return
	_advance()
	# Focus/manual/retry/receipt pauses take priority over an open card modal.
	var external_pause: bool = arena.paused or (arena.get_tree().paused and not arena.growth.choosing)
	mode = "pause" if external_pause else "choice" if arena.growth.choosing else "active"
	time_scale_min = minf(time_scale_min, Engine.time_scale)
	time_scale_max = maxf(time_scale_max, Engine.time_scale)


func record_level_heal(amount: float) -> void:
	if finished: return
	level_heal += maxf(0.0, amount)
	level_heal_events += 1


func record_damage(amount: float) -> void:
	if finished: return
	damage_taken += maxf(0.0, amount)
	damage_events += 1


func boss_event(event: String, active_seconds: float) -> void:
	if finished: return
	_advance()
	if event == "engage": boss_engagements += 1
	if not boss_times.has(event):
		boss_times[event] = {"active_seconds": active_seconds, "wall_seconds": float(last_usec - started_usec) / 1000000.0}


func snapshot(arena) -> Dictionary:
	if finished: return final_report.duplicate(true)
	observe(arena)
	return _report(arena)


func _report(arena) -> Dictionary:
	return {
		"schema": "local_run_diagnostics_v1", "result": result,
		"region": arena.region_id, "active_seconds": arena.run_time,
		"wall_seconds": float(last_usec - started_usec) / 1000000.0,
		"active_wall_seconds": float(wall_usec.active) / 1000000.0,
		"choice_wall_seconds": float(wall_usec.choice) / 1000000.0,
		"pause_wall_seconds": float(wall_usec.pause) / 1000000.0,
		"time_scale_min": time_scale_min, "time_scale_max": time_scale_max,
		"level_heal_actual": level_heal, "level_heal_events": level_heal_events,
		"damage_taken_actual": damage_taken, "damage_events": damage_events,
		"health": arena.player.health, "max_health": arena.player.max_health,
		"kills": arena.kills, "earned_currency": arena.run_currency,
		"level": arena.growth.level, "xp_remainder": arena.growth.xp,
		"choice_windows": arena.growth.choice_windows_opened,
		"points_earned": arena.growth.points_earned, "points_spent": arena.growth.points_spent,
		"points_exhausted": arena.growth.exhausted_points, "points_pending": arena.growth.pending_choices,
		"cards": arena.growth.selected_card_ranks.duplicate(),
		"weapon": arena.profile.equipped_weapon, "accessory": arena.profile.equipped_accessory,
		"permanent_growth": arena.profile.growth_ranks.duplicate(), "attack_branch": arena.profile.attack_branch,
		"boss_first_times": boss_times.duplicate(true), "boss_engagements": boss_engagements,
	}


func finish(arena, outcome: String) -> Dictionary:
	if not finished:
		observe(arena)
		result = outcome
		final_report = _report(arena)
		finished = true
		print("RUN_DIAGNOSTICS ", JSON.stringify(final_report))
	return snapshot(arena)
