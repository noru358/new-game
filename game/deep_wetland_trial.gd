extends "res://game/hybrid_height.gd"
## Standalone construction sample: no profile, XP, settlement or new unlocks.
const Wetland = preload("res://game/deep_wetland_terrain.gd")
const PLACE_ENCOUNTERS := [
	[Vector2(1300, 2180), TrainingEnemy.Role.FRAGMENT, 22.0],
	[Vector2(1650, 2150), TrainingEnemy.Role.BEAST, 45.0],
	[Vector2(2200, 1540), TrainingEnemy.Role.ZONE, 32.0],
	[Vector2(2800, 1510), TrainingEnemy.Role.FRAGMENT, 22.0],
	[Vector2(1100, 1150), TrainingEnemy.Role.LAMP, 30.0],
	[Vector2(1650, 990), TrainingEnemy.Role.FRAGMENT, 22.0],
	[Vector2(3220, 1000), TrainingEnemy.Role.SUPPORT, 36.0],
	[Vector2(3260, 760), TrainingEnemy.Role.BEAST, 45.0],
]
var dormant_place_enemies: Array[TrainingEnemy] = []

func _init() -> void:
	terrain = Wetland.new()
	start_point = Wetland.ENTRY
	enemy_points = [Vector2(1300, 2180), Vector2(2140, 1550), Vector2(2840, 1510), Vector2(3230, 1030)]
	landmark_points = {"입구": Wetland.ENTRY, "참배길": Wetland.PROCESSION, "얼굴 유적": Wetland.FACE_BANK, "사원뜰": Wetland.TEMPLE_COURT}
	combat_camera_size = 9.0
	overview_camera_size = 48.0
	camera_offset = Vector3(14, 13.864, 14)
	ground_color = Color("4c6858")
	scene_title = "Deep Temple Wetland — representative route"
	show_practice_controls = false
	moving_slash_practice = true
	growth_save_prefix = "user://deep_wetland_trial_unused_unlocks"

func _ready() -> void:
	super._ready()
	growth.growth_ended = true
	growth.hud.hide()
	growth.xp_bar.hide()
	growth.last_choice_label.hide()
	player.set_combo_rank(2)
	build_summary_label.hide()
	minimap.hide()
	_update_hud()

func _build_ui() -> void:
	super._build_ui()
	for canvas in get_children():
		if not canvas is CanvasLayer: continue
		var hint := canvas.get_node_or_null("ControlsHint")
		if hint != null:
			hint.text = "WASD 이동 · J 공격 · Space 베기 · Shift 대시 · Tab 지도 · Esc 정지 · R 재시작 · G 야영지"
			hint.position = Vector2(20, 680)

func _on_enemy_defeated(_enemy: TrainingEnemy) -> void:
	kills += 1

func _update_hud() -> void:
	if hud == null or not is_instance_valid(player): return
	hud.text = "깊은 사원 습지 · 대표 구간\n%s · HP %d · 저장/보상 없음" % [terrain.surface_name(player.position), ceili(player.health)]
	if player_health_bar != null:
		player_health_bar.max_value = player.max_health
		player_health_bar.value = player.health

func _process(delta: float) -> void:
	super._process(delta)
	if overview:
		camera.position = terrain.world_point(terrain.map_size * 0.5) + camera_offset.normalized() * 90.0
		camera.look_at(terrain.world_point(terrain.map_size * 0.5), Vector3.UP)

func _top(st: SurfaceTool, area: Rect2, elevation: Callable, color: Color) -> void:
	# This place sample has no prototype checkerboard. Preserve physical boundaries.
	var tint := Color("294e50") if color == Color("39858b") else color
	var points: Array = []
	for p in [area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)]:
		points.append(Vector3(p.x, elevation.call(p), p.y))
	_quad(st, points, tint)

func _build_terrain(render_bounds := Rect2()) -> void:
	super._build_terrain(render_bounds)
	preload("res://game/wetland_environment.gd").build(self)

func _stone(p: Vector2, size: Vector3, color: Color, lift: float = 0.0) -> MeshInstance3D:
	return preload("res://game/wetland_environment.gd").stone(self,p,size,color,lift)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
		_set_paused(false)
		get_tree().change_scene_to_file("res://game/travel_camp.tscn")
		return
	super._input(event)

func spawn_enemies() -> void:
	if not terrain is Wetland:
		super.spawn_enemies()
		return
	dormant_place_enemies.clear()
	for actor in actors.keys():
		if actor == player: continue
		if is_instance_valid(actor): actor.queue_free()
		actors[actor].queue_free()
		actors.erase(actor)
		actor_motion.erase(actor)
	for spec in _place_encounters():
		var enemy := _spawn_enemy_at(spec[0], spec[1], spec[2])
		enemy.set_physics_process(false)
		dormant_place_enemies.append(enemy)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if paused or get_tree().paused or not terrain is Wetland: return
	for enemy in dormant_place_enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			dormant_place_enemies.erase(enemy)
			continue
		if enemy.position.distance_to(player.position) > 650: continue
		var path := navigation.find_path(enemy.position, player.position)
		var distance := 0.0
		for i in range(1, path.size()): distance += path[i - 1].distance_to(path[i])
		if path.is_empty() or distance > 900: continue
		# Once engaged, retreat never freezes a warning or resets the enemy.
		enemy.set_physics_process(true)
		dormant_place_enemies.erase(enemy)

func _dry_routes() -> Array:
	return [Wetland.WAYPOINTS, Wetland.SIDE_ROUTE]

func _place_encounters() -> Array:
	return PLACE_ENCOUNTERS

func _far_bank_groves() -> Array:
	return [Vector2(330, 450), Vector2(420, 1110), Vector2(390, 1900), Vector2(1140, 300), Vector2(1770, 350), Vector2(3650, 400), Vector2(3670, 1000)]
