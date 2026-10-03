extends "res://tests/capture_temple_place_sequence.gd"
## Bounded surface comparison on the real production scene/camera/input path.
const Finish = preload("res://game/temple_surface_sample.gd")
var requested_size := Vector2i(960,540)
func _initialize() -> void:
	root.mode = Window.MODE_WINDOWED
	super._initialize()
func _samples() -> Array:
	if not OS.get_cmdline_user_args().has("--full-surface-walk"):
		return [{"name":"04-open-court","point":Vector2(2450,2100)},{"name":"06-cloister","point":Vector2(1450,1350)}]
	return [
		{"name":"03-west-stairs","point":Vector2(1650,2275)},
		{"name":"04-open-court","point":Vector2(2450,2100)},
		{"name":"06-cloister","point":Vector2(1450,1350)},
		{"name":"08-gallery-turn","point":Vector2(1650,910)},
		{"name":"09-sanctuary-reveal","point":Vector2(2650,1000)},
		{"name":"10-human-door","point":Vector2(2800,460)},
	]
func _walk(goal: Vector2) -> void:
	# An automated off-focus window must not invoke the ordinary focus-loss pause.
	# This fixture policy is identical for both variants; product pause is untouched.
	for connection in root.focus_exited.get_connections(): root.focus_exited.disconnect(connection.callable)
	scene._set_paused(false)
	Finish.install(scene)
	await super._walk(goal)
func _capture_checkpoint(label: String, width: int, record: Dictionary) -> void:
	requested_size = Vector2i(width,width*9/16)
	root.size = requested_size
	for i in 5: await process_frame
	await super._capture_checkpoint(label,width,record)
func _image() -> Image:
	# macOS Window.size can briefly differ from the GL drawable during native resize.
	# Wait for the exact requested drawable; never rescale/crop a wrong-size frame.
	for attempt in 30:
		if root.size != requested_size: root.size = requested_size
		for i in 3: await process_frame
		# Explicitly draw the test viewport even when this test window is occluded.
		# Waiting on frame_post_draw can stall on macOS's occluded-window policy.
		RenderingServer.force_draw(false)
		var frame := root.get_texture().get_image()
		if frame != null and not frame.is_empty() and frame.get_size() == requested_size: return frame
		if attempt == 0: print("WINDOW_SETTLE: requested=",requested_size," window=",root.size," drawable=",frame.get_size() if frame != null else Vector2i.ZERO)
	errors.append("Exact native drawable failed to settle at "+str(requested_size))
	return null
