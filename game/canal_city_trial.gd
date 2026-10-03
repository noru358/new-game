extends "res://game/hybrid_height.gd"
## Isolated place-authoring experiment. No RunProfile, rewards or settlement.
const CityTerrain = preload("res://game/canal_city_terrain.gd")
const EnvironmentOpacity = preload("res://game/environment_opacity.gd")
const OverheadOcclusion = preload("res://game/canal_overhead_occlusion.gd")
const ENCOUNTERS := [
	Vector2(1730, 1590), Vector2(2100, 1630), Vector2(2480, 1690),
	Vector2(3460, 2830), Vector2(3990, 2850), Vector2(4330, 2770),
	Vector2(6010, 1620), Vector2(6530, 1630)
]
var combat_enabled := false
var spawn_delay := 0.0
var trial_elapsed := 0.0
var trial_canvas: CanvasLayer
var mode_button: Button
var building_visuals: Array[Dictionary] = []
var landmark_visuals: Array[Dictionary] = []
var material_cache: Dictionary = {}
var faded_material_cache: Dictionary = {}
var overhead_occlusion_enabled := false # Full opaque source assets remain visible.
var overhead_occlusion = OverheadOcclusion.new()

func _init() -> void:
	terrain = CityTerrain.new()
	start_point = CityTerrain.ENTRY
	enemy_points = []
	landmark_points = {"동문": CityTerrain.ENTRY, "시장": CityTerrain.MARKET, "창고": CityTerrain.WAREHOUSE, "수변": CityTerrain.WATERFRONT}
	combat_camera_size = 9.0
	overview_camera_size = 96.0
	camera_offset = Vector3(14, 13.864, 14)
	scene_title = "Loop Conquest — Jiangnan Canal Town v32"
	scene_hud_title = "강남 수로도시 · 조화 시험"
	ground_color = Color("b9b199")
	show_practice_controls = false
	moving_slash_practice = true
	# Super reads only this separate, non-progression prefix. No XP is awarded.
	growth_save_prefix = "user://canal_city_trial_unused_unlocks"

func _ready() -> void:
	super._ready()
	growth.growth_ended = true
	growth.hud.hide()
	growth.xp_bar.hide()
	growth.last_choice_label.hide()
	player.set_combo_rank(2)
	player.attack_hitstop_scale = 1.0
	_update_hud()

func _build_terrain(render_bounds := Rect2()) -> void:
	super._build_terrain(render_bounds)
	for record in terrain.buildings:
		_build_house(record)
	for record in terrain.props:
		_build_prop(record)
	for bridge in CityTerrain.BRIDGES:
		_build_bridge(bridge)
	# A small tiled ward gate belongs to this commercial town, not a fortress.
	# The roof is above the entry; only the existing two piers are collidable.
	var gate := Node3D.new()
	gate.name = "TiledWardGate"
	add_child(gate)
	_pitched_roof(gate, Rect2(6420, 3760, 215, 570), 238, Color("385453"), 62, Color("e2dbc6"))
	_box(gate, Vector3(6528, 222, 4045), Vector3(170, 25, 540), Color("75573e"))
	landmark_visuals.append({"area": Rect2(6420, 3760, 215, 570), "height": 320.0, "root": gate, "background": false})
	# Quay coping: same water boundaries, low enough to leave telegraphs clear.
	for water in terrain.water_areas:
		for y in [water.position.y, water.end.y]:
			_box(self, Vector3(water.get_center().x, 3, y), Vector3(water.size.x, 6, 14), Color("d0ccaf"))
	# Waterfront steps are visual coping inside blocked water, not fake stairs.
	for i in 4:
		_box(self, Vector3(4610, -2 + i * 3, 2375 + i * 12), Vector3(320, 8, 12), Color("aaa98f"))
	for point in [Vector2(4680, 2280), Vector2(6740, 2200)]:
		_build_boat(point)
	# Fixed landing stage stays on dry ground, adjacent to blocked water.
	_box(self, Vector3(4530, 3, 2500), Vector3(400, 6, 145), Color("928060"))
	for x in range(4350, 4740, 45):
		_box(self, Vector3(x, 7, 2500), Vector3(3, 2, 145), Color("655e4d"))
	# Mooring posts, coiled rope and handcart are loading context, not random clutter.
	for point in [Vector2(4360, 2470), Vector2(4700, 2470), Vector2(4120, 2580)]:
		_box(self, Vector3(point.x, 20, point.y), Vector3(18, 40, 18), Color("706449"))
		_box(self, Vector3(point.x + 28, 7, point.y), Vector3(36, 14, 28), Color("c6a56d"))
	_build_cart(CityTerrain.CART)
	for point in CityTerrain.LOADING_BARRELS:
		_cylinder(self, Vector3(point.x, 26, point.y), 25, 28, 52, Color("8d7852"))
		_cylinder(self, Vector3(point.x, 45, point.y), 28, 28, 6, Color("56665b"))
	# Loading yard: leaning planks and tied canvas bales stay with the warehouse.
	for i in 4:
		var plank := _box(self, Vector3(4780 + i * 17, 45, 2780), Vector3(12, 92, 15), Color("b09360"))
		plank.rotation.x = 0.22
	_box(self, Vector3(4420, 15, 2950), Vector3(130, 30, 68), Color("bfb28c"))

	# Water-control pavilion: a recognisable destination beyond the shop lane.
	# It remains scenery; no gate puzzle, new boss or progression trigger.
	var pavilion := Node3D.new()
	pavilion.name = "SluicePavilion"
	add_child(pavilion)
	_box(pavilion, Vector3(6690, 228, 995), Vector3(655, 28, 170), Color("75573e"))
	_pitched_roof(pavilion, Rect2(6360, 880, 660, 245), 241, Color("385453"), 65, Color("bfcbbb"))
	landmark_visuals.append({"area": Rect2(6360, 880, 660, 245), "height": 326.0, "root": pavilion, "background": false})

func _box(parent: Node, center: Vector3, extent: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = extent * Terrain.SCALE
	instance.mesh = mesh
	var key := color.to_html()
	if not material_cache.has(key): material_cache[key] = _material(color)
	instance.material_override = material_cache[key]
	instance.position = center * Terrain.SCALE
	parent.add_child(instance)
	return instance

func _cylinder(parent: Node, center: Vector3, top: float, bottom: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top * Terrain.SCALE
	mesh.bottom_radius = bottom * Terrain.SCALE
	mesh.height = height * Terrain.SCALE
	mesh.radial_segments = 10
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _material(color)
	node.position = center * Terrain.SCALE
	parent.add_child(node)
	return node

func _build_house(record: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "BackgroundHouse" if record.background else "ShopCluster" if record.kind == "shop" else "WarehouseCluster"
	add_child(root)
	var area: Rect2 = record.area
	var h: float = record.height
	var wall_color := Color("bac6bb") if record.background else Color("e2dbc6")
	_box(root, Vector3(area.get_center().x, h * 0.5, area.get_center().y), Vector3(area.size.x, h, area.size.y), wall_color)
	_box(root, Vector3(area.get_center().x, 13, area.get_center().y), Vector3(area.size.x + 8, 26, area.size.y + 8), Color("869487"))
	_pitched_roof(root, area, h, Color("385453") if record.kind == "shop" else Color("435755"), 62, wall_color)
	# Shop doors face the shared selling lane; warehouse doors face the
	# unloading yard. The same region palette serves different building uses.
	var side := -1.0 if record.front == "north" else 1.0
	var y: float = area.position.y if side < 0 else area.end.y
	var door_width := 74.0 if record.kind == "shop" else 180.0
	var door_height := 125.0 if record.kind == "shop" else 165.0
	_box(root, Vector3(area.get_center().x, door_height * 0.5, y + side * 4), Vector3(door_width, door_height, 10), Color("654b39"))
	for x in [area.position.x + 20, area.end.x - 20]:
		_box(root, Vector3(x, h * 0.48, y + side * 7), Vector3(14, h * 0.96, 16), Color("75573e"))
	_box(root, Vector3(area.get_center().x, h - 26, y + side * 6), Vector3(area.size.x - 28, 16, 12), Color("75573e"))
	if record.kind == "shop":
		for x in [area.get_center().x - area.size.x * 0.28, area.get_center().x + area.size.x * 0.28]:
			_box(root, Vector3(x, 103, y + side * 6), Vector3(64, 58, 10), Color("b7a279"))
			for offset in [-22, 0, 22]:
				_box(root, Vector3(x + offset, 103, y + side * 12), Vector3(5, 60, 5), Color("6d553c"))
		var awning_width: float = area.size.x * 0.76
		for stripe in 5:
			var x: float = area.get_center().x - awning_width * 0.5 + (stripe + 0.5) * awning_width / 5.0
			_box(root, Vector3(x, 151, y + side * 46), Vector3(awning_width / 5.0 - 2, 8, 91), Color("dbca9f") if stripe % 2 == 0 else Color("a86d53"))
		for x in [area.get_center().x - awning_width * 0.48, area.get_center().x + awning_width * 0.48]:
			_box(root, Vector3(x, 74, y + side * 82), Vector3(9, 148, 9), Color("6c5940"))
		# A modest hanging board and warm lantern mark a business, not a quest.
		_box(root, Vector3(area.position.x + 60, 116, y + side * 88), Vector3(28, 48, 8), Color("916142"))
		_cylinder(root, Vector3(area.end.x - 62, 110, y + side * 72), 14, 14, 28, Color("e0c486"))
	else:
		for offset in [-65, -22, 22, 65]:
			_box(root, Vector3(area.get_center().x + offset, 78, y + side * 11), Vector3(7, 154, 5), Color("8d7350"))
		_box(root, Vector3(area.get_center().x, 38, y + side * 13), Vector3(175, 11, 5), Color("b29768"))
	building_visuals.append({"area": area, "height": h + 80, "root": root, "background": record.background})

func _pitched_roof(parent: Node, area: Rect2, h: float, color: Color, rise: float, plaster: Color) -> void:
	# A's tiled roof language: low white gables, timber eaves, dark tile bands.
	# One mesh per roof avoids one draw call for every tile.
	var eave := area.grow(24)
	var ridge_y := eave.get_center().y
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in 2:
		var edge: float = eave.position.y if side == 0 else eave.end.y
		for row in 6:
			var a := float(row) / 6.0
			var b := float(row + 1) / 6.0
			for tile in ceili(eave.size.x / 64.0):
				var x0 := eave.position.x + tile * 64.0
				var x1 := minf(x0 + 64, eave.end.x)
				var tone := color.lightened(0.055) if (tile + row) % 3 == 0 else color.darkened(0.045) if row % 2 == 0 else color
				_quad(st, [Vector3(x0, h + 12 + rise * a, lerpf(edge, ridge_y, a)), Vector3(x1, h + 12 + rise * a, lerpf(edge, ridge_y, a)), Vector3(x1, h + 12 + rise * b, lerpf(edge, ridge_y, b)), Vector3(x0, h + 12 + rise * b, lerpf(edge, ridge_y, b))], tone)
	# End gables close the roof instead of floating tile planes above a box.
	for x in [area.position.x, area.end.x]:
		for point in [Vector3(x, h, area.position.y), Vector3(x, h + rise + 12, ridge_y), Vector3(x, h, area.end.y)]:
			st.set_color(plaster)
			st.add_vertex(point * Terrain.SCALE)
	st.generate_normals()
	var roof := MeshInstance3D.new()
	roof.name = "TiledRoof"
	roof.mesh = st.commit()
	var material := _material(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	roof.material_override = material
	parent.add_child(roof)
	_box(parent, Vector3(eave.get_center().x, h + rise + 17, ridge_y), Vector3(eave.size.x + 12, 12, 15), color.darkened(0.20))
	for y in [eave.position.y, eave.end.y]:
		_box(parent, Vector3(eave.get_center().x, h + 7, y), Vector3(eave.size.x, 14, 14), Color("72553c"))

func _build_prop(record: Dictionary) -> void:
	var area: Rect2 = record.area
	var center := area.get_center()
	match record.kind:
		"stall":
			var trade: String = record.trade
			_box(self, Vector3(center.x, 24, center.y), Vector3(area.size.x, 48, area.size.y), Color("9f8254"))
			_box(self, Vector3(center.x, 48, center.y + 12), Vector3(area.size.x + 5, 5, area.size.y + 4), Color("c19d67") if trade == "produce" else Color("a67356"))
			# A small market stall is a repeatable functional group: supports,
			# canvas, goods, under-counter storage, then a clear selling side.
			for x in [area.position.x + 6, area.end.x - 6]:
				_box(self, Vector3(x, 63, area.position.y + 4), Vector3(7, 126, 7), Color("6a644b"))
			var canopy := _box(self, Vector3(center.x, 137, center.y - 7), Vector3(area.size.x + 22, 6, area.size.y + 18), Color("c8ac76") if trade == "produce" else Color("9cab98") if trade == "textile" else Color("b98468"))
			canopy.rotation.x = -0.09
			for j in 3:
				var point := Vector2(area.position.x + 23 + j * 41, center.y + 22)
				if trade == "produce":
					_cylinder(self, Vector3(point.x, 57, point.y), 16, 19, 15, Color("b99662"))
					for k in 4:
						var fruit := _sphere(0.072, Color("deaa45") if j % 2 == 0 else Color("75984a"))
						add_child(fruit)
						fruit.position = Vector3(point.x + (k % 2) * 10 - 5, 70 + (k / 2) * 4, point.y + (k / 2) * 9 - 5) * Terrain.SCALE
				elif trade == "pottery":
					_cylinder(self, Vector3(point.x, 65 + j * 3, point.y), 10 + j * 3, 15 + j * 2, 29 + j * 6, Color("bd8964") if j % 2 == 0 else Color("b8c4ad"))
				else:
					_box(self, Vector3(point.x, 58 + j * 3, point.y), Vector3(34, 15 + j * 6, 44), Color("9ba9a0") if j % 2 == 0 else Color("c4ad82"))
			_box(self, Vector3(area.position.x + 22, 13, center.y + 1), Vector3(33, 26, 40), Color("756547"))
		"stock":
			if record.trade == "pottery":
				for x in [center.x - 19, center.x + 19]:
					_cylinder(self, Vector3(x, 25, center.y), 11, 18, 50, Color("b29270"))
			else:
				_box(self, Vector3(center.x, 22, center.y), Vector3(area.size.x, 44, area.size.y), Color("b7ad8a"))
				for x in [area.position.x + 13, area.end.x - 13]:
					_box(self, Vector3(x, 24, center.y), Vector3(5, 49, area.size.y + 3), Color("776d50"))
		"cargo":
			_box(self, Vector3(center.x, 26, center.y), Vector3(area.size.x, 52, area.size.y), Color("aa8c60"))
			for x in [area.position.x + 12, area.end.x - 12]:
				_box(self, Vector3(x, 29, center.y), Vector3(8, 58, area.size.y + 4), Color("695e46"))
			_box(self, Vector3(center.x, 66, center.y), Vector3(area.size.x * 0.6, 28, area.size.y * 0.7), Color("cab481"))
		_:
			_box(self, Vector3(center.x, 110, center.y), Vector3(area.size.x, 220, area.size.y), Color("8e9a88"))
			_box(self, Vector3(center.x, 227, center.y), Vector3(area.size.x + 20, 22, area.size.y + 20), Color("445c51"))

func _build_bridge(area: Rect2) -> void:
	var horizontal := area.size.x > area.size.y
	# Low decorative coping occupies only the water-side edge, no invisible barrier.
	for offset in [-1.0, 1.0]:
		var center := area.get_center()
		center[1 if horizontal else 0] += offset * (area.size[1 if horizontal else 0] * 0.5 - 8)
		_box(self, Vector3(center.x, 12, center.y), Vector3(area.size.x if horizontal else 12, 24, 12 if horizontal else area.size.y), Color("ced0b4"))
	# Short stone spans have repeated transverse paving joints, unlike the
	# timber landing. Keep every raised detail on the water-side edges.
	var length: float = area.size.x if horizontal else area.size.y
	for step in range(1, ceili(length / 65.0)):
		var point := area.position + (Vector2(step * 65, area.size.y * 0.5) if horizontal else Vector2(area.size.x * 0.5, step * 65))
		_box(self, Vector3(point.x, 3, point.y), Vector3(4 if horizontal else area.size.x - 30, 2, area.size.y - 30 if horizontal else 4), Color("929883"))

func _build_boat(point: Vector2) -> void:
	# Shallow narrow cargo boat: pointed hull, low cover and tied goods.
	var outline := [Vector2(-125, -40), Vector2(90, -40), Vector2(135, 0), Vector2(90, 40), Vector2(-125, 40), Vector2(-145, 0)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outline.size():
		var a: Vector2 = point + outline[i]
		var b: Vector2 = point + outline[(i + 1) % outline.size()]
		_quad(st, [Vector3(a.x, 1, a.y), Vector3(b.x, 1, b.y), Vector3(b.x, 31, b.y), Vector3(a.x, 31, a.y)], Color("5d5948"))
	st.generate_normals()
	var hull := MeshInstance3D.new()
	hull.mesh = st.commit()
	hull.material_override = _material(Color("5d5948"))
	add_child(hull)
	_box(self, Vector3(point.x, 35, point.y), Vector3(160, 12, 52), Color("99865b"))
	for x in [point.x - 102, point.x + 102]:
		_box(self, Vector3(x, 32, point.y), Vector3(17, 32, 66), Color("465d55"))
	_box(self, Vector3(point.x + 27, 59, point.y), Vector3(64, 39, 51), Color("aa9167"))
	_box(self, Vector3(point.x - 61, 83, point.y), Vector3(83, 8, 81), Color("a6ac8d"))
	for z in [-32, 32]:
		_box(self, Vector3(point.x - 61, 58, point.y + z), Vector3(5, 48, 5), Color("716348"))

func _build_cart(point: Vector2) -> void:
	_box(self, Vector3(point.x, 32, point.y), Vector3(130, 15, 75), Color("796a4d"))
	for x in [-42, 42]:
		for z in [-42, 42]:
			var wheel := _sphere(0.16, Color("505b49"))
			add_child(wheel)
			wheel.position = Vector3(point.x + x, 16, point.y + z) * Terrain.SCALE
	_box(self, Vector3(point.x + 87, 38, point.y), Vector3(75, 8, 9), Color("796a4d"))

func spawn_enemies() -> void:
	for actor in actors.keys():
		if actor != player:
			if is_instance_valid(actor): actor.queue_free()
			actors[actor].queue_free()
			actors.erase(actor)
			actor_motion.erase(actor)
	for group in ["enemy_bolts", "enemy_zones", "wisp_projectiles"]:
		for node in get_tree().get_nodes_in_group(group): node.queue_free()
	spawn_delay = 1.0 if combat_enabled else 0.0

func set_combat_enabled(enabled: bool) -> void:
	combat_enabled = enabled
	spawn_enemies()
	_update_hud()

func _physics_process(delta: float) -> void:
	if paused: return
	trial_elapsed += delta
	if spawn_delay > 0.0:
		spawn_delay -= delta
		if spawn_delay <= 0.0 and combat_enabled:
			for i in ENCOUNTERS.size():
				var point: Vector2 = ENCOUNTERS[i]
				if point.distance_to(player.position) < 210.0: continue
				if navigation.is_open(point, ACTOR_CLEARANCE):
					_spawn_enemy_at(point, ENEMY_ROLES[i], ENEMY_HEALTH[i])
	for actor in actors:
		if is_instance_valid(actor) and actor is TrainingEnemy:
			actor.set_physics_process(actor.position.distance_to(player.position) < 1050.0 and player.health > 0.0)
	super._physics_process(delta)

func _on_enemy_defeated(_enemy: TrainingEnemy) -> void:
	kills += 1 # No XP, currency, unlocks or profile writes in this experiment.

func _process(delta: float) -> void:
	super._process(delta)
	if overview:
		camera.position = terrain.world_point(display_bounds().get_center(), 80) + camera_offset.normalized() * 120.0
	if not is_instance_valid(player): return
	# Keep the original roofs, beams and houses; actor position changes nothing.
	if not overhead_occlusion.entries.is_empty(): overhead_occlusion.restore()

func _set_architecture_fade(root: Node3D, _obscures: bool) -> void:
	EnvironmentOpacity.restore(root)

func _build_ui() -> void:
	trial_canvas = CanvasLayer.new()
	trial_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(trial_canvas)
	var panel := ColorRect.new()
	panel.position = Vector2(16, 16)
	panel.size = Vector2(500, 83)
	panel.color = Color(0.055, 0.12, 0.12, 0.91)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trial_canvas.add_child(panel)
	hud = Label.new()
	hud.position = Vector2(29, 26)
	hud.add_theme_font_size_override("font_size", 19)
	trial_canvas.add_child(hud)
	var row := HBoxContainer.new()
	row.position = Vector2(600, 20)
	row.add_theme_constant_override("separation", 8)
	trial_canvas.add_child(row)
	mode_button = _trial_button(row, "F2 · 전투 비교", func(): set_combat_enabled(not combat_enabled))
	_trial_button(row, "동문", func(): teleport(CityTerrain.ENTRY))
	_trial_button(row, "시장", func(): teleport(CityTerrain.MARKET))
	_trial_button(row, "수변", func(): teleport(CityTerrain.WATERFRONT))
	_trial_button(row, "야영지", _return_to_camp)
	var help := Label.new()
	help.position = Vector2(22, 654)
	help.text = "WASD 이동 · Shift 대시 · J/클릭 공격 · Space 이동 베기\nTab 전체 배치 · F2 풍경/제한 전투 · N 적 재배치 · R 동문 재시작 · Esc 정지 · G 야영지"
	help.add_theme_font_size_override("font_size", 17)
	help.add_theme_color_override("font_shadow_color", Color.BLACK)
	help.add_theme_constant_override("shadow_offset_x", 1)
	help.add_theme_constant_override("shadow_offset_y", 1)
	trial_canvas.add_child(help)
	pause_label = Label.new()
	pause_label.position = Vector2(480, 320)
	pause_label.text = "일시정지 · Esc로 계속"
	pause_label.add_theme_font_size_override("font_size", 26)
	pause_label.hide()
	trial_canvas.add_child(pause_label)

func _trial_button(row: HBoxContainer, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(82, 38)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	row.add_child(button)
	return button

func _update_hud() -> void:
	if hud == null or not is_instance_valid(player): return
	var mode := "제한 전투 · 적 최대 8" if combat_enabled else "풍경 · 적 없음"
	if spawn_delay > 0.0: mode = "1초 후 고정 지점에 적 배치"
	hud.text = "강남 수로도시 v32 · %s\nHP %d · 대시 %d/%d · 고정 시험 빌드 / 저장·보상 없음" % [mode, ceili(player.health), player.dash_charges, player.dash_max_charges]
	if player.health <= 0.0: hud.text += "\n쓰러졌습니다 · R로 동문에서 다시 시작"
	if mode_button != null: mode_button.text = "F2 · 풍경 보기" if combat_enabled else "F2 · 전투 비교"

func _return_to_camp() -> void:
	_set_paused(false)
	get_tree().change_scene_to_file("res://game/travel_camp.tscn")

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_F2:
			if not paused: set_combat_enabled(not combat_enabled)
		KEY_N:
			if not paused: spawn_enemies()
		KEY_R:
			_set_paused(false)
			player.restore_for_boss_retry()
			teleport(CityTerrain.ENTRY)
			spawn_enemies()
		KEY_G: _return_to_camp()
		_: super._input(event)
