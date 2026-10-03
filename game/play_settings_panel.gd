extends CanvasLayer
## Small modal shared by walking camp and the existing combat pause menu.
## Scene owners return early from their _input while is_open() is true.

signal closed
const Preferences = preload("res://game/play_settings.gd")

var preferences = Preferences.new()
var can_resume: Callable
var backdrop: ColorRect
var panel: PanelContainer
var volume_slider: HSlider
var volume_label: Label
var mute_button: CheckButton
var display_choice: OptionButton
var back_button: Button
var save_notice: Label
var _was_paused := false
var _previous_focus: WeakRef


func setup(owner_node: Node, config_path := Preferences.DEFAULT_PATH) -> void:
	name = "PlaySettingsPanel"
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	owner_node.add_child(self)
	preferences.config_path = config_path
	preferences.setup(get_window())
	_build_ui()
	hide()
	set_process_input(false)
	set_process_unhandled_input(false)


func is_open() -> bool:
	return visible


func open(from_control: Control = null) -> void:
	if visible: return
	_was_paused = get_tree().paused
	var focused := from_control if is_instance_valid(from_control) else get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(focused) if focused != null else null
	volume_slider.set_value_no_signal(preferences.volume_percent)
	volume_label.text = "%d%%" % roundi(preferences.volume_percent)
	mute_button.set_pressed_no_signal(preferences.muted)
	display_choice.select(1 if preferences.fullscreen else 0)
	save_notice.text = "변경 내용은 자동으로 저장됩니다" if preferences.last_save_error == OK else "설정을 저장하지 못했습니다"
	get_tree().paused = true
	show()
	set_process_input(true)
	set_process_unhandled_input(true)
	volume_slider.grab_focus()


func close() -> void:
	if not visible: return
	if display_choice.get_popup().visible:
		display_choice.get_popup().hide()
	hide()
	set_process_input(false)
	set_process_unhandled_input(false)
	# A level-up/retry owner may keep the tree paused even when opening directly.
	get_tree().paused = _was_paused or (can_resume.is_valid() and not can_resume.call())
	var focus: Control = _previous_focus.get_ref() if _previous_focus != null else null
	if is_instance_valid(focus) and focus.is_visible_in_tree(): focus.grab_focus()
	else: get_viewport().gui_release_focus()
	_previous_focus = null
	closed.emit()


func handle_input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			if display_choice.get_popup().visible:
				display_choice.get_popup().hide()
			else:
				close()
			get_viewport().set_input_as_handled()
		elif event.keycode not in [KEY_TAB, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_HOME, KEY_END, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_SHIFT]:
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	handle_input(event)


func _unhandled_input(_event: InputEvent) -> void:
	if visible: get_viewport().set_input_as_handled()


func _store() -> void:
	var error: Error = preferences.save_preferences()
	save_notice.text = "변경 내용이 저장되었습니다" if error == OK else "설정을 저장하지 못했습니다"
	save_notice.add_theme_color_override("font_color", Color("c3d4cd") if error == OK else Color("ffc4a3"))


func _build_ui() -> void:
	backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.01, 0.025, 0.035, 0.80)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(576, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("142b30")
	style.border_color = Color("7aaca0")
	style.set_border_width_all(1)
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 18)
	panel.add_child(contents)
	var title := _label("설정", 30, Color("f6e7bf"))
	contents.add_child(title)
	var audio_row := HBoxContainer.new()
	contents.add_child(audio_row)
	var audio_title := _label("전체 음량", 22)
	audio_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	audio_row.add_child(audio_title)
	volume_label = _label("100%", 22)
	audio_row.add_child(volume_label)
	volume_slider = HSlider.new()
	volume_slider.name = "MasterVolume"
	volume_slider.min_value = 0
	volume_slider.max_value = 100
	volume_slider.step = 1
	volume_slider.custom_minimum_size.y = 34
	volume_slider.value_changed.connect(func(value: float):
		preferences.set_volume(value)
		volume_label.text = "%d%%" % roundi(value)
		_store())
	contents.add_child(volume_slider)
	mute_button = CheckButton.new()
	mute_button.name = "Mute"
	mute_button.text = "음소거"
	mute_button.add_theme_font_size_override("font_size", 21)
	mute_button.custom_minimum_size.y = 40
	mute_button.toggled.connect(func(value: bool):
		preferences.set_muted(value)
		_store())
	contents.add_child(mute_button)
	var display_row := HBoxContainer.new()
	display_row.add_theme_constant_override("separation", 28)
	contents.add_child(display_row)
	var display_title := _label("화면 모드", 22)
	display_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	display_row.add_child(display_title)
	display_choice = OptionButton.new()
	display_choice.name = "DisplayMode"
	display_choice.add_item("창 모드")
	display_choice.add_item("전체 화면")
	display_choice.add_theme_font_size_override("font_size", 21)
	display_choice.custom_minimum_size = Vector2(200, 44)
	display_choice.item_selected.connect(func(index: int):
		preferences.set_fullscreen(index == 1)
		_store())
	display_row.add_child(display_choice)
	save_notice = _label("변경 내용은 자동으로 저장됩니다", 16, Color("c3d4cd"))
	save_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_notice.custom_minimum_size.y = 42
	contents.add_child(save_notice)
	back_button = Button.new()
	back_button.name = "Back"
	back_button.text = "돌아가기  [Esc]"
	back_button.custom_minimum_size.y = 50
	back_button.add_theme_font_size_override("font_size", 22)
	back_button.pressed.connect(close)
	contents.add_child(back_button)
	var controls: Array[Control] = [volume_slider, mute_button, display_choice, back_button]
	for index in controls.size():
		controls[index].focus_next = controls[index].get_path_to(controls[(index + 1) % controls.size()])
		controls[index].focus_previous = controls[index].get_path_to(controls[(index - 1 + controls.size()) % controls.size()])


func _label(text: String, font_size: int, color := Color("edf1e7")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
