extends "res://game/main.gd"

const ViewPropScript = preload("res://game/view_prop.gd")
const WispScript = preload("res://game/wisp.gd")
const GrowthScript = preload("res://game/run_growth.gd")
const EnemyScene = preload("res://game/enemy.tscn")
const NavigationScript = preload("res://game/arena_navigation.gd")
const CAMERA_ZOOM := 1.25
const VIEW_PITCH := 0.55
const CAMERA_LOOKAHEAD := 45.0
const PROP_POINTS := [
	Vector2(420, 360), Vector2(720, 520), Vector2(1000, 575),
	Vector2(1270, 755), Vector2(1520, 900), Vector2(1790, 580),
	Vector2(690, 1050), Vector2(1920, 1090), Vector2(1450, 370)
]
const PRACTICE_ENEMIES := [
	Vector2(850, 520), Vector2(1600, 610), Vector2(1040, 1080),
	Vector2(1800, 980), Vector2(1620, 620), Vector2(1620, 780),
	Vector2(1010, 960), Vector2(1740, 700)
]
const PRACTICE_ROLES := [
	TrainingEnemy.Role.FRAGMENT, TrainingEnemy.Role.FRAGMENT, TrainingEnemy.Role.FRAGMENT,
	TrainingEnemy.Role.LAMP, TrainingEnemy.Role.BEAST, TrainingEnemy.Role.LAMP,
	TrainingEnemy.Role.ZONE, TrainingEnemy.Role.SUPPORT
]
const PRACTICE_HEALTH := [22.0, 22.0, 22.0, 30.0, 45.0, 30.0, 32.0, 36.0]

var view_props: Array = []
var wisp_status: Label
var wave_hint: Label
var wisp: Variant
var growth: RunGrowth
var arena_navigation: ArenaNavigation


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
		prop.configure(1 if i % 3 == 0 else 0, VIEW_PITCH)
		view_props.append(prop)
	arena_navigation = NavigationScript.new()
	arena_navigation.setup(view_props)
	for enemy in $Enemies.get_children():
		enemy.navigation = arena_navigation
		enemy.visual_pitch = VIEW_PITCH
		enemy.queue_redraw()
	camera.zoom = Vector2.ONE * CAMERA_ZOOM
	camera.position_smoothing_speed = 8.0
	player.visual_pitch = VIEW_PITCH
	player.queue_redraw()
	_build_view_ui()
	wisp = WispScript.new()
	wisp.name = "Wisp"
	wisp.player = player
	wisp.navigation = arena_navigation
	wisp.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(wisp)
	growth = GrowthScript.new()
	growth.name = "RunGrowth"
	growth.setup(self, player, wisp)
	add_child(growth)
	for enemy in $Enemies.get_children():
		enemy.defeated.connect(growth.on_enemy_defeated.bind(enemy))
	queue_redraw()


func _input(event: InputEvent) -> void:
	if growth != null and growth.choosing:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode >= KEY_1 and event.keycode <= KEY_3:
				growth.choose_index(event.keycode - KEY_1)
				get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_K:
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_N and remaining_enemies == 0 and not get_tree().paused:
			_next_practice_wave()
			get_viewport().set_input_as_handled()
			return
	super._input(event)


func _on_window_focus_exited() -> void:
	if growth != null and growth.choosing:
		return
	super._on_window_focus_exited()


func _process(delta: float) -> void:
	super._process(delta)
	status_label.text = status_label.text.replace("FRAGMENTS", "ENEMIES")
	status_label.text = status_label.text.replace("    ARENA CLEAR - R TO RESET", "")
	if wave_hint != null:
		wave_hint.visible = remaining_enemies == 0
	var lead := CAMERA_LOOKAHEAD
	camera.position = camera.position.lerp(player.facing * lead + Vector2(0, -lead * 0.22), minf(1.0, 5.0 * delta))
	for prop in view_props:
		var behind: bool = player.global_position.y < prop.global_position.y
		var close_x: bool = absf(player.global_position.x - prop.global_position.x) < prop.footprint_radius * 1.8
		var close_y: bool = prop.global_position.y - player.global_position.y < 90.0
		prop.modulate.a = lerpf(prop.modulate.a, 0.48 if behind and close_x and close_y else 1.0, minf(1.0, 12.0 * delta))
	if wisp_status != null and wisp != null:
		wisp_status.text = "WISP %d  |  AUTO SHOT  |  %s" % [
			growth.wisps.size() if growth != null else 1,
			"READY" if wisp.fire_cooldown <= 0.0 else "%.1fs" % wisp.fire_cooldown
		]


func _next_practice_wave() -> void:
	total_enemies = PRACTICE_ENEMIES.size()
	remaining_enemies = total_enemies
	for i in range(PRACTICE_ENEMIES.size()):
		var enemy: TrainingEnemy = EnemyScene.instantiate()
		enemy.name = "PracticeEnemy%d" % i
		enemy.role = PRACTICE_ROLES[i]
		enemy.max_health = PRACTICE_HEALTH[i]
		enemy.position = PRACTICE_ENEMIES[i]
		enemy.target = player
		enemy.collision_mask = 6
		enemy.navigation = arena_navigation
		enemy.visual_pitch = VIEW_PITCH
		$Enemies.add_child(enemy)
		enemy.defeated.connect(_on_enemy_defeated)
		enemy.defeated.connect(growth.on_enemy_defeated.bind(enemy))


func diamond_grid_point(u: int, v: int) -> Vector2:
	return Vector2(1200.0 + float(u - v) * 80.0, 700.0 + float(u + v) * 40.0)


func _build_view_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)
	var panel := ColorRect.new()
	panel.position = Vector2(760, 12)
	panel.size = Vector2(505, 94)
	panel.color = Color(0.04, 0.13, 0.17, 0.80)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(panel)
	var role_title := Label.new()
	role_title.position = Vector2(12, 5)
	role_title.text = "적 행동"
	role_title.add_theme_font_size_override("font_size", 20)
	role_title.add_theme_color_override("font_color", Color("f7e5b7"))
	panel.add_child(role_title)
	var role_detail := Label.new()
	role_detail.position = Vector2(13, 36)
	role_detail.text = "붉은 뿔: 돌진   ·   금빛 등불: 사격\n청록 원: 장판   ·   보라 고리: 적 강화"
	role_detail.add_theme_font_size_override("font_size", 16)
	role_detail.add_theme_color_override("font_color", Color("d8e9de"))
	panel.add_child(role_detail)
	wisp_status = Label.new()
	wisp_status.position = Vector2(20, 77)
	wisp_status.add_theme_font_size_override("font_size", 17)
	wisp_status.add_theme_color_override("font_color", Color("e8f7bd"))
	wisp_status.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	canvas.add_child(wisp_status)
	wave_hint = Label.new()
	wave_hint.position = Vector2(875, 116)
	wave_hint.text = "훈련 완료 · N 다음 배치"
	wave_hint.add_theme_font_size_override("font_size", 18)
	wave_hint.add_theme_color_override("font_color", Color("e8f7bd"))
	wave_hint.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	wave_hint.hide()
	canvas.add_child(wave_hint)
	for child in get_children():
		if child is CanvasLayer and child != canvas:
			for control in child.get_children():
				if control is Label and control.text.begins_with("WASD Move"):
					control.text = "WASD Move  |  J / Click Attack  |  Space Dash  |  N Next Wave  |  Esc Pause  |  R Reset"


func _draw() -> void:
	_draw_diamond_ground()
	draw_rect(Rect2(Vector2(16, 16), ARENA_SIZE - Vector2(32, 32)), Color("3f706e"), false, 14.0)


func _draw_diamond_ground() -> void:
	const TILE_HALF_WIDTH := 80.0
	const TILE_HALF_HEIGHT := 40.0
	draw_rect(Rect2(Vector2.ZERO, ARENA_SIZE), Color("6a9b97"))
	for u in range(-24, 25):
		for v in range(-24, 25):
			var center := diamond_grid_point(u, v)
			if center.x < -TILE_HALF_WIDTH or center.x > ARENA_SIZE.x + TILE_HALF_WIDTH:
				continue
			if center.y < -TILE_HALF_HEIGHT or center.y > ARENA_SIZE.y + TILE_HALF_HEIGHT:
				continue
			var water := center.y < 235.0 or center.y > 1180.0
			var margin := center.x < 250.0 or center.x > 2150.0
			var color := Color("599492") if water else Color("abc3ad") if margin else Color("cbd0ae")
			if (u + v) % 3 == 0:
				color = color.lightened(0.055)
			var points := PackedVector2Array([
				center + Vector2(0, -TILE_HALF_HEIGHT),
				center + Vector2(TILE_HALF_WIDTH, 0),
				center + Vector2(0, TILE_HALF_HEIGHT),
				center + Vector2(-TILE_HALF_WIDTH, 0)
			])
			draw_colored_polygon(points, color)
			draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color(0.28, 0.43, 0.41, 0.20), 1.5)
	for center in [Vector2(700, 700), Vector2(1200, 700), Vector2(1700, 700)]:
		var plaza := PackedVector2Array([
			center + Vector2(0, -92), center + Vector2(180, 0),
			center + Vector2(0, 92), center + Vector2(-180, 0)
		])
		draw_colored_polygon(plaza, Color("decfa8"))
		draw_polyline(PackedVector2Array([plaza[0], plaza[1], plaza[2], plaza[3], plaza[0]]), Color("688e85"), 4.0)
