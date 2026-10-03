extends "res://game/hybrid_height.gd"
## Standalone development slice: no campaign, profile, reward or boss mounting.
const PalaceTerrain = preload("res://game/palace_temple_terrain.gd")
const PalaceKit = preload("res://game/palace_temple_kit.gd")
var palace_root: Node3D

func _init() -> void:
	terrain = PalaceTerrain.new()
	start_point = PalaceTerrain.ENTRY
	combat_camera_size = 9.0
	camera_offset = Vector3(14, 13.864, 14)
	overview_camera_size = 38.0
	ground_color = Color("afbe85")
	show_practice_controls = false
	moving_slash_practice = true
	scene_title = "Palace temple — independent development preview"
	growth_save_prefix = "user://palace_preview_unused_unlocks"
	landmark_points = {"행렬문": PalaceTerrain.GATE, "밝은 중정": PalaceTerrain.COURT_CENTER, "회랑": PalaceTerrain.CLOISTER}

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

func spawn_enemies() -> void:
	if OS.get_cmdline_user_args().has("--palace-walk-only"): return
	for spec in [[Vector2(1940, 1580), TrainingEnemy.Role.FRAGMENT, 22.0], [Vector2(2160, 1610), TrainingEnemy.Role.BEAST, 45.0], [Vector2(2450, 1290), TrainingEnemy.Role.LAMP, 30.0]]:
		_spawn_enemy_at(spec[0], spec[1], spec[2])

func _on_enemy_defeated(_enemy: TrainingEnemy) -> void: kills += 1

func _build_terrain(_render_bounds := Rect2()) -> void:
	palace_root = PalaceKit.build(self)
	add_child(palace_root)

func _update_hud() -> void:
	if hud == null or not is_instance_valid(player): return
	hud.text = "왕궁 사원 · 독립 개발 구간\n%s · HP %d · 저장/보상 없음" % [terrain.surface_name(player.position), ceili(player.health)]
	if player_health_bar != null:
		player_health_bar.max_value = player.max_health
		player_health_bar.value = player.health

func _build_ui() -> void:
	super._build_ui()
	for canvas in get_children():
		if not canvas is CanvasLayer: continue
		var hint := canvas.get_node_or_null("ControlsHint")
		if hint != null: hint.text = "WASD 이동 · J 공격 · Space 베기 · Shift 대시 · Esc 정지 · R 재시작"
