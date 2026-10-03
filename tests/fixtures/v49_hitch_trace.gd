extends RefCounted
## QA only. Loaded by an ephemeral instrumented source copy, never production.
static var origin_usec: int = 0
static var events: Array = []
static var dropped: int = 0
const LIMIT := 80000
const WINDOW_USEC := 26000000

static func reset() -> void:
	origin_usec = Time.get_ticks_usec()
	events.clear()
	dropped = 0

static func begin() -> int:
	if origin_usec == 0 or Time.get_ticks_usec() - origin_usec > WINDOW_USEC: return 0
	return Time.get_ticks_usec()

static func finish(label: String, start_usec: int, detail: Variant = null) -> void:
	if start_usec == 0: return
	var end_usec := Time.get_ticks_usec()
	if events.size() >= LIMIT:
		dropped += 1
		return
	events.append([label, start_usec - origin_usec, end_usec - origin_usec,
		Engine.get_process_frames(), Engine.get_physics_frames(), Engine.get_frames_drawn(), detail])

static func mark(label: String, detail: Variant = null) -> void:
	finish(label, begin(), detail)

static func report() -> Dictionary:
	return {"columns": ["label", "start_usec", "end_usec", "process_frame", "physics_frame", "frames_drawn", "detail"],
		"origin_usec": origin_usec, "events": events, "dropped": dropped,
		"scope": "QA script spans and render signal boundaries; CPU wall duration includes waits and is not GPU time or full engine main-thread time"}
