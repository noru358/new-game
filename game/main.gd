extends Node2D

const ARENA_SIZE := Vector2(2400, 1400)

var remaining_enemies := 0
var total_enemies := 0
var game_over := false
var pause_overlay: ColorRect
var pause_title: Label
var pause_message: Label
var pause_button: Button
var status_label: Label
var health_fill: ColorRect
var hurt_edges: Array[ColorRect] = []
var hurt_feedback_time := 0.0
var camera_shake := 0.0
var hitstop_until_usec := 0

@onready var player: SandboxPlayer = $Player
@onready var camera: Camera2D = $Player/Camera2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	$Enemies.process_mode = Node.PROCESS_MODE_PAUSABLE
	_register_inputs()
	total_enemies = $Enemies.get_child_count()
	remaining_enemies = total_enemies
	for enemy in $Enemies.get_children():
		enemy.target = player
		enemy.defeated.connect(_on_enemy_defeated)
	player.defeated.connect(_on_player_defeated)
	player.attack_landed.connect(_on_attack_landed)
	player.hurt_received.connect(_on_player_hurt)
	get_window().focus_exited.connect(_on_window_focus_exited)
	_build_ui()
	queue_redraw()


func _process(delta: float) -> void:
	if hitstop_until_usec > 0 and Time.get_ticks_usec() >= hitstop_until_usec:
		Engine.time_scale = 1.0
		hitstop_until_usec = 0
	status_label.text = "HP %d / 100    FRAGMENTS %d / %d    COMBO %d    DASH %s" % [
		int(player.health), remaining_enemies, total_enemies, player.combo_limit(),
		"READY" if player.dash_cooldown <= 0.0 else "%.1fs" % player.dash_cooldown
	]
	if remaining_enemies == 0:
		status_label.text += "    ARENA CLEAR - R TO RESET"
	health_fill.size.x = 300.0 * player.health / player.MAX_HEALTH
	hurt_feedback_time = maxf(0.0, hurt_feedback_time - delta)
	var edge_color := Color(0.82, 0.13, 0.13, hurt_feedback_time * 1.6)
	for edge in hurt_edges:
		edge.color = edge_color
	camera_shake = maxf(0.0, camera_shake - 26.0 * delta)
	if get_tree().paused:
		camera.offset = Vector2.ZERO
	else:
		var pulse := float(Time.get_ticks_msec()) * 0.11
		camera.offset = Vector2(sin(pulse), cos(pulse * 1.3)) * camera_shake


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if not game_over:
				if get_tree().paused:
					_resume()
				else:
					_pause("PAUSED", "Press Resume or Esc to continue.")
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_R:
			get_viewport().set_input_as_handled()
			_restart()
		elif event.keycode == KEY_K and not get_tree().paused and not game_over:
			player.set_combo_rank((player.combo_rank + 1) % 3)
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_on_window_focus_exited()


func _on_window_focus_exited() -> void:
	if is_inside_tree() and not game_over:
		_pause("PAUSED", "Focus lost. Resume manually when ready.")


func _pause(title: String, message: String) -> void:
	if pause_overlay == null:
		return
	pause_title.text = title
	pause_message.text = message
	pause_button.text = "Resume"
	pause_overlay.show()
	get_tree().paused = true


func _resume() -> void:
	get_tree().paused = false
	pause_overlay.hide()
	player.require_attack_release()


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_enemy_defeated() -> void:
	remaining_enemies -= 1
	if remaining_enemies == 0:
		pause_message.text = "Arena clear. Press R to try again."


func _on_player_defeated() -> void:
	game_over = true
	_pause("TRAINING OVER", "Press R or Restart to retry the sandbox.")
	pause_button.text = "Restart"


func _on_attack_landed(hit_position: Vector2, direction: Vector2, combo_step: int, finisher: bool) -> void:
	_spawn_impact(hit_position, direction, combo_step, false)
	camera_shake = maxf(camera_shake, 3.3 if combo_step == 4 else 2.0 if combo_step == 3 else 3.3 if finisher else 1.7)
	_request_hitstop(0.045 if combo_step == 4 else 0.025 if combo_step == 3 else 0.045 if finisher else 0.028)


func _on_player_hurt(hit_position: Vector2, direction: Vector2) -> void:
	_spawn_impact(hit_position, direction, 1, true)
	hurt_feedback_time = 0.22
	camera_shake = maxf(camera_shake, 4.5)
	_request_hitstop(0.05)


func _spawn_impact(hit_position: Vector2, direction: Vector2, combo_step: int, hurt: bool) -> void:
	var effect := ImpactBurst.new()
	effect.setup(combo_step, hurt, direction)
	add_child(effect)
	effect.global_position = hit_position


func _request_hitstop(duration: float) -> void:
	hitstop_until_usec = maxi(hitstop_until_usec, Time.get_ticks_usec() + int(duration * 1000000.0))
	Engine.time_scale = 0.16


func _on_pause_button_pressed() -> void:
	if game_over:
		_restart()
	else:
		_resume()


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)
	status_label = Label.new()
	status_label.position = Vector2(20, 15)
	status_label.add_theme_font_size_override("font_size", 23)
	status_label.add_theme_color_override("font_color", Color("f9f2d8"))
	status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	status_label.add_theme_constant_override("shadow_offset_x", 2)
	status_label.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(status_label)
	var health_back := ColorRect.new()
	health_back.position = Vector2(20, 48)
	health_back.size = Vector2(304, 16)
	health_back.color = Color("294950")
	health_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(health_back)
	health_fill = ColorRect.new()
	health_fill.position = Vector2(2, 2)
	health_fill.size = Vector2(300, 12)
	health_fill.color = Color("f4bc77")
	health_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_back.add_child(health_fill)
	var controls := Label.new()
	controls.text = "WASD Move  |  J / Left Click Attack (hold)  |  Space Dash  |  K Combo 2/3/4  |  Esc Pause  |  R Reset"
	controls.position = Vector2(20, 672)
	controls.add_theme_font_size_override("font_size", 19)
	controls.add_theme_color_override("font_color", Color("f9f2d8"))
	controls.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	controls.add_theme_constant_override("shadow_offset_x", 2)
	controls.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(controls)
	for bounds in [
		Rect2(0, 0, 1280, 15), Rect2(0, 705, 1280, 15),
		Rect2(0, 0, 15, 720), Rect2(1265, 0, 15, 720)
	]:
		var edge := ColorRect.new()
		edge.position = bounds.position
		edge.size = bounds.size
		edge.color = Color(0.82, 0.13, 0.13, 0.0)
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(edge)
		hurt_edges.append(edge)
	pause_overlay = ColorRect.new()
	pause_overlay.color = Color(0.02, 0.08, 0.11, 0.7)
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(pause_overlay)
	var panel := PanelContainer.new()
	panel.position = Vector2(420, 245)
	panel.custom_minimum_size = Vector2(440, 230)
	pause_overlay.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)
	pause_title = Label.new()
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_title.add_theme_font_size_override("font_size", 34)
	column.add_child(pause_title)
	pause_message = Label.new()
	pause_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_message.add_theme_font_size_override("font_size", 18)
	column.add_child(pause_message)
	pause_button = Button.new()
	pause_button.custom_minimum_size = Vector2(200, 52)
	pause_button.pressed.connect(_on_pause_button_pressed)
	column.add_child(pause_button)
	pause_overlay.hide()


func _register_inputs() -> void:
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("move_up", KEY_W)
	_add_key_action("move_down", KEY_S)
	_add_key_action("attack", KEY_J)
	_add_key_action("dash", KEY_SPACE)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", mouse)


func _add_key_action(action: String, key: Key) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, ARENA_SIZE), Color("b9d5b9"))
	for x in range(0, 2401, 80):
		draw_line(Vector2(x, 0), Vector2(x, 1400), Color(0.35, 0.58, 0.54, 0.19), 2.0)
	for y in range(0, 1401, 80):
		draw_line(Vector2(0, y), Vector2(2400, y), Color(0.35, 0.58, 0.54, 0.19), 2.0)
	draw_rect(Rect2(Vector2(16, 16), ARENA_SIZE - Vector2(32, 32)), Color("497b78"), false, 14.0)
	for position in [Vector2(450, 340), Vector2(1850, 380), Vector2(490, 1080), Vector2(1940, 1110)]:
		draw_arc(position, 70.0, 0.0, TAU, 48, Color(0.13, 0.49, 0.52, 0.36), 5.0)
		draw_arc(position, 37.0, 0.0, TAU, 48, Color(0.13, 0.49, 0.52, 0.25), 4.0)
