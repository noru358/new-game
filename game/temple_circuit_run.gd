extends "res://game/hybrid_region.gd"
## Real four-minute loop on the candidate topology, with separate development saves.
const CircuitTerrain = preload("res://game/temple_circuit_run_terrain.gd")
const CircuitLayout = preload("res://game/temple_circuit_run_layout.gd")
func _init() -> void:
	super._init()
	terrain = CircuitTerrain.new()
	start_point = Vector2(650, 3000)
	enemy_points = []
	landmark_points = {"입구": start_point, "중심 뜰": Vector2(2450, 2100), "회랑": Vector2(1450, 1350), "성소": Vector2(2800, 620)}
	profile_save_prefix = "user://temple_circuit_v44_profile"
	growth_save_prefix = "user://temple_circuit_v44_unlocks"
	scene_title = "Temple circuit — isolated four-minute run"
	scene_hud_title = "사원 동선 시험 · 별도 기록"
	temple_environment_enabled = false
	temple_sanctuary_enabled = false
	temple_opening_enabled = false
	overview_camera_size = 54.0

func region_layout(): return CircuitLayout

func _create_region_section() -> Node:
	var section = TempleSectionScript.new()
	section.layout = CircuitLayout
	section.boss_area = Rect2(2380, 250, 900, 850)
	section.boss_point = Vector2(2800, 620)
	section.boss_spawn_points = [Vector2(2800, 620), Vector2(3100, 950), Vector2(2500, 800)]
	section.retry_point = Vector2(2650, 1210)
	section.destination_point = Vector2(2640, 1200)
	return section

func _ready() -> void:
	super._ready()
	growth.late_xp_slope_trial = OS.get_cmdline_user_args().has("--circuit-xp-trial")
	growth._update_hud()
