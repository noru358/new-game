extends "res://game/jungle_pass.gd"
## Full existing jungle plus a southern place circuit, using isolated development saves.
const SouthTerrain = preload("res://game/jungle_south_circuit_terrain.gd")
const SouthLayout = preload("res://game/jungle_south_circuit_layout.gd")
func _init() -> void:
	super._init()
	terrain = SouthTerrain.new()
	profile_save_prefix = "user://jungle_south_v44_profile"
	growth_save_prefix = "user://jungle_south_v44_unlocks"
	scene_title = "Jungle southern circuit — isolated development run"
	scene_hud_title = "정글 남쪽 순환 시험 · 별도 기록"
	overview_camera_size = 50.0
	landmark_points["강가 조망터"] = Vector2(3340, 2600)
	landmark_points["강변 통행 거점"] = Vector2(2080, 2910)
func region_layout(): return SouthLayout
func _create_region_section() -> Node:
	var section = preload("res://game/jungle_section.gd").new()
	section.layout = SouthLayout
	return section
func _ready() -> void:
	var session = preload("res://game/field_preview_session.gd")
	session.configure(self)
	if session.active(get_tree()): scene_hud_title = "정글 · 미리보기 공통 기록"
	if not session.active(get_tree()):
		# Explicit synthetic access in this separate trial, never a real campaign clear.
		var trial_profile := RunProfile.new()
		trial_profile.save_prefix = profile_save_prefix
		trial_profile.load_state()
		if not trial_profile.load_error and not trial_profile.temple_owned:
			trial_profile.settle("southern-circuit-development-access", "SUCCESS", 0, RunProfile.TEMPLE_REGION)
		if not trial_profile.load_error:
			var trial_unlocks := UnlockProgress.new()
			trial_unlocks.save_prefix = growth_save_prefix
			trial_unlocks.load_progress()
			while trial_unlocks.lifetime_levelups < 6:
				var previous := trial_unlocks.lifetime_levelups
				trial_unlocks.add_levelup()
				if trial_unlocks.lifetime_levelups == previous: break
	super._ready()
	var environment := preload("res://game/jungle_south_circuit_environment.gd").build(self)
	add_child(environment)
	main_decor.append(environment)
	var emergent_tree := preload("res://game/jungle_emergent_tree.gd").build()
	add_child(emergent_tree)
	main_decor.append(emergent_tree)

func _top(st: SurfaceTool, area: Rect2, elevation: Callable, color: Color) -> void:
	# Quiet continuous material on the field candidate, without prototype checker cells.
	var vertices: Array = []
	for point in [area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)]:
		vertices.append(Vector3(point.x, elevation.call(point), point.y))
	_quad(st, vertices, color)
