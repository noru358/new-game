extends "res://game/main.gd"

const ViewPropScript = preload("res://game/view_prop.gd")
const MODE_NAMES := ["1  HIGH TOPDOWN", "2  MEDIUM OBLIQUE", "3  LOW OBLIQUE"]
const MODE_ZOOMS := [1.05, 1.25, 1.43]
const MODE_PITCHES := [0.0, 0.55, 1.0]
const MODE_LOOKAHEAD := [0.0, 45.0, 70.0]
const PROP_POINTS := [
	Vector2(420, 360), Vector2(720, 520), Vector2(1000, 575),
	Vector2(1270, 755), Vector2(1520, 900), Vector2(1790, 580),
	Vector2(690, 1050), Vector2(1920, 1090), Vector2(1450, 370)
]

var view_mode := 2
var view_props: Array = []
var view_title: Label
var view_detail: Label


func _ready() -> void:
	super._ready()
	player.collision_mask = 4
	for enemy in $Enemies.get_children():
		enemy.collision_mask = 6
	for i in range(PROP_POINTS.size()):
		var prop: Variant = ViewPropScript.new()
		prop.name = "BlockoutProp%d" % i
		prop.position = PROP_POINTS[i]
		prop.footprint_radius = 32.0 if i % 3 != 0 else 39.0
		add_child(prop)
		prop.configure(1 if i % 3 == 0 else 0, MODE_PITCHES[1])
		view_props.append(prop)
	_build_view_ui()
	set_view_mode(view_mode)
	queue_redraw()


func _input(event: InputEvent) -> void:
	super._input(event)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1 or event.keycode == KEY_2 or event.keycode == KEY_3:
			set_view_mode(event.keycode - KEY_1 + 1)
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	super._process(delta)
	var lead: float = MODE_LOOKAHEAD[view_mode - 1]
	camera.position = camera.position.lerp(player.facing * lead + Vector2(0, -lead * 0.22), minf(1.0, 5.0 * delta))
	for prop in view_props:
		var behind: bool = player.global_position.y < prop.global_position.y
		var close_x: bool = absf(player.global_position.x - prop.global_position.x) < prop.footprint_radius * 1.8
		var close_y: bool = prop.global_position.y - player.global_position.y < 90.0
		prop.modulate.a = lerpf(prop.modulate.a, 0.48 if behind and close_x and close_y else 1.0, minf(1.0, 12.0 * delta))


func set_view_mode(mode: int) -> void:
	view_mode = clampi(mode, 1, 3)
	var index := view_mode - 1
	camera.zoom = Vector2.ONE * MODE_ZOOMS[index]
	camera.position_smoothing_speed = [10.0, 8.0, 6.0][index]
	player.visual_pitch = MODE_PITCHES[index]
	player.queue_redraw()
	for enemy in $Enemies.get_children():
		enemy.visual_pitch = MODE_PITCHES[index]
		enemy.queue_redraw()
	for prop in view_props:
		prop.configure(prop.kind, MODE_PITCHES[index])
	if view_title != null:
		view_title.text = MODE_NAMES[index]
		view_detail.text = "ZOOM %.2f  |  FOOTPRINT %d px  |  LOOK AHEAD %d  |  Y SORT + FADE" % [
			MODE_ZOOMS[index], int(36.0 * MODE_ZOOMS[index]), int(MODE_LOOKAHEAD[index])
		]
	queue_redraw()


func _build_view_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)
	var panel := ColorRect.new()
	panel.position = Vector2(710, 12)
	panel.size = Vector2(555, 78)
	panel.color = Color(0.04, 0.13, 0.17, 0.80)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(panel)
	view_title = Label.new()
	view_title.position = Vector2(12, 6)
	view_title.add_theme_font_size_override("font_size", 25)
	view_title.add_theme_color_override("font_color", Color("f7e5b7"))
	panel.add_child(view_title)
	view_detail = Label.new()
	view_detail.position = Vector2(13, 41)
	view_detail.add_theme_font_size_override("font_size", 14)
	view_detail.add_theme_color_override("font_color", Color("d8e9de"))
	panel.add_child(view_detail)
	for child in get_children():
		if child is CanvasLayer and child != canvas:
			for control in child.get_children():
				if control is Label and control.text.begins_with("WASD Move"):
					control.text = "1/2/3 View  |  WASD Move  |  J / Click Attack  |  Space Dash  |  K Combo  |  Esc Pause  |  R Reset"


func _draw() -> void:
	var pitch: float = MODE_PITCHES[view_mode - 1]
	draw_rect(Rect2(Vector2.ZERO, ARENA_SIZE), Color("a5bea9"))
	draw_rect(Rect2(0, 60, 2400, 170), Color("4f8f93"))
	draw_rect(Rect2(0, 1180, 2400, 170), Color("4f8f93"))
	draw_rect(Rect2(240, 255, 1920, 900), Color("c5c8a9"))
	draw_rect(Rect2(280, 300, 1840, 805), Color("cfd0ad"))
	for x in range(280, 2121, 100):
		draw_line(Vector2(x, 300), Vector2(x, 1105), Color(0.25, 0.38, 0.36, 0.23), 2.0)
	for y in range(300, 1106, 80):
		draw_line(Vector2(280, y), Vector2(2120, y), Color(0.25, 0.38, 0.36, 0.23), 2.0)
	for center in [Vector2(700, 700), Vector2(1200, 700), Vector2(1700, 700)]:
		var depth := lerpf(110.0, 58.0, pitch)
		var points := PackedVector2Array()
		for i in range(33):
			var angle := TAU * float(i) / 32.0
			points.append(center + Vector2(cos(angle) * 150.0, sin(angle) * depth))
		draw_colored_polygon(points, Color("dbcda8"))
		draw_polyline(points, Color("71948b"), 4.0, true)
	for x in range(100, 2350, 280):
		draw_line(Vector2(x, 120), Vector2(x + 110, 120), Color("a1c7b5"), 3.0)
		draw_line(Vector2(x + 80, 1250), Vector2(x + 190, 1250), Color("a1c7b5"), 3.0)
	draw_rect(Rect2(Vector2(16, 16), ARENA_SIZE - Vector2(32, 32)), Color("3f706e"), false, 14.0)
