extends RefCounted
## Presentation-only three-direction idle trial. No timing or simulation writes.
const FRONT = preload("res://game/fennec_idle/front.png")
const SIDE = preload("res://game/fennec_idle/side.png")
const BACK = preload("res://game/fennec_idle/back.png")
const CANVAS := Vector2i(384, 448)
const FOOT := Vector2(192, 416)
const PIXEL_SIZE := 0.0025 # 384 authored height = existing 0.96 world-unit body.

static func configure(body: Sprite3D) -> void:
	body.pixel_size = PIXEL_SIZE
	body.position = Vector3.UP * 0.04
	body.offset = Vector2(0, FOOT.y - CANVAS.y * 0.5)
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
	set_direction(body, direction(facing, camera))
	body.flip_h = direction(facing, camera) == "side" and Vector3(facing.x, 0, facing.y).dot(camera.global_basis.x) < 0.0

static func set_direction(body: Sprite3D, view: String) -> void:
	assert(view in ["front", "side", "back"])
	body.texture = FRONT if view == "front" else BACK if view == "back" else SIDE
	body.flip_h = false
	body.set_meta("fennec_idle_view", view)
