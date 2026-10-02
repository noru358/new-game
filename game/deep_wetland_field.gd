extends "res://game/deep_wetland_trial.gd"
const Field = preload("res://game/deep_wetland_field_terrain.gd")
func _init() -> void:
	super._init()
	terrain = Field.new()
	landmark_points["안쪽 성소"] = Field.INNER_COURT
	landmark_points["공양터"] = Field.OFFERING_GROVE
	overview_camera_size = 65.0
	scene_title = "Deep wetland whole-field candidate"
func _dry_routes() -> Array:
	return super._dry_routes() + [Field.INNER_ROUTE, Field.RETURN_ROUTE]
func _place_encounters() -> Array:
	return super._place_encounters() + [
		[Vector2(3650, 980), TrainingEnemy.Role.FRAGMENT, 22.0],
		[Vector2(4130, 650), TrainingEnemy.Role.LAMP, 30.0],
		[Vector2(4880, 1020), TrainingEnemy.Role.ZONE, 32.0],
		[Vector2(5100, 1170), TrainingEnemy.Role.SUPPORT, 36.0],
		[Vector2(4070, 1710), TrainingEnemy.Role.BEAST, 45.0],
	]
func _build_terrain(render_bounds := Rect2()) -> void:
	super._build_terrain(render_bounds)
	for area in Field.INNER_RUINS:
		_stone(area.get_center(), Vector3(area.size.x / 200.0, 0.55, area.size.y / 200.0), Color("85927a"))
	# The inner temple silhouette lives on the blocked far bank; its combat floor stays clear.
	for x in [4740, 4940, 5140]:
		_stone(Vector2(x, 380), Vector3(0.8, 2.0, 0.8), Color("677e70"))
		_stone(Vector2(x, 380), Vector3(1.15, 0.18, 1.0), Color("899982"), 360)
	for point in [Vector2(4350, 300), Vector2(5500, 300)]:
		_stone(point, Vector3(0.44, 2.4, 0.50), Color("3d5848"))
		_stone(point, Vector3(1.45, 0.5, 1.35), Color("3d644f"), 370)
func _update_hud() -> void:
	super._update_hud()
	if hud != null: hud.text = hud.text.replace("대표 구간", "전체 동선 시험")

func _far_bank_groves() -> Array:
	var points := super._far_bank_groves()
	points.erase(Vector2(3670, 1000))
	points.append(Vector2(4130, 300))
	return points
