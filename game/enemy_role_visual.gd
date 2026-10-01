extends RefCounted
## The five existing ordinary roles in the hybrid billboard renderer. Presentation only.

const FRAGMENT_TEXTURE := preload("res://game/enemy_fragment.svg")
const BEAST_TEXTURE := preload("res://game/enemy_beast.svg")
const LAMP_TEXTURE := preload("res://game/enemy_lamp.svg")
const ZONE_TEXTURE := preload("res://game/enemy_zone.svg")
const SUPPORT_TEXTURE := preload("res://game/enemy_support.svg")
const PIXEL_SIZE := 0.01
const FOOT_Y := 74.0
const FIRE_RECOIL := 0.18
static var hit_textures: Dictionary = {}


static func supports(role: int) -> bool:
	return role in [TrainingEnemy.Role.FRAGMENT, TrainingEnemy.Role.BEAST, TrainingEnemy.Role.LAMP, TrainingEnemy.Role.ZONE, TrainingEnemy.Role.SUPPORT]


static func configure(body: Sprite3D, role: int) -> void:
	assert(supports(role))
	body.set_meta("enemy_role_body", role)
	body.set_meta("stride", 0.0)
	body.set_meta("shown_attacks", 0)
	body.set_meta("fire_recoil", 0.0)
	body.texture = _texture(role, false)
	_texture(role, true)
	body.pixel_size = PIXEL_SIZE
	body.modulate = Color.WHITE
	# Retain the renderer's depth-writing alpha scissor and camera-facing plane.
	_anchor(body)


static func update(body: Sprite3D, enemy: TrainingEnemy, delta: float) -> bool:
	# Boss figures and the hero retain their original render path.
	if not body.has_meta("enemy_role_body"): return false
	var role := int(body.get_meta("enemy_role_body"))
	body.texture = _texture(role, enemy.hit_flash > 0.0)
	body.modulate = Color.WHITE
	var direction := enemy.velocity
	var warning := role in [TrainingEnemy.Role.BEAST, TrainingEnemy.Role.LAMP] and enemy.warning_time > 0.0
	var charging := role == TrainingEnemy.Role.BEAST and enemy.charge_time > 0.0
	var recoil := maxf(0.0, float(body.get_meta("fire_recoil", 0.0)) - delta)
	if int(body.get_meta("shown_attacks", 0)) != enemy.attacks_fired:
		# Observe actual fire events. The zone's existing ground warning owns its
		# timing; the body must never imply an extra windup or delay its damage.
		if role in [TrainingEnemy.Role.LAMP, TrainingEnemy.Role.ZONE]: recoil = FIRE_RECOIL
		body.set_meta("shown_attacks", enemy.attacks_fired)
	if enemy.hit_flash > 0.0 or enemy.gathering: recoil = 0.0
	body.set_meta("fire_recoil", recoil)
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
	if warning and role == TrainingEnemy.Role.BEAST:
		body.scale.y = lerpf(0.98, 0.88, clampf(1.0 - enemy.warning_time / TrainingEnemy.BEAST_WARNING, 0.0, 1.0))
	elif warning:
		body.scale.y = lerpf(0.96, 1.04, clampf(1.0 - enemy.warning_time / TrainingEnemy.LAMP_WARNING, 0.0, 1.0))
	elif charging:
		body.scale.y = 0.84
	elif recoil > 0.0:
		body.scale.y = 1.0 - 0.10 * recoil / FIRE_RECOIL
	return true


static func _anchor(body: Sprite3D) -> void:
	# Sprite offset is in billboard pixels: the bottom stone corners are at the
	# local origin for every camera pitch and stay there during pose scaling.
	body.position = Vector3.ZERO
	body.offset = Vector2(0.0, FOOT_Y - float(body.texture.get_height()) * 0.5)


static func _texture(role: int, hit: bool) -> Texture2D:
	var base: Texture2D
	match role:
		TrainingEnemy.Role.BEAST: base = BEAST_TEXTURE
		TrainingEnemy.Role.LAMP: base = LAMP_TEXTURE
		TrainingEnemy.Role.ZONE: base = ZONE_TEXTURE
		TrainingEnemy.Role.SUPPORT: base = SUPPORT_TEXTURE
		_: base = FRAGMENT_TEXTURE
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
