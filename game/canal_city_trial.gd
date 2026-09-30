extends "res://game/hybrid_height.gd"

const CanalTerrain = preload("res://game/canal_city_terrain.gd")
const COMBAT_POINTS := [Vector2(6050, 3440), Vector2(5200, 1630), Vector2(4080, 1550), Vector2(4770, 3180), Vector2(2600, 2960)]

var enemies_enabled := false
var mode_button: Button


func minimap_heading() -> String:
	return "수로도시 · 동선"


func minimap_legend() -> String:
	return "동문 · 시장 · 석교 · 창고 · 수변"


func _init() -> void:
	terrain = CanalTerrain.new()
	start_point = Vector2(6750, 3790)
	enemy_points = []
	landmark_points = {"동문": start_point, "시장 골목": Vector2(4510, 1510), "열린 수변": Vector2(4570, 3140), "창고 하역장": Vector2(2200, 2950), "수문 마당": Vector2(1840, 1500)}
	scene_title = "Loop Conquest — 수로도시 장소 시험"
	scene_hud_title = "수로도시 · v2 배치 시험"
	ground_color = Color("a5a58d")
	combat_camera_size = 10.8
	overview_camera_size = 46.0
	growth_persists = false


func _build_terrain(render_bounds := Rect2()) -> void:
	super._build_terrain(Rect2(-300, -700, 7800, 5900))
	_build_city_details()


func _build_city_details() -> void:
	for record in terrain.wall_areas:
		var area: Rect2 = record.area
		match record.get("kind", ""):
			"shop": _shop(area, float(record.height), record.color)
			"warehouse": _warehouse(area, float(record.height), record.color)
			"background": _background_building(area, float(record.height))
			"sluice":
				_pitched_roof(area, float(record.height), Color("405754"), 58)
				_box(Rect2(area.position.x + 50, area.position.y - 12, 105, 18), 145, Color("324e53"))
			"gate":
				_pitched_roof(area, float(record.height), Color("435850"), 65)
				_box(Rect2(area.position.x + 50, area.position.y - 12, 110, 20), 145, Color("425952"))
	for bridge in CanalTerrain.BRIDGES:
		for i in 8:
			_box(Rect2(bridge.position.x + 26, bridge.position.y + i * 62, bridge.size.x - 52, 7), 3, Color("e1bf87"), 3)
	_box(Rect2(6545, 3500, 300, 560), 25, Color("6c4b3e"), 225)
	_pitched_roof(Rect2(6545, 3500, 300, 560), 250, Color("344d4d"), 83)
	_box(Rect2(6555, 3555, 275, 34), 16, Color("9d7150"), 272)
	for point in [Vector2(6500, 3565), Vector2(6500, 3980)]: _lantern(point)
	for i in 5:
		_box(Rect2(3780 + i * 342, 2770 + i % 2 * 5, 270, 23), 6, Color("e2cfaa"), 2)
		_box(Rect2(3780 + i * 342, 2810 + i % 2 * 5, 270, 21), 6, Color("ad9d82"), 2)
	for i in 6:
		_box(Rect2(CanalTerrain.DOCK.position.x + 12, CanalTerrain.DOCK.position.y + i * 48, CanalTerrain.DOCK.size.x - 24, 7), 6, Color("cba878"), 5)
	for point in [Vector2(4170, 2890), Vector2(4910, 2880), Vector2(3690, 2840), Vector2(5360, 2890)]:
		_box(Rect2(point.x, point.y, 45, 45), 65, Color("777b6a"))
	for point in [Vector2(3490, 1530), Vector2(5500, 1690), Vector2(3840, 3200), Vector2(5600, 3180), Vector2(1580, 2060)]:
		_lantern(point)
	for i in 4:
		var crate_point := Vector2(1650 + i * 490, 3330 + i % 2 * 35)
		_box(Rect2(crate_point, Vector2(95, 84)), 80, Color("80654a"))
		_box(Rect2(crate_point + Vector2(113, 35), Vector2(68, 65)), 58, Color("ab8558"))
	# Boats are visual context, and are deliberately outside the walkable deck.
	for point in [Vector2(1150, 2420), Vector2(6170, 2450)]:
		_box(Rect2(point - Vector2(185, 55), Vector2(370, 110)), 32, Color("514b42"), 3)
		_box(Rect2(point - Vector2(143, 37), Vector2(286, 74)), 8, Color("b28e5f"), 35)


func _shop(area: Rect2, height: float, color: Color) -> void:
	_pitched_roof(area, height, Color("385453") if int(area.position.x / 100) % 2 == 0 else Color("4d5651"), 62)
	var faces_south := area.position.y < 1600
	var front_y: float = area.end.y if faces_south else area.position.y
	var door_y: float = front_y + 4 if faces_south else front_y - 12
	_box(Rect2(area.get_center().x - 49, door_y, 98, 12), 135, Color("6b4634"), 0)
	for x in [area.position.x + 17, area.end.x - 34]:
		_box(Rect2(x, door_y, 17, 18), height - 15, Color("6b4634"))
	for side in [-1, 1]:
		_box(Rect2(area.get_center().x + side * 132 - 34, door_y, 68, 12), 66, Color("a28960"), 95)
		_box(Rect2(area.get_center().x + side * 132 - 3, door_y + (8 if faces_south else -8), 6, 10), 67, Color("5b4835"), 95)
	var awning_y: float = front_y + 15 if faces_south else front_y - 105
	for stripe in 5:
		_box(Rect2(area.position.x + 24 + stripe * (area.size.x - 48) / 5.0, awning_y, (area.size.x - 48) / 5.0 - 3, 88), 9, Color("d7c39b") if stripe % 2 == 0 else Color("9d614b"), 163)
	for edge_x in [area.position.x + 35, area.end.x - 47]:
		_box(Rect2(edge_x, awning_y + 53, 12, 12), 155, Color("6a5741"))
	_box(Rect2(area.position.x + 40, awning_y + (105 if faces_south else -8), 88, 55), 69, Color("a88053"))


func _warehouse(area: Rect2, height: float, color: Color) -> void:
	_pitched_roof(area, height, Color("425758"), 67)
	_box(Rect2(area.get_center().x - 112, area.position.y - 12, 224, 17), 182, Color("65452f"))
	_box(Rect2(area.position.x + 38, area.position.y - 12, area.size.x - 76, 14), 20, Color("704c35"), height - 45)
	for edge_x in [area.position.x + 26, area.end.x - 43]:
		_box(Rect2(edge_x, area.position.y - 15, 17, 22), height - 20, color.darkened(0.3))
	for i in 3:
		_box(Rect2(area.position.x + 70 + i * (area.size.x - 140) / 3.0, area.position.y - 67, 70, 53), 42, Color("94734e"))


func _background_building(area: Rect2, height: float) -> void:
	_pitched_roof(area, height, Color("3e5555"), 61)
	for i in 3:
		_box(Rect2(area.position.x + 65 + i * 125, area.end.y + 1, 45, 9), 55, Color("d5c7a8"), 95)


func _pitched_roof(area: Rect2, wall_height: float, tile_color: Color, rise: float) -> void:
	var eave := area.grow(24)
	var ridge_y := eave.get_center().y
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in 2:
		var edge_y: float = eave.position.y if side == 0 else eave.end.y
		for row in 6:
			var a := float(row) / 6.0
			var b := float(row + 1) / 6.0
			var y0 := lerpf(edge_y, ridge_y, a)
			var y1 := lerpf(edge_y, ridge_y, b)
			var h0 := wall_height + 15.0 + rise * a
			var h1 := wall_height + 15.0 + rise * b
			for tile in ceili(eave.size.x / 64.0):
				var x0 := eave.position.x + tile * 64.0
				var x1 := minf(x0 + 64.0, eave.end.x)
				_quad(st, [Vector3(x0, h0, y0), Vector3(x1, h0, y0), Vector3(x1, h1, y1), Vector3(x0, h1, y1)], tile_color.lightened(0.06) if (tile + row) % 3 == 0 else tile_color.darkened(0.07) if row % 2 == 0 else tile_color)
	st.generate_normals()
	var roof := MeshInstance3D.new()
	roof.mesh = st.commit()
	var material := _material(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	roof.material_override = material
	add_child(roof)
	_box(Rect2(eave.position.x, ridge_y - 7, eave.size.x, 14), 13, tile_color.darkened(0.23), wall_height + rise + 15)
	for edge_y in [eave.position.y, eave.end.y - 15]:
		_box(Rect2(eave.position.x, edge_y, eave.size.x, 15), 17, Color("6b4936"), wall_height + 5)


func _lantern(point: Vector2) -> void:
	_box(Rect2(point - Vector2(7, 7), Vector2(14, 14)), 155, Color("4d5750"))
	var bulb := _sphere(0.13, Color("f4d995"))
	bulb.position = terrain.world_point(point, 165)
	add_child(bulb)


func _box(area: Rect2, height: float, color: Color, lift: float = 0.0) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(area.size.x, height, area.size.y) * HybridTerrain.SCALE
	node.mesh = mesh
	node.material_override = _material(color)
	node.position = Vector3(area.get_center().x, lift + height * 0.5, area.get_center().y) * HybridTerrain.SCALE
	add_child(node)


func spawn_enemies() -> void:
	enemy_points = COMBAT_POINTS.duplicate() if enemies_enabled else []
	super.spawn_enemies()
	if mode_button != null: mode_button.text = "V · 일반 적 5명 켜짐" if enemies_enabled else "V · 경관만 보기"


func _build_ui() -> void:
	super._build_ui()
	var canvas: CanvasLayer = get_children().filter(func(child): return child is CanvasLayer).back()
	mode_button = Button.new()
	mode_button.position = Vector2(1005, 633)
	mode_button.size = Vector2(240, 42)
	mode_button.text = "V · 경관만 보기"
	mode_button.pressed.connect(_toggle_enemies)
	canvas.add_child(mode_button)
	var note := Label.new()
	note.position = Vector2(716, 683)
	note.text = "G 야영지 귀환 · 이 구간은 진행과 보상을 저장하지 않음"
	note.add_theme_font_size_override("font_size", 15)
	canvas.add_child(note)


func _toggle_enemies() -> void:
	enemies_enabled = not enemies_enabled
	spawn_enemies()


func _input(event: InputEvent) -> void:
	super._input(event)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_V and not paused and not growth.choosing: _toggle_enemies()
		if event.keycode == KEY_G and not growth.choosing:
			_set_paused(false)
			get_tree().change_scene_to_file("res://game/travel_camp.tscn")
