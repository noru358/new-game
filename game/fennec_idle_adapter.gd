extends RefCounted
## Presentation-only three-direction idle trial. No timing or simulation writes.
const FRONT = preload("res://game/fennec_idle/front.png")
const SIDE = preload("res://game/fennec_idle/side.png")
const BACK = preload("res://game/fennec_idle/back.png")
const CANVAS := Vector2i(384, 448)
const FOOT := Vector2(192, 416)
const BASE_PIXEL_SIZE := 0.0025 # Historical ear-inclusive comparison, retained.
const TRIAL_SCALE := 1417.0 / 1176.0 # Parent's provisional crown-height choice.
const PIXEL_SIZE := BASE_PIXEL_SIZE * TRIAL_SCALE
const FOOT_X := {"front": 190.0, "side": 187.0, "back": 195.5}

static func configure(body: Sprite3D) -> void:
	body.pixel_size = PIXEL_SIZE
	body.position = Vector3.UP * 0.04
	body.offset = anchor_offset("front", false)
	body.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	body.alpha_scissor_threshold = 0.5
	body.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	body.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	body.set_meta("fennec_idle_trial", true)
	set_direction(body, "front")

static func direction(facing: Vector2, camera: Camera3D) -> String:
	var world := Vector3(facing.x, 0, facing.y)
	var horizontal := world.dot(camera.global_basis.x)
	var toward := world.dot(camera.global_basis.z)
	if absf(horizontal) > absf(toward): return "side"
	return "front" if toward >= 0.0 else "back"

static func update(body: Sprite3D, facing: Vector2, camera: Camera3D) -> void:
	var view := direction(facing, camera)
	var mirrored := view == "side" and Vector3(facing.x, 0, facing.y).dot(camera.global_basis.x) < 0.0
	set_direction(body, view, mirrored)

static func anchor_offset(view: String, mirrored: bool) -> Vector2:
	var anchor_x := float(FOOT_X[view])
	if mirrored: anchor_x = CANVAS.x - anchor_x
	return Vector2(CANVAS.x * 0.5 - anchor_x, FOOT.y - CANVAS.y * 0.5)

static func set_direction(body: Sprite3D, view: String, mirrored := false) -> void:
	assert(view in ["front", "side", "back"])
	body.texture = FRONT if view == "front" else BACK if view == "back" else SIDE
	body.flip_h = mirrored
	body.offset = anchor_offset(view, mirrored)
	body.set_meta("fennec_idle_view", view)
