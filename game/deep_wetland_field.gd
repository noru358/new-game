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
	preload("res://game/wetland_environment.gd").build_field(self)
func _update_hud() -> void:
	super._update_hud()
	if hud != null: hud.text = hud.text.replace("대표 구간", "전체 동선 시험")

func _far_bank_groves() -> Array:
	var points := super._far_bank_groves()
	points.erase(Vector2(3670, 1000))
	points.append(Vector2(4130, 300))
	return points

func _inner_ruins() -> Array:
	return Field.INNER_RUINS
