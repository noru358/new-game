extends "res://game/hybrid_height.gd"

const RegionTerrain = preload("res://game/temple_hybrid_terrain.gd")


func _init() -> void:
	terrain = RegionTerrain.new()
	start_point = Vector2(650, 1870)
	enemy_points = [
		Vector2(120, 1850), Vector2(650, 920), Vector2(960, 1100),
		Vector2(1760, 1050), Vector2(2280, 900), Vector2(2830, 1220),
		Vector2(3130, 850), Vector2(3400, 1380)
	]
	landmark_points = {
		"수변 남쪽": Vector2(650, 1870),
		"중정": Vector2(660, 1120),
		"테라스": Vector2(1000, 1100),
		"사원 뜰": Vector2(1780, 900),
		"회랑": Vector2(2700, 900),
		"성소": Vector2(3600, 1100)
	}
	scene_title = "Loop Conquest — 1F Hybrid Region v09"
	scene_hud_title = "청록 폐사원"
	combat_camera_size = 9.0
	camera_offset = Vector3(14, 13.864, 14)
	# Continue the original 1F cumulative card-unlock record in the main scene.
	growth_save_prefix = "user://loop_conquest_1d_unlocks"
