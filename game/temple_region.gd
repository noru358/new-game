extends "res://game/view_prototype.gd"

const TempleBlockScript = preload("res://game/temple_block.gd")
const REGION_SIZE := Vector2(3840, 2160)
const PLAYER_START := Vector2(760, 1190)
const ENEMY_POINTS := [
	Vector2(1180, 1080), Vector2(1730, 1230), Vector2(2230, 940),
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
	Rect2(280, 450, 650, 120), Rect2(1120, 450, 530, 120),
	Rect2(360, 1710, 780, 120), Rect2(1330, 1710, 550, 120),
	Rect2(2110, 330, 310, 160)
]
const WALL_AREAS := [
	Rect2(2500, 880, 230, 50), Rect2(2500, 1260, 230, 50),
	Rect2(2840, 610, 650, 52), Rect2(2840, 1550, 650, 52),
	Rect2(3460, 610, 52, 992)
]
const SPAWN_AREAS := [
	Rect2(380, 730, 760, 670), Rect2(1260, 650, 1000, 800),
	Rect2(1810, 1500, 780, 470), Rect2(2540, 780, 380, 620),
	Rect2(2890, 710, 500, 740), Rect2(1690, 190, 770, 420)
]

var region_label: Label


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
	for area in WATER_AREAS:
		_add_block(area, true)
	for area in WALL_AREAS:
		_add_block(area, false)
	arena_navigation = NavigationScript.new()
	arena_navigation.setup(view_props, REGION_SIZE)
	player.arena_bounds = Rect2(Vector2.ZERO, REGION_SIZE)
	player.global_position = PLAYER_START
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
	queue_redraw()


func _add_block(area: Rect2, water: bool) -> void:
	var block: TempleBlock = TempleBlockScript.new()
	block.name = "Water%d" % view_props.size() if water else "TempleWall%d" % view_props.size()
	block.setup(area, water)
	add_child(block)
	view_props.append(block)


func _process(delta: float) -> void:
	super._process(delta)
	if region_label != null:
		region_label.text = "청록 폐사원  ·  %s" % current_region_name(player.global_position)


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
	for u in range(-54, 55):
		for v in range(-54, 55):
			var center := diamond_grid_point(u, v)
			if center.x < -80.0 or center.x > REGION_SIZE.x + 80.0 or center.y < -40.0 or center.y > REGION_SIZE.y + 40.0:
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
	for area in WATER_AREAS:
		draw_rect(area, Color("367f85"))
		draw_rect(area.grow(4.0), Color("d5dfc3"), false, 4.0)
		draw_line(area.position + Vector2(20, area.size.y * 0.38), area.position + Vector2(area.size.x - 20, area.size.y * 0.38), Color(0.52, 0.83, 0.83, 0.48), 3.0)
	draw_line(Vector2(2320, 1080), Vector2(2930, 1080), Color("ddcfaa"), 204.0)
	_draw_plaza(Vector2(790, 1180), 580.0, 285.0, Color("e0d7b2"))
	_draw_plaza(Vector2(1830, 1080), 820.0, 385.0, Color("e7d8ae"))
	_draw_plaza(Vector2(3130, 1080), 400.0, 280.0, Color("e0d1a7"))
	draw_rect(Rect2(Vector2(16, 16), REGION_SIZE - Vector2(32, 32)), Color("326f70"), false, 14.0)


func _draw_plaza(center: Vector2, half_width: float, half_height: float, color: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0, -half_height), center + Vector2(half_width, 0),
		center + Vector2(0, half_height), center + Vector2(-half_width, 0)
	])
	draw_colored_polygon(points, color)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color("759c8d"), 5.0)
