extends Node
## Presentation-only layout for the two live regions. Existing scene/growth
## owners continue to produce every status string and all gameplay state.
## Coordinates use the project's 1280x720 canvas and scale with the window.

const INK := Color("f1f3e8")
const MUTED := Color("c5d4ce")
const SURFACE := Color(0.035, 0.085, 0.09, 0.94)
const TRACK := Color("314447")

var arena: Node3D
var objective_panel: ColorRect
var run_panel: ColorRect
var progress_panel: ColorRect
var build_panel: ColorRect
var help_panel: ColorRect
var controls_hint: Label
var passive_controls: Array[Control] = []


func setup(scene: Node3D) -> void:
	arena = scene
	name = "RunHudPresenter"
	process_mode = Node.PROCESS_MODE_ALWAYS
	scene.add_child(self)
	var base_canvas: CanvasLayer = scene.hud.get_parent()
	var status_panel: ColorRect = base_canvas.get_node("StatusPanel")
	status_panel.position = Vector2(16, 16)
	status_panel.size = Vector2(390, 112)
	status_panel.color = SURFACE
	_passive(status_panel)
	_label(scene.hud, Vector2(32, 26), Vector2(358, 61), 22)
	_bar(scene.player_health_bar, Vector2(32, 101), Vector2(250, 11), Color("ed887b"))
	_label(scene.player_health_warning, Vector2(296, 96), Vector2(94, 26), 18, Color("ffaea1"))

	# Independent, content-sized groups leave the unused bottom area open.
	progress_panel = _panel(base_canvas, "ProgressionSurface", Rect2())
	build_panel = _panel(base_canvas, "BuildSurface", Rect2())
	help_panel = _panel(base_canvas, "HelpSurface", Rect2())
	_label(scene.growth.hud, Vector2.ZERO, Vector2(292, 0), 20)
	_bar(scene.growth.xp_bar, Vector2.ZERO, Vector2(292, 8), Color("e8c67e"))
	_label(scene.build_summary_label, Vector2.ZERO, Vector2(512, 0), 18, MUTED)
	_label(scene.moving_slash_status, Vector2.ZERO, Vector2(382, 0), 17, MUTED)
	controls_hint = base_canvas.get_node("ControlsHint")
	controls_hint.text = "Tab 지도\nEsc 카드 · 장비 · 각성 · 조작"
	_label(controls_hint, Vector2.ZERO, Vector2(262, 0), 18, MUTED)
	scene.minimap.position = Vector2(1022, 16)
	_passive(scene.minimap)

	run_panel = _panel(scene.run_hud.get_parent(), "EncounterSurface", Rect2(422, 16, 584, 110))
	_label(scene.run_hud, Vector2(434, 24), Vector2(552, 0), 20, INK)
	_bar(scene.boss_health_bar, Vector2(438, 122), Vector2(552, 9), Color("e49d6e"))
	if scene.temple_section != null:
		var objective: Label = scene.temple_section.section_hud
		objective_panel = _panel(objective.get_parent(), "ObjectiveSurface", Rect2(16, 140, 390, 78))
		_label(objective, Vector2(32, 151), Vector2(358, 0), 18, MUTED)
	_refresh_surfaces()


func _process(_delta: float) -> void:
	# Text line count can change on a boss phase, field transition, or save error.
	# Resizing its backing must never clip or hide that information.
	_refresh_surfaces()


func _refresh_surfaces() -> void:
	if not is_instance_valid(arena): return
	if objective_panel != null:
		var objective: Label = arena.temple_section.section_hud
		objective_panel.size.y = maxf(52, objective.get_minimum_size().y + 22)
	if run_panel != null:
		_fit_label(arena.run_hud, 244, 552)
		var text_height: float = arena.run_hud.size.y
		arena.boss_health_bar.position = Vector2(434, 24 + text_height + 6)
		arena.boss_health_bar.size.x = arena.run_hud.size.x
		run_panel.size = Vector2(arena.run_hud.size.x + 24, text_height + (31 if arena.boss_health_bar.visible else 16))
	if progress_panel != null:
		var width := clampf(maxf(292, maxf(_text_width(arena.growth.hud), _text_width(arena.moving_slash_status))), 292, 382)
		_fit_label(arena.growth.hud, width, width)
		_fit_label(arena.moving_slash_status, width, width)
		var height: float = arena.growth.hud.size.y + arena.moving_slash_status.size.y + 33
		progress_panel.position = Vector2(16, 704 - height)
		progress_panel.size = Vector2(width + 24, height)
		arena.growth.hud.position = progress_panel.position + Vector2(12, 8)
		arena.growth.xp_bar.position = arena.growth.hud.position + Vector2(0, arena.growth.hud.size.y + 4)
		arena.moving_slash_status.position = arena.growth.xp_bar.position + Vector2(0, 13)
		_bottom_group(build_panel, arena.build_summary_label, 434, 220, 512)
		_bottom_group(help_panel, controls_hint, 986, 0, 262)


func _bottom_group(panel: ColorRect, label: Label, left: float, minimum: float, maximum: float) -> void:
	_fit_label(label, minimum, maximum)
	panel.size = label.size + Vector2(24, 16)
	panel.position = Vector2(left, 704 - panel.size.y)
	label.position = panel.position + Vector2(12, 8)


func _fit_label(label: Label, minimum: float, maximum: float) -> void:
	label.size.x = clampf(_text_width(label), minimum, maximum)
	label.size.y = label.get_minimum_size().y


func _text_width(label: Label) -> float:
	var width := 0.0
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	for line in label.text.split("\n"):
		width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	return ceilf(width) + 2


func _label(label: Label, point: Vector2, extent: Vector2, font_size: int, color: Color = INK) -> void:
	if label == null: return
	label.position = point
	label.size = extent
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_passive(label)


func _bar(bar: ProgressBar, point: Vector2, extent: Vector2, color: Color) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	var background := StyleBoxFlat.new()
	background.bg_color = TRACK
	for style in [fill, background]:
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			style.set_content_margin(side, 0)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", background)
	bar.position = point
	bar.size = extent
	_passive(bar)


func _panel(canvas: CanvasLayer, title: String, bounds: Rect2) -> ColorRect:
	var panel := ColorRect.new()
	panel.name = title
	panel.position = bounds.position
	panel.size = bounds.size
	panel.color = SURFACE
	_passive(panel)
	canvas.add_child(panel)
	canvas.move_child(panel, 0)
	return panel


func _passive(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.focus_mode = Control.FOCUS_NONE
	passive_controls.append(control)
