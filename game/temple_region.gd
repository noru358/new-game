extends "res://game/view_prototype.gd"

const TempleBlockScript = preload("res://game/temple_block.gd")
const MinimapScript = preload("res://game/temple_minimap.gd")
const DIAMOND_ANGLE := 0.463647609
const GROUND_REDRAW_DISTANCE := 96.0
const REGION_SIZE := Vector2(3840, 2160)
const PLAYER_START := Vector2(760, 1190)
const ENEMY_POINTS := [
	Vector2(1180, 1080), Vector2(1850, 930), Vector2(2230, 940),
	Vector2(3090, 1100), Vector2(1580, 710), Vector2(2670, 1120),
	Vector2(2070, 1570), Vector2(3160, 1180)
]
const PILLAR_POINTS := [
	Vector2(570, 1030), Vector2(900, 930), Vector2(970, 1380),
	Vector2(1400, 990), Vector2(1800, 820), Vector2(1940, 1330),
	Vector2(2350, 1110), Vector2(2650, 760), Vector2(2650, 1410),
	Vector2(3040, 810), Vector2(3290, 1330)
]
const WATER_AREAS := [
	Rect2(280, 450, 650, 120), Rect2(1110, 800, 530, 120),
	Rect2(350, 1710, 760, 120), Rect2(1270, 1300, 560, 120),
	Rect2(2110, 330, 310, 160)
]
const WATER_ANGLES := [DIAMOND_ANGLE, DIAMOND_ANGLE, -DIAMOND_ANGLE, -DIAMOND_ANGLE, DIAMOND_ANGLE]
const WALL_AREAS := [
	Rect2(2500, 880, 230, 50), Rect2(2500, 1260, 230, 50),
	Rect2(3120, 925, 540, 52), Rect2(3120, 1183, 540, 52),
	Rect2(2740, 680, 240, 50)
]
const WALL_ANGLES := [DIAMOND_ANGLE, -DIAMOND_ANGLE, DIAMOND_ANGLE, -DIAMOND_ANGLE, -DIAMOND_ANGLE]
const SPAWN_AREAS := [
	Rect2(380, 730, 760, 670), Rect2(1260, 650, 1000, 800),
	Rect2(1810, 1500, 780, 470), Rect2(2540, 780, 380, 620),
	Rect2(2890, 710, 500, 740), Rect2(1690, 190, 770, 420)
]

var region_label: Label
var minimap: TempleMinimap
var last_ground_center := Vector2(-10000, -10000)


func _ready() -> void:
	super._ready()
	for old_prop in view_props:
		old_prop.free()
	view_props.clear()
	for i in range(PILLAR_POINTS.size()):
		var pillar: ViewProp = ViewPropScript.new()
		pillar.name = "TemplePillar%d" % i
		pillar.position = PILLAR_POINTS[i]
		pillar.footprint_radius = 38.0 if i % 4 == 0 else 31.0
		add_child(pillar)
		pillar.configure(1 if i % 4 == 0 else 0, VIEW_PITCH)
		view_props.append(pillar)
	for i in range(WATER_AREAS.size()):
		_add_block(WATER_AREAS[i], true, WATER_ANGLES[i])
	for i in range(WALL_AREAS.size()):
		_add_block(WALL_AREAS[i], false, WALL_ANGLES[i])
	arena_navigation = NavigationScript.new()
	arena_navigation.setup(view_props, REGION_SIZE)
	player.arena_bounds = Rect2(Vector2.ZERO, REGION_SIZE)
	player.global_position = PLAYER_START
	player.reset_physics_interpolation()
	camera.limit_right = int(REGION_SIZE.x)
	camera.limit_bottom = int(REGION_SIZE.y)
	for enemy in $Enemies.get_children():
		enemy.navigation = arena_navigation
		enemy.arena_bounds = player.arena_bounds
	wisp.navigation = arena_navigation
	practice_enemy_points.clear()
	for point in ENEMY_POINTS:
		practice_enemy_points.append(point)
	region_label = Label.new()
	region_label.position = Vector2(20, 166)
	region_label.add_theme_font_size_override("font_size", 20)
	region_label.add_theme_color_override("font_color", Color("f5e7bd"))
	region_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	wisp_status.get_parent().add_child(region_label)
	role_panel.hide()
	_build_minimap()
	queue_redraw()


func _build_minimap() -> void:
	var panel := ColorRect.new()
	panel.name = "MinimapPanel"
	panel.position = Vector2(970, 12)
	panel.size = Vector2(295, 209)
	panel.color = Color(0.04, 0.13, 0.17, 0.86)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wisp_status.get_parent().add_child(panel)
	var title := Label.new()
	title.position = Vector2(13, 6)
	title.text = "청록 폐사원 · 지도"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("f5e7bd"))
	panel.add_child(title)
	minimap = MinimapScript.new()
	minimap.name = "Minimap"
	minimap.position = Vector2(13, 36)
	minimap.size = Vector2(269, 151)
	minimap.setup(self)
	panel.add_child(minimap)
	wave_hint.position = Vector2(970, 228)


func _add_block(area: Rect2, water: bool, angle: float) -> void:
	var block: TempleBlock = TempleBlockScript.new()
	block.name = "Water%d" % view_props.size() if water else "TempleWall%d" % view_props.size()
	block.setup(area, water, angle)
	add_child(block)
	view_props.append(block)


func _process(delta: float) -> void:
	super._process(delta)
	if region_label != null:
		region_label.text = "청록 폐사원  ·  %s" % current_region_name(player.global_position)
	if camera.get_screen_center_position().distance_to(last_ground_center) >= GROUND_REDRAW_DISTANCE:
		queue_redraw()


func current_region_name(point: Vector2) -> String:
	if point.x < 1250.0:
		return "수변 마당"
	if point.x < 2500.0:
		return "사원 뜰"
	if point.x < 2860.0:
		return "회랑"
	return "성소"


func can_spawn_at(point: Vector2) -> bool:
	if point.x < 70.0 or point.y < 70.0 or point.x > REGION_SIZE.x - 70.0 or point.y > REGION_SIZE.y - 70.0:
		return false
	if point.distance_to(player.global_position) < 280.0 or not arena_navigation.is_open(point, 32.0):
		return false
	var listed := false
	for area in SPAWN_AREAS:
		if area.has_point(point):
			listed = true
			break
	return listed and (arena_navigation.has_clear_path(point, player.global_position) or not arena_navigation.find_path(point, player.global_position).is_empty())


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, REGION_SIZE), Color("75a7a0"))
	var view_center := camera.get_screen_center_position()
	last_ground_center = view_center
	var half_view := get_viewport_rect().size / camera.zoom * 0.5 + Vector2(200, 200)
	var visible := Rect2(view_center - half_view, half_view * 2.0)
	var first := _ground_coordinates(visible.position)
	var second := _ground_coordinates(Vector2(visible.end.x, visible.position.y))
	var third := _ground_coordinates(visible.end)
	var fourth := _ground_coordinates(Vector2(visible.position.x, visible.end.y))
	var min_u := floori(minf(first.x, minf(second.x, minf(third.x, fourth.x)))) - 2
	var max_u := ceili(maxf(first.x, maxf(second.x, maxf(third.x, fourth.x)))) + 2
	var min_v := floori(minf(first.y, minf(second.y, minf(third.y, fourth.y)))) - 2
	var max_v := ceili(maxf(first.y, maxf(second.y, maxf(third.y, fourth.y)))) + 2
	for u in range(min_u, max_u + 1):
		for v in range(min_v, max_v + 1):
			var center := diamond_grid_point(u, v)
			if center.x < -80.0 or center.x > REGION_SIZE.x + 80.0 or center.y < -40.0 or center.y > REGION_SIZE.y + 40.0 or not visible.grow(80.0).has_point(center):
				continue
			var color := Color("a9c8b7") if center.x < 1250.0 else Color("d4d1ad") if center.x < 2500.0 else Color("bed1bd")
			if (u + v) % 4 == 0:
				color = color.lightened(0.04)
			var points := PackedVector2Array([
				center + Vector2(0, -40), center + Vector2(80, 0),
				center + Vector2(0, 40), center + Vector2(-80, 0)
			])
			draw_colored_polygon(points, color)
			draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color(0.27, 0.44, 0.42, 0.14), 1.3)
	_draw_plaza(Vector2(790, 1180), 580.0, 285.0, Color("e0d7b2"))
	_draw_plaza(Vector2(1830, 1080), 820.0, 385.0, Color("e7d8ae"))
	_draw_plaza(Vector2(3130, 1080), 400.0, 280.0, Color("e0d1a7"))
	for i in range(WATER_AREAS.size()):
		var points := rotated_rect_points(WATER_AREAS[i], WATER_ANGLES[i])
		draw_colored_polygon(points, Color("367f85"))
		draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color("d5dfc3"), 4.0)
	draw_line(Vector2(2320, 1080), Vector2(2930, 1080), Color("ddcfaa"), 204.0)
	draw_rect(Rect2(Vector2(16, 16), REGION_SIZE - Vector2(32, 32)), Color("326f70"), false, 14.0)


func _ground_coordinates(point: Vector2) -> Vector2:
	var x := (point.x - 1200.0) / 80.0
	var y := (point.y - 700.0) / 40.0
	return Vector2((x + y) * 0.5, (y - x) * 0.5)


func _draw_plaza(center: Vector2, half_width: float, half_height: float, color: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0, -half_height), center + Vector2(half_width, 0),
		center + Vector2(0, half_height), center + Vector2(-half_width, 0)
	])
	draw_colored_polygon(points, color)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color("759c8d"), 5.0)


func rotated_rect_points(area: Rect2, angle: float) -> PackedVector2Array:
	var half := area.size * 0.5
	var center := area.get_center()
	return PackedVector2Array([
		center + Vector2(-half.x, -half.y).rotated(angle),
		center + Vector2(half.x, -half.y).rotated(angle),
		center + Vector2(half.x, half.y).rotated(angle),
		center + Vector2(-half.x, half.y).rotated(angle)
	])
