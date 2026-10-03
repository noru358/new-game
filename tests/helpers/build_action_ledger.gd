extends RefCounted
## Test-only observation. Never writes profiles or influences combat.
var health: Dictionary = {}
var damage: Dictionary = {}
var events: Array = []
var starts: Dictionary = {}
var hit_actions: Dictionary = {}
var finished: Dictionary = {}
var refunds: Array = []

func register(target_id: int, initial_health: float) -> void:
	health[target_id] = initial_health

func hit(target_id: int, after: float, source: String, action_id: int, active: float) -> void:
	if not health.has(target_id):
		events.append({"source": "unregistered", "target": target_id, "active": active})
		return
	var before: float = health[target_id]
	var raw := maxf(0.0, before - after)
	if raw <= 0.0: return
	var effective := minf(maxf(0.0, before), raw)
	if not damage.has(source): damage[source] = {"raw": 0.0, "effective": 0.0, "overkill": 0.0, "hits": 0}
	damage[source].raw += raw
	damage[source].effective += effective
	damage[source].overkill += raw - effective
	damage[source].hits += 1
	health[target_id] = after
	var key := "%s:%d" % [source, action_id]
	hit_actions[key] = true
	events.append({"source": source, "action": action_id, "target": target_id, "active": active, "raw": raw, "effective": effective, "overkill": raw - effective})

func begin(source: String, action_id: int, active: float, detail: Dictionary = {}) -> void:
	starts["%s:%d" % [source, action_id]] = {"source": source, "action": action_id, "active": active, "detail": detail.duplicate(true)}

func finish(source: String, action_id: int, active: float, interrupted: bool) -> void:
	var key := "%s:%d" % [source, action_id]
	if not starts.has(key) or finished.has(key): return
	finished[key] = {"active": active, "interrupted": interrupted, "hit": hit_actions.has(key)}

func refund(before: float, after: float, active: float, action_id: int) -> void:
	refunds.append({"before": before, "after": after, "saved": maxf(0.0, before - after), "active": active, "action": action_id})

func snapshot() -> Dictionary:
	var actions := {}
	for key in starts:
		var start: Dictionary = starts[key]
		var source: String = start.source
		if not actions.has(source): actions[source] = {"started": 0, "hitting": 0, "missed_completed": 0, "interrupted": 0, "pending": 0}
		actions[source].started += 1
		if hit_actions.has(key): actions[source].hitting += 1
		if not finished.has(key): actions[source].pending += 1
		elif finished[key].interrupted: actions[source].interrupted += 1
		elif not finished[key].hit: actions[source].missed_completed += 1
	var saved := 0.0
	for entry in refunds: saved += float(entry.saved)
	return {"damage": damage.duplicate(true), "actions": actions, "refund_events": refunds.size(), "refund_effective_seconds": saved, "starts": starts.duplicate(true), "finished": finished.duplicate(true), "events": events.duplicate(true), "refunds": refunds.duplicate(true)}
