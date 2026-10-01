extends RefCounted
## Two existing ordinary roles in the hybrid billboard renderer. Presentation only.

const FRAGMENT_TEXTURE := preload("res://game/enemy_fragment.svg")
const BEAST_TEXTURE := preload("res://game/enemy_beast.svg")
const PIXEL_SIZE := 0.01
const FOOT_Y := 74.0
static var hit_textures: Dictionary = {}


static func supports(role: int) -> bool:
	return role == TrainingEnemy.Role.FRAGMENT or role == TrainingEnemy.Role.BEAST


static func configure(body: Sprite3D, role: int) -> void:
	assert(supports(role))
	body.set_meta("enemy_role_body", role)
	body.set_meta("stride", 0.0)
	body.texture = _texture(role, false)
	_texture(role, true)
	body.pixel_size = PIXEL_SIZE
	body.modulate = Color.WHITE
	# Retain the renderer's depth-writing alpha scissor and camera-facing plane.
	_anchor(body)


static func update(body: Sprite3D, enemy: TrainingEnemy, delta: float) -> bool:
	# Bosses and the three untouched roles retain their original render path.
	if not body.has_meta("enemy_role_body"): return false
	var role := int(body.get_meta("enemy_role_body"))
	body.texture = _texture(role, enemy.hit_flash > 0.0)
	body.modulate = Color.WHITE
	var direction := enemy.velocity
	var warning := role == TrainingEnemy.Role.BEAST and enemy.warning_time > 0.0
	var charging := role == TrainingEnemy.Role.BEAST and enemy.charge_time > 0.0
	if warning or charging: direction = enemy.locked_direction
	var screen_x := direction.x - direction.y
	if absf(screen_x) > 0.1: body.flip_h = screen_x < 0.0
	var stride := float(body.get_meta("stride", 0.0))
	if not warning and not charging and enemy.velocity.length_squared() > 25.0:
		stride = fmod(stride + delta * enemy.velocity.length() * 0.10, TAU)
		body.set_meta("stride", stride)
		body.scale = Vector3(1.0, 1.0 - absf(sin(stride)) * 0.035, 1.0)
	else:
		body.scale = Vector3.ONE
	if warning:
		body.scale.y = lerpf(0.98, 0.88, clampf(1.0 - enemy.warning_time / TrainingEnemy.BEAST_WARNING, 0.0, 1.0))
	elif charging:
		body.scale.y = 0.84
	return true


static func _anchor(body: Sprite3D) -> void:
	# Sprite offset is in billboard pixels: the bottom stone corners are at the
	# local origin for every camera pitch and stay there during pose scaling.
	body.position = Vector3.ZERO
	body.offset = Vector2(0.0, FOOT_Y - float(body.texture.get_height()) * 0.5)


static func _texture(role: int, hit: bool) -> Texture2D:
	var base: Texture2D = BEAST_TEXTURE if role == TrainingEnemy.Role.BEAST else FRAGMENT_TEXTURE
	if not hit: return base
	if not hit_textures.has(role):
		# A shared pale texture makes actual hits visible on the authored colors;
		# white modulation alone cannot lighten an already colored sprite.
		var flash := base.get_image().duplicate() as Image
		for y in flash.get_height():
			for x in flash.get_width():
				var pixel := flash.get_pixel(x, y)
				var bright := Color(pixel.r, pixel.g, pixel.b).lerp(Color("fff8dc"), 0.80)
				bright.a = pixel.a
				flash.set_pixel(x, y, bright)
		hit_textures[role] = ImageTexture.create_from_image(flash)
	return hit_textures[role]
