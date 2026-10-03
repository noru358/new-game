extends SceneTree
## Prepared only: synthetic Input actions through the unchanged live simulation.
## Idle drawings remain static. This observes pivot/view swaps, not finished animation.
const Adapter = preload("res://game/fennec_idle_adapter.gd")
const ACTIONS := ["move_right", "move_left", "move_up", "move_down", "dash", "attack"]
var failures: Array[String] = []
var samples: Array = []
var records: Array = []
var output := ""
var native := false
var scene: Node3D
var body: Sprite3D
var began := 0
var observed_dash := false
var observed_attack := false
var observed_views: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func input_event(action: String, pressed: bool) -> void:
	if pressed: Input.action_press(action)
	else: Input.action_release(action)
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)

func release_all() -> void:
	for action in ACTIONS: input_event(action, false)

func observe_input_state() -> void:
	# Watch every physics boundary so a short dash cannot be missed when
	# several physics ticks occur between native rendered frames.
	if scene == null or not is_instance_valid(scene.player): return
	observed_dash = observed_dash or scene.player.dash_time > 0.0
	observed_attack = observed_attack or scene.player.attack_step > 0

func sample_pose(label: String, frame: int) -> void:
	var player: SandboxPlayer = scene.player
	var view := str(body.get_meta("fennec_idle_view", ""))
	observed_views[view] = true
	observed_dash = observed_dash or player.dash_time > 0.0
	observed_attack = observed_attack or player.attack_step > 0
	var foot_x := float(Adapter.FOOT_X.get(view, 192.0))
	if body.flip_h: foot_x = Adapter.CANVAS.x - foot_x
	# Godot4.6 flips UVs, not the destination rect: explicit sign compensation.
	var anchor_local := Vector2(foot_x - 192.0 + body.offset.x, 448.0 - 416.0 - 224.0 + body.offset.y)
	check(anchor_local.length() < 0.001, label + " anchored foot " + str(frame))
	check(is_equal_approx(body.pixel_size, Adapter.PIXEL_SIZE), label + " trial size " + str(frame))
	check(body.texture.get_size() == Vector2(384, 448), label + " canvas " + str(frame))
	check(is_equal_approx(player.collision_radius, 30.0), label + " preserved radius " + str(frame))
	samples.append({"phase":label, "frame":frame, "elapsed_ms":Time.get_ticks_msec()-began,
		"player":[player.position.x,player.position.y], "velocity":[player.velocity.x,player.velocity.y],
		"facing":[player.facing.x,player.facing.y], "view":view, "mirrored":body.flip_h,
		"offset":[body.offset.x,body.offset.y], "anchor_local":[anchor_local.x,anchor_local.y],
		"render_ground":scene.camera.unproject_position(body.get_parent().global_position),
		"dash_time":player.dash_time, "attack_step":player.attack_step,
		"attack_sequence":player.attack_sequence, "plane_rotation":body.rotation.z})

func capture(label: String) -> void:
	if native:
		# No indefinite post-draw await. One force-draw and actual PNG dimensions.
		RenderingServer.force_draw(false)
		var image := root.get_texture().get_image()
		check(image != null and image.get_size() == Vector2i(960,540), "PNG size " + label)
		if image != null and image.get_size() == Vector2i(960,540):
			check(image.save_png(output.path_join(label + ".png")) == OK, "PNG save " + label)
	records.append({"view":label,"width":960,"height":540,"native":native})

func phase(label: String, movement: String, frames: int, tap := "") -> void:
	release_all()
	if not movement.is_empty(): input_event(movement, true)
	if not tap.is_empty(): input_event(tap, true)
	for frame in frames:
		if Time.get_ticks_msec() - began > 45000:
			check(false, "bounded motion timeout")
			return
		await physics_frame
		await process_frame
		if frame == 1 and not tap.is_empty(): input_event(tap, false)
		sample_pose(label, frame)
		if frame in [0, frames / 2, frames - 1]: capture("%s-%02d" % [label,frame])
	release_all()

func _run() -> void:
	output = OS.get_environment("FENNEC_OUTPUT")
	if output.is_empty() or not OS.get_user_data_dir().contains("FennecIdle-"):
		printerr("Private UUID userdata and output required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	native = DisplayServer.get_name() != "headless"
	root.size = Vector2i(960,540)
	root.content_scale_size = root.size
	scene = load("res://tests/fennec_idle_preview.tscn").instantiate()
	scene.profile_save_prefix = "user://motion-profile"
	scene.growth_save_prefix = "user://motion-growth"
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene.teleport(Vector2(660,1120))
	body = scene.actors[scene.player].get_node("Body")
	var start: Vector2 = scene.player.position
	var initial_sequence: int = scene.player.attack_sequence
	physics_frame.connect(observe_input_state)
	began = Time.get_ticks_msec()
	await phase("walk-right", "move_right", 12)
	await phase("turn-left", "move_left", 12)
	await phase("turn-back", "move_up", 12)
	await phase("turn-front", "move_down", 12)
	await phase("dash-right", "move_right", 14, "dash")
	await phase("direct-attack", "", 30, "attack")
	await phase("settle", "", 6)
	check(scene.player.position.distance_to(start) > 10.0, "actual input movement")
	check(observed_dash, "actual dash state observed")
	check(observed_attack and scene.player.attack_sequence > initial_sequence, "actual direct attack observed")
	for view in ["front","side","back"]: check(observed_views.has(view), "direction observed " + view)
	release_all()
	physics_frame.disconnect(observe_input_state)
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"native":native,"records":records,"samples":samples,"failures":failures,"claim":"real input observation; static idle art; no acceptance of motion aesthetics"},"  "))
	scene.queue_free()
	current_scene = null
	await process_frame
	print("Fennec input motion failures=",failures.size(),"; native=",native)
	quit(0 if failures.is_empty() else 1)
