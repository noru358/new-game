extends Node3D

const Terrain = preload("res://game/hybrid_terrain.gd")
const PlayerScene = preload("res://game/player.tscn")
const EnemyScene = preload("res://game/enemy.tscn")
const GrowthScript = preload("res://game/run_growth.gd")
const MinimapScript = preload("res://game/hybrid_minimap.gd")
const ActorTexture = preload("res://game/hybrid_actor.svg")
const COMBAT_CAMERA_SIZE := 10.8
const OVERVIEW_CAMERA_SIZE := 30.0
const ACTOR_CLEARANCE := 30.0
const ENEMY_POINTS := [Vector2(390, 1660), Vector2(720, 680), Vector2(1430, 1000), Vector2(1700, 1320), Vector2(2100, 1100), Vector2(890, 600), Vector2(1380, 1360), Vector2(2100, 1240)]
const ENEMY_ROLES := [TrainingEnemy.Role.FRAGMENT, TrainingEnemy.Role.FRAGMENT, TrainingEnemy.Role.FRAGMENT, TrainingEnemy.Role.BEAST, TrainingEnemy.Role.LAMP, TrainingEnemy.Role.LAMP, TrainingEnemy.Role.ZONE, TrainingEnemy.Role.SUPPORT]
const ENEMY_HEALTH := [22.0, 22.0, 22.0, 45.0, 30.0, 30.0, 32.0, 36.0]
var terrain := Terrain.new()
var start_point := Vector2(930, 1780)
var enemy_points := ENEMY_POINTS.duplicate()
var landmark_points := {"남쪽 입구": Vector2(930, 1780), "디딤돌": Vector2(1290, 1840), "북쪽 입구": Vector2(930, 220), "측면 입구": Vector2(2080, 1180), "테라스": Vector2(1390, 1000)}
var scene_title := "Loop Conquest — Hybrid Court v09"
var scene_hud_title := "높이 비교"
var combat_camera_size := COMBAT_CAMERA_SIZE
var overview_camera_size := OVERVIEW_CAMERA_SIZE
var camera_offset := Vector3(14, 11.431, 14)
var show_practice_controls := true
var moving_slash_practice := false
var simulation := Node2D.new()
var player: SandboxPlayer
var wisp: WispCompanion
var growth: RunGrowth
var navigation := ArenaNavigation.new()
var camera := Camera3D.new()
var actors: Dictionary = {}
var actor_motion: Dictionary = {}
var shots: Dictionary = {}
var shot_motion: Dictionary = {}
var shot_height_data: Dictionary = {}
var wisp_visual: MeshInstance3D
var wisp_visuals: Dictionary = {}
var wisp_motion: Dictionary = {}
var growth_save_prefix := "user://loop_conquest_hybrid_lab_unlocks"
var attack_visual := MeshInstance3D.new()
var attack_mesh := ImmediateMesh.new()
var moving_slash_visual := MeshInstance3D.new()
var moving_slash_mesh := ImmediateMesh.new()
var warning_visual := MeshInstance3D.new()
var warning_mesh := ImmediateMesh.new()
var warning_vertex_count := 0
var seal_visual: MeshInstance3D
var hud: Label
var moving_slash_status: Label
var minimap: Control
var pause_label: Label
var pause_backdrop: ColorRect
var overview := false
var kills := 0
var paused := false
var terrain_mesh: MeshInstance3D
var previous_attack_step := 0
var current_attack_step := 0
var previous_attack_elapsed := 0.0
var current_attack_elapsed := 0.0
var previous_attack_direction := Vector2.RIGHT
var current_attack_direction := Vector2.RIGHT

func _ready() -> void:
	get_window().title = scene_title
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 100
	_register_inputs()
	_build_terrain()
	_build_camera()
	simulation.name = "Simulation2D"
	simulation.process_mode = Node.PROCESS_MODE_PAUSABLE
	simulation.hide()
	add_child(simulation)
	var obstacles: Array = []
	for area in terrain.barriers():
		var block := TempleBlock.new()
		block.setup(area, terrain.water_areas.has(area))
		simulation.add_child(block)
		obstacles.append(block)
	navigation.agent_radius = ACTOR_CLEARANCE
	navigation.strict_contact_escape = true
	navigation.setup(obstacles, terrain.map_size)
	player = PlayerScene.instantiate()
	_set_actor_radius(player, ACTOR_CLEARANCE)
	player.get_node("Camera2D").enabled = false
	player.position = start_point
	player.arena_bounds = Rect2(Vector2.ZERO, terrain.map_size)
	player.collision_mask = 4
	player.input_rotation = -PI / 4.0
	player.move_speed_multiplier = 1.12
	player.dash_distance_multiplier = 1.16
	player.basic_speed_bonus = 0.18
	player.attack_active_multiplier = 1.6
	player.attack_recovery_multiplier = 0.78
	player.attack_path_filter = clear_attack
	player.moving_slash_enabled = moving_slash_practice
	simulation.add_child(player)
	player.set_dash_upgrade(2)
	actors[player] = _actor_visual(Color.WHITE)
	actor_motion[player] = [player.global_position, player.global_position]
	player.attack_landed.connect(_on_player_attack_landed)
	player.moving_slash_landed.connect(func(point: Vector2): _flash(point, Color("b7f8ff"), 0.23))
	wisp = WispCompanion.new()
	wisp.player = player
	wisp.facing_formation = true
	# A faster core gives the curved projectile a firmer launch without changing
	# the accepted attack interval or its homing rule.
	wisp.projectile_speed = 740.0
	wisp.navigation = navigation
	wisp.target_visibility_filter = _on_screen
	wisp.follow_position_filter = _constrain_wisp
	simulation.add_child(wisp)
	wisp_visual = _sphere(0.13, Color("49dce8"))
	add_child(wisp_visual)
	wisp_visual.position = terrain.world_point(wisp.global_position, 80)
	wisp_visual.reset_physics_interpolation()
	wisp_visuals[wisp] = wisp_visual
	wisp_motion[wisp] = [wisp.global_position, wisp.global_position]
	growth = GrowthScript.new()
	growth.setup(simulation, player, wisp)
	growth.unlocks.save_prefix = growth_save_prefix
	growth.basic_speed_base = player.basic_speed_bonus
	growth.hud_position = Vector2(28, 128)
	# Keep the accepted two-charge movement baseline in this comparison scene.
	growth.card_ranks["U_STEP"] = 2
	add_child(growth)
	growth.card_applied.connect(_on_card_applied)
	_sync_wisp_visuals()
	attack_visual.mesh = attack_mesh
	var attack_material := _material(Color.WHITE, true)
	attack_material.vertex_color_use_as_albedo = true
	attack_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Opaque terrain writes depth; the swing must disappear behind a wall.
	attack_material.no_depth_test = false
	attack_visual.material_override = attack_material
	attack_visual.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(attack_visual)
	moving_slash_visual.mesh = moving_slash_mesh
	var moving_slash_material := _material(Color.WHITE, true)
	moving_slash_material.vertex_color_use_as_albedo = true
	moving_slash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	moving_slash_material.no_depth_test = false
	moving_slash_visual.material_override = moving_slash_material
	moving_slash_visual.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(moving_slash_visual)
	warning_visual.mesh = warning_mesh
	var warning_material := _material(Color.WHITE, true)
	warning_material.vertex_color_use_as_albedo = true
	warning_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	warning_visual.material_override = warning_material
	warning_visual.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(warning_visual)
	seal_visual = _sphere(0.17, Color("dfbaff"))
	seal_visual.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	seal_visual.hide()
	add_child(seal_visual)
	spawn_enemies()
	_build_ui()
	camera.position = terrain.world_point(player.position) + camera_offset
	camera.look_at(terrain.world_point(player.position), Vector3.UP)
	camera.reset_physics_interpolation()
	get_window().focus_exited.connect(func():
		if not growth.choosing: _set_paused(true)
	)
	print("Hybrid scene ready: ", scene_title)

func _register_inputs() -> void:
	var keys := {"move_left": KEY_A, "move_right": KEY_D, "move_up": KEY_W, "move_down": KEY_S, "attack": KEY_J, "dash": KEY_SPACE, "moving_slash": KEY_Q}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = keys[action]
			InputMap.action_add_event(action, event)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	if not InputMap.action_has_event("attack", mouse):
		InputMap.action_add_event("attack", mouse)

func _material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func _quad(st: SurfaceTool, points: Array, color: Color) -> void:
	for index in [0, 2, 1, 0, 3, 2]:
		st.set_color(color)
		st.add_vertex(points[index] * Terrain.SCALE)

func _top(st: SurfaceTool, area: Rect2, elevation: Callable, color: Color) -> void:
	for x in range(int(area.position.x), int(area.end.x), 100):
		for z in range(int(area.position.y), int(area.end.y), 100):
			var x1 := minf(x + 100, area.end.x)
			var z1 := minf(z + 100, area.end.y)
			var corners := [Vector2(x, z), Vector2(x1, z), Vector2(x1, z1), Vector2(x, z1)]
			var vertices: Array = []
			for point in corners:
				vertices.append(Vector3(point.x, elevation.call(point), point.y))
			_quad(st, vertices, color.lightened(0.035) if (x / 100 + z / 100) % 2 == 0 else color)

func _sides(st: SurfaceTool, area: Rect2, elevation: Callable, bottom: float, color: Color, openings: Dictionary = {}, skip_sides: Array = []) -> void:
	var corners := [area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)]
	for i in range(4):
		var side: String = ["north", "east", "south", "west"][i]
		if side in skip_sides:
			continue
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var axis := 0 if i % 2 == 0 else 1
		var spans: Array = []
		var cursor: float = minf(a[axis], b[axis])
		for opening in openings.get(side, []):
			if opening[0] > cursor:
				spans.append([cursor, opening[0]])
			cursor = opening[1]
		if cursor < maxf(a[axis], b[axis]):
			spans.append([cursor, maxf(a[axis], b[axis])])
		for span in spans:
			var p0 := a
			var p1 := b
			p0[axis] = span[0]
			p1[axis] = span[1]
			_quad(st, [Vector3(p0.x, bottom, p0.y), Vector3(p1.x, bottom, p1.y), Vector3(p1.x, elevation.call(p1), p1.y), Vector3(p0.x, elevation.call(p0), p0.y)], color)

func _stepping_stones(st: SurfaceTool, ramp: Dictionary) -> void:
	var area: Rect2 = ramp.area
	var step_length := area.size.y / Terrain.STONE_COUNT
	var x0 := area.position.x
	var x1 := area.end.x
	var edges: Array[Vector2] = [Vector2(8, 21), Vector2(22, 9), Vector2(5, 18), Vector2(19, 7), Vector2(10, 16), Vector2(15, 11)]
	for i in Terrain.STONE_COUNT:
		var stone_left: float = x0 + edges[i].x
		var stone_right: float = x1 - edges[i].y
		var link_left := x0 + 30.0
		var link_right := x1 - 30.0
		var y0 := area.position.y + step_length * i
		var seam := y0 + step_length * (1.0 - Terrain.STONE_BEVEL)
		var y1 := y0 + step_length
		var h0: float = lerpf(ramp.from, ramp.to, float(i) / Terrain.STONE_COUNT)
		var h1: float = lerpf(ramp.from, ramp.to, float(i + 1) / Terrain.STONE_COUNT)
		var face := Color("aeb8aa") if i % 2 == 0 else Color("a1ada2")
		var outline := [
			Vector2(stone_left + 10, y0), Vector2(stone_right - 11, y0),
			Vector2(stone_right, y0 + 7), Vector2(stone_right - 7, seam),
			Vector2(stone_left + 9, seam), Vector2(stone_left, y0 + 6)
		]
		var center := Vector2((stone_left + stone_right) * 0.5, (y0 + seam) * 0.5)
		for side in outline.size():
			var a: Vector2 = outline[side]
			var b: Vector2 = outline[(side + 1) % outline.size()]
			for vertex in [Vector3(center.x, h0, center.y), Vector3(a.x, h0, a.y), Vector3(b.x, h0, b.y)]:
				st.set_color(face)
				st.add_vertex(vertex * Terrain.SCALE)
			_quad(st, [Vector3(a.x, 0, a.y), Vector3(b.x, 0, b.y), Vector3(b.x, h0, b.y), Vector3(a.x, h0, a.y)], Color("71857d"))
		_quad(st, [Vector3(link_left, h0, seam), Vector3(link_right, h0, seam), Vector3(link_right, h1, y1), Vector3(link_left, h1, y1)], Color("647b72"))
		for x in [link_left, link_right]:
			_quad(st, [Vector3(x, 0, seam), Vector3(x, 0, y1), Vector3(x, h1, y1), Vector3(x, h0, seam)], Color("647970"))

func _build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_top(st, Rect2(Vector2.ZERO, terrain.map_size), func(_p): return 0.0, Color("93afa1"))
	for floor in terrain.floor_areas:
		_top(st, floor.area, func(_p): return float(floor.get("height", 0.7)), floor.color)
	for water in terrain.water_areas:
		_top(st, water, func(_p): return 1.0, Color("39858b"))
	for plateau in terrain.plateaus:
		var elevation := func(_p): return plateau.height
		_top(st, plateau.area, elevation, Color("d6cfb1") if plateau.height == 160 else Color("e7ddbd"))
		_sides(st, plateau.area, elevation, plateau.base, Color("798e80"), plateau.openings)
	for ramp in terrain.ramps:
		if ramp.get("kind", "") == "stepping_stones":
			_stepping_stones(st, ramp)
			continue
		var elevation := func(p): return terrain.ramp_height(ramp, p)
		_top(st, ramp.area, elevation, Color("c9bb91"))
		_sides(st, ramp.area, elevation, minf(ramp.from, ramp.to), Color("8c8e77"), {}, ["north", "south"] if ramp.axis == 1 else ["west", "east"])
	for wall in terrain.wall_areas:
		var elevation := func(_p): return wall.height
		_top(st, wall.area, elevation, wall.color)
		_sides(st, wall.area, elevation, wall.get("base", 0.0), wall.color.darkened(0.25))
	st.generate_normals()
	terrain_mesh = MeshInstance3D.new()
	terrain_mesh.mesh = st.commit()
	var mat := _material(Color.WHITE)
	mat.vertex_color_use_as_albedo = true
	terrain_mesh.material_override = mat
	add_child(terrain_mesh)

func _build_camera() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("607f78")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.75
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 0.65
	add_child(sun)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = combat_camera_size
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(camera)
	camera.current = true

func _sphere(radius: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = 12
	mesh.rings = 6
	node.mesh = mesh
	node.material_override = _material(color, true)
	return node

func _actor_visual(color: Color) -> Node3D:
	var root := Node3D.new()
	root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var sprite := Sprite3D.new()
	sprite.name = "Body"
	sprite.texture = ActorTexture
	sprite.pixel_size = 0.01
	# Offset in camera-up direction so billboard feet stay on the sampled ground.
	sprite.position = Vector3(-0.353553, 0.866025, -0.353553) * 0.44
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Alpha-scissor writes depth consistently when the billboard brushes a cliff face.
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.modulate = color
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	root.add_child(sprite)
	var shadow := MeshInstance3D.new()
	shadow.name = "Shadow"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.24
	disc.bottom_radius = 0.24
	disc.height = 0.008
	disc.radial_segments = 16
	shadow.mesh = disc
	shadow.position.y = 0.012
	shadow.material_override = _material(Color("52685f"), true)
	root.add_child(shadow)
	add_child(root)
	return root

func _add_health_bar(visual: Node3D, enemy: TrainingEnemy) -> void:
	var bar := Sprite3D.new()
	bar.name = "HealthBar"
	bar.pixel_size = 0.012
	bar.position.y = 1.10
	bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bar.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	bar.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var ratio := clampf(enemy.health / enemy.max_health, 0.0, 1.0)
	bar.texture = ImageTexture.create_from_image(_health_bar_image(enemy, ratio))
	bar.set_meta("shown_ratio", ratio)
	visual.add_child(bar)

func _update_health_bar(visual: Node3D, enemy: TrainingEnemy) -> void:
	var bar: Sprite3D = visual.get_node_or_null("HealthBar")
	if bar == null: return
	var ratio := clampf(enemy.health / enemy.max_health, 0.0, 1.0)
	if is_equal_approx(float(bar.get_meta("shown_ratio", -1.0)), ratio): return
	bar.set_meta("shown_ratio", ratio)
	(bar.texture as ImageTexture).update(_health_bar_image(enemy, ratio))

func _health_bar_image(enemy: TrainingEnemy, ratio: float) -> Image:
	var image := Image.create(48, 7, false, Image.FORMAT_RGBA8)
	var fill_color := Color("f6b76c") if enemy.role == TrainingEnemy.Role.LAMP else Color("ee836e") if enemy.role == TrainingEnemy.Role.BEAST else Color("80e7d8") if enemy.role == TrainingEnemy.Role.ZONE else Color("c7a6f6") if enemy.role == TrainingEnemy.Role.SUPPORT else Color("98dfad")
	if enemy.max_health >= 500.0: fill_color = Color("ffbb70")
	for y in 7:
		for x in 48:
			var inside := x > 0 and x < 47 and y > 0 and y < 6
			image.set_pixel(x, y, fill_color if inside and x <= ceili(46.0 * ratio) else Color("1a3435") if inside else Color("071c20"))
	return image

func _set_actor_radius(actor: CharacterBody2D, radius: float) -> void:
	var collision: CollisionShape2D = actor.get_node("CollisionShape2D")
	var shape: CircleShape2D = collision.shape.duplicate()
	shape.radius = radius
	collision.shape = shape
	actor.set("collision_radius", radius)

func spawn_enemies() -> void:
	for actor in actors.keys():
		if actor != player:
			if is_instance_valid(actor): actor.queue_free()
			actors[actor].queue_free()
			actors.erase(actor)
			actor_motion.erase(actor)
	for i in enemy_points.size():
		_spawn_enemy_at(enemy_points[i], ENEMY_ROLES[i], ENEMY_HEALTH[i])

func _spawn_enemy_at(point: Vector2, role: TrainingEnemy.Role, health: float) -> TrainingEnemy:
	var enemy: TrainingEnemy = EnemyScene.instantiate()
	_set_actor_radius(enemy, ACTOR_CLEARANCE)
	enemy.contact_margin = 3.0
	enemy.position = point
	enemy.role = role
	enemy.max_health = health
	enemy.target = player
	enemy.arena_bounds = Rect2(Vector2.ZERO, terrain.map_size)
	enemy.collision_mask = 6
	enemy.navigation = navigation
	enemy.projectile_parent = simulation
	enemy.zone_path_filter = clear_attack
	simulation.add_child(enemy)
	var visual := _actor_visual(_enemy_color(enemy.role))
	_add_health_bar(visual, enemy)
	if enemy.role != TrainingEnemy.Role.FRAGMENT:
		var marker := _sphere(0.14 if enemy.role == TrainingEnemy.Role.BEAST else 0.11, _enemy_color(enemy.role).lightened(0.25))
		marker.position.y = 0.86
		visual.add_child(marker)
	actors[enemy] = visual
	actor_motion[enemy] = [enemy.global_position, enemy.global_position]
	enemy.defeated.connect(_on_enemy_defeated.bind(enemy))
	return enemy

func _on_enemy_defeated(enemy: TrainingEnemy) -> void:
	kills += 1
	growth.on_enemy_defeated(enemy)

func _on_player_attack_landed(point: Vector2, direction: Vector2, step: int, finisher: bool) -> void:
	if player.attack_hitstop_scale <= 0.0:
		_flash(point, Color("94e9ff") if step == 3 else Color("ffd486"))
		return
	var color := Color("80f0f1") if step == 1 else Color("d6b2ff") if step == 2 else Color("94e9ff") if step == 3 else Color("ffe2a0")
	_flash(point, color, 0.27 if finisher else 0.20)
	if not player.impact_played_this_attack:
		camera.position -= Vector3(direction.x, 0.0, direction.y) * (0.10 if finisher else 0.055)

func _enemy_color(role: TrainingEnemy.Role) -> Color:
	match role:
		TrainingEnemy.Role.BEAST: return Color("e79683")
		TrainingEnemy.Role.LAMP: return Color("ffe0a0")
		TrainingEnemy.Role.ZONE: return Color("74ded8")
		TrainingEnemy.Role.SUPPORT: return Color("cba9f2")
		_: return Color("aec8be")

func clear_attack(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, 4)
	query.hit_from_inside = true
	return simulation.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _on_screen(candidate: Node2D) -> bool:
	var point := terrain.world_point(candidate.global_position, 40)
	return not camera.is_position_behind(point) and get_viewport().get_visible_rect().has_point(camera.unproject_position(point))

func _constrain_wisp(point: Vector2) -> Vector2:
	var query := PhysicsRayQueryParameters2D.create(player.global_position, point, 4)
	query.hit_from_inside = true
	var hit := simulation.get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return point
	return hit.position.move_toward(player.global_position, 15.0)

func _on_card_applied(card_id: String) -> void:
	if card_id.begins_with("S_WISP"):
		_sync_wisp_visuals()
	if growth.seal != null:
		growth.seal.target_visibility_filter = _on_screen
		if not growth.seal.enemy_hit.is_connected(_on_seal_hit):
			growth.seal.enemy_hit.connect(_on_seal_hit)

func _on_seal_hit(enemy: TrainingEnemy) -> void:
	_flash(enemy.global_position, Color("d29bff"))

func _sync_wisp_visuals() -> void:
	for companion in growth.wisps:
		companion.facing_formation = true
		companion.target_visibility_filter = _on_screen
		companion.follow_position_filter = _constrain_wisp
		if not companion.enemy_hit.is_connected(_on_wisp_hit):
			companion.enemy_hit.connect(_on_wisp_hit)
		if not wisp_visuals.has(companion):
			var new_visual := _sphere(0.13, Color("49dce8"))
			new_visual.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			add_child(new_visual)
			new_visual.position = terrain.world_point(companion.global_position, 80)
			wisp_visuals[companion] = new_visual
			wisp_motion[companion] = [companion.global_position, companion.global_position]
		var visual: MeshInstance3D = wisp_visuals[companion]
		(visual.material_override as StandardMaterial3D).albedo_color = Color("49dce8").lerp(Color("e3ffff"), float(companion.power_rank) / 3.0)

func _on_wisp_hit(enemy: TrainingEnemy) -> void:
	_flash(enemy.global_position, Color("66efff"))
	var pulse := _sphere(0.13, Color("bafaff"))
	add_child(pulse)
	pulse.position = terrain.world_point(enemy.global_position, 55.0)
	var tween := create_tween()
	tween.tween_property(pulse, "scale", Vector3.ONE * 2.8, 0.15)
	tween.parallel().tween_property(pulse, "transparency", 1.0, 0.15)
	tween.tween_callback(pulse.queue_free)

func _physics_process(delta: float) -> void:
	if paused or not is_instance_valid(player): return
	for actor in actors.keys():
		if not is_instance_valid(actor):
			actors[actor].queue_free()
			actors.erase(actor)
			actor_motion.erase(actor)
			continue
		var visual: Node3D = actors[actor]
		var samples: Array = actor_motion.get(actor, [actor.global_position, actor.global_position])
		actor_motion[actor] = [samples[1], actor.global_position]
		# Keep the physics pose available to physics-frame checks. The render
		# callback replaces it with an interpolated pose before drawing.
		visual.position = terrain.world_point(actor.global_position)
	previous_attack_step = current_attack_step
	previous_attack_elapsed = current_attack_elapsed
	previous_attack_direction = current_attack_direction
	current_attack_step = player.attack_step
	current_attack_elapsed = player.attack_elapsed
	current_attack_direction = player.attack_direction
	for companion in wisp_visuals:
		if not is_instance_valid(companion): continue
		var samples: Array = wisp_motion[companion]
		wisp_motion[companion] = [samples[1], companion.global_position]
		wisp_visuals[companion].position = terrain.world_point(companion.global_position, 80)
	for group in ["wisp_projectiles", "enemy_bolts"]:
		for shot in get_tree().get_nodes_in_group(group):
			if not shots.has(shot):
				var powered: bool = group == "wisp_projectiles"
				var rank: int = shot.power_rank if powered else 0
				var visual := _sphere(0.075 + 0.015 * float(rank) if powered else 0.095, Color("96f4ff").lerp(Color.WHITE, float(rank) / 3.0) if powered else Color("ffe18c"))
				visual.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
				add_child(visual)
				if powered:
					var tail := _sphere(0.055 + 0.008 * float(rank), Color("42c8f2"))
					tail.name = "Tail"
					visual.add_child(tail)
				shots[shot] = visual
				shot_motion[shot] = [shot.global_position, shot.global_position]
				var launch: Vector2 = shot.visual_origin if shot.visual_origin != Vector2.ZERO else shot.global_position
				var target_point: Vector2 = shot.target.global_position if powered and is_instance_valid(shot.target) else player.global_position
				shot_height_data[shot] = [launch, terrain.height_at(launch), terrain.height_at(target_point), maxf(1.0, launch.distance_to(target_point))]
			var samples: Array = shot_motion[shot]
			shot_motion[shot] = [samples[1], shot.global_position]
			shots[shot].position = _shot_world_point(shot, shot.global_position)
			if shots[shot].has_node("Tail"):
				shots[shot].get_node("Tail").position = Vector3(-shot.direction.x, 0.0, -shot.direction.y) * 0.15
	for shot in shots.keys():
		if not is_instance_valid(shot):
			shots[shot].queue_free()
			shots.erase(shot)
			shot_motion.erase(shot)
			shot_height_data.erase(shot)
	_update_hud()

func _process(delta: float) -> void:
	if paused or not is_instance_valid(player): return
	var fraction := Engine.get_physics_interpolation_fraction()
	for actor in actors:
		if not is_instance_valid(actor): continue
		var point := _render_position(actor, fraction)
		var visual: Node3D = actors[actor]
		visual.position = terrain.world_point(point)
		if actor == player:
			var body: Sprite3D = visual.get_node("Body")
			body.flip_h = player.facing.x - player.facing.y < -0.1
			var slash_progress: float = 1.0 - player.moving_slash_time / SandboxPlayer.MOVING_SLASH_DURATION
			body.rotation.z = 0.19 * sin(PI * slash_progress) if player.moving_slash_time > 0.0 else -0.14 if player.attack_step == 3 else 0.16 if player.attack_step == 4 else 0.0
			body.scale = Vector3.ONE * (1.08 if player.attack_step == 4 else 1.0)
		elif actor is TrainingEnemy:
			visual.get_node("Body").modulate = Color.WHITE if actor.hit_flash > 0.0 else _enemy_color(actor.role)
			_update_health_bar(visual, actor)
		var dx: float = (terrain.height_at(point + Vector2(1, 0)) - terrain.height_at(point - Vector2(1, 0))) * 0.5
		var dz: float = (terrain.height_at(point + Vector2(0, 1)) - terrain.height_at(point - Vector2(0, 1))) * 0.5
		visual.get_node("Shadow").quaternion = Quaternion(Vector3.UP, Vector3(-dx, 1, -dz).normalized())
	var player_point := _render_position(player, fraction)
	for shot in shots:
		if is_instance_valid(shot):
			var samples: Array = shot_motion[shot]
			shots[shot].position = _shot_world_point(shot, (samples[0] as Vector2).lerp(samples[1], fraction))
	for companion in wisp_visuals:
		if not is_instance_valid(companion): continue
		var samples: Array = wisp_motion[companion]
		var point: Vector2 = (samples[0] as Vector2).lerp(samples[1], fraction)
		var visual: MeshInstance3D = wisp_visuals[companion]
		visual.position = terrain.world_point(point, 80.0 + sin(companion.age * 5.4) * 3.0)
		visual.scale = Vector3.ONE * (1.0 + 0.15 * float(companion.power_rank) + (0.45 if companion.muzzle_flash > 0.0 else 0.0))
	seal_visual.visible = growth.seal != null and (growth.seal.telegraph > 0.0 or growth.seal.burst_time > 0.0)
	if seal_visual.visible:
		var seal := growth.seal
		seal_visual.position = terrain.world_point(seal.global_position, 76.0)
		seal_visual.scale = Vector3.ONE * (1.7 if seal.burst_time > 0.0 else 1.0 + 0.30 * sin(Time.get_ticks_msec() * 0.018))
	var focus := terrain.world_point(player_point, 35)
	if overview: focus = Vector3(terrain.map_size.x * 0.5, 80.0, terrain.map_size.y * 0.5) * Terrain.SCALE
	camera.position = camera.position.lerp(focus + camera_offset, 1.0 - exp(-8.0 * delta))
	var attack_elapsed := current_attack_elapsed
	var attack_direction := current_attack_direction
	if current_attack_step == previous_attack_step:
		attack_elapsed = lerpf(previous_attack_elapsed, current_attack_elapsed, fraction)
		attack_direction = Vector2.from_angle(lerp_angle(previous_attack_direction.angle(), current_attack_direction.angle(), fraction))
	_draw_attack_at(player_point, attack_elapsed, attack_direction)
	_draw_moving_slash(player_point)
	_draw_enemy_warnings(fraction)

func _render_position(actor: Node2D, fraction: float) -> Vector2:
	var samples: Array = actor_motion.get(actor, [actor.global_position, actor.global_position])
	return (samples[0] as Vector2).lerp(samples[1], fraction)

func _shot_world_point(shot: Node2D, point: Vector2) -> Vector3:
	var data: Array = shot_height_data[shot]
	var progress: float = clampf((data[0] as Vector2).distance_to(point) / float(data[3]), 0.0, 1.0)
	var elevation: float = lerpf(float(data[1]), float(data[2]), progress)
	return Vector3(point.x, elevation + 55.0, point.y) * Terrain.SCALE

func _update_hud() -> void:
	if hud == null: return
	hud.text = "%s  ·  %s\nHP %d   대시 %d/%d   연계 %d타   처치 %d\n%s" % [scene_hud_title, terrain.surface_name(player.position), player.health, player.dash_charges, player.dash_max_charges, player.combo_limit(), kills, "쓰러졌습니다 · R로 다시 시작" if player.health <= 0 else ""]
	if moving_slash_status != null:
		moving_slash_status.text = "Q 이동 베기 · %s" % ("누적 첫 레벨업 때 영구 습득" if not player.moving_slash_enabled else "진행 중" if player.moving_slash_time > 0.0 else "%.1f초" % player.moving_slash_cooldown if player.moving_slash_cooldown > 0.0 else "준비")

func _draw_attack() -> void:
	_draw_attack_at(player.global_position, player.attack_elapsed, player.attack_direction)

func _draw_attack_at(origin: Vector2, elapsed: float, direction: Vector2) -> void:
	attack_mesh.clear_surfaces()
	if player.attack_step == 0: return
	var spec: Dictionary = player._attack_spec(player.attack_step)
	var windup: float = spec.windup
	var active: float = spec.active
	var recovery: float = spec.recovery
	var reach: float = spec.radius
	var effective_reach := reach + ACTOR_CLEARANCE
	var half_angle: float = deg_to_rad(spec.angle) * 0.5
	var start: float = direction.angle() - half_angle
	var arc: float = half_angle * 2.0
	var active_progress: float = clampf((elapsed - windup) / active, 0.0, 1.0)
	var fade: float = 1.0 if elapsed < windup + active else clampf(1.0 - (elapsed - windup - active) / recovery, 0.0, 1.0)
	var base := Color("49e6eb") if player.attack_step == 1 else Color("bda0ff") if player.attack_step == 2 else Color("e9a6fa") if player.attack_step == 3 else Color("ffe19a")
	attack_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	# Keep the swing in one plane at chest height. Sampling the ground height at
	# every vertex folded the old mesh over stairs and cliffs. The pale blade
	# still swings in air; the bright reach guide stops where damage is blocked.
	var first_reach := _attack_reach_at(origin, start, effective_reach)
	for i in range(32):
		var a0 := start + arc * float(i) / 32.0
		var a1 := start + arc * float(i + 1) / 32.0
		var second_reach := _attack_reach_at(origin, a1, effective_reach)
		var visible_reach := minf(first_reach, second_reach)
		first_reach = second_reach
		var tint := base
		tint.a = (0.075 if elapsed >= windup else 0.025) * fade
		if visible_reach > reach * 0.28:
			_attack_band(origin, a0, a1, reach * 0.28, visible_reach, tint, 70.0)
		var rim := base.lightened(0.55)
		rim.a = (0.88 if elapsed >= windup else 0.42) * fade
		if visible_reach > 8.0:
			_attack_band(origin, a0, a1, visible_reach - 5.0, visible_reach, rim, 72.0)
	# A moving broad blade gives the two starter slashes opposite directions.
	if elapsed >= windup and player.attack_step <= 2:
		var sweep_sign := 1.0 if player.attack_step != 2 else -1.0
		var head := start + arc * (active_progress if sweep_sign > 0.0 else 1.0 - active_progress)
		var heavy_second := player.attack_hitstop_scale > 0.0 and player.attack_step == 2
		var tail := head - sweep_sign * minf(0.82 if heavy_second else 0.64, arc * 0.45)
		var slash_color := base.lightened(0.48)
		slash_color.a = (1.0 if heavy_second else 0.93) * fade
		for i in range(10):
			var first := lerpf(tail, head, float(i) / 10.0)
			var second := lerpf(tail, head, float(i + 1) / 10.0)
			var blade_reach := minf(_attack_reach_at(origin, first, effective_reach), _attack_reach_at(origin, second, effective_reach))
			if blade_reach > 8.0:
				_attack_band(origin, first, second, minf(reach * (0.40 if heavy_second else 0.48), blade_reach * 0.38), blade_reach * 0.96, slash_color, 88.0)
		var edge_color := Color.WHITE
		edge_color.a = 0.78 * fade
		var edge_width := 0.085 if heavy_second else 0.065
		var edge_start := head - sweep_sign * edge_width
		var edge_end := head + sweep_sign * edge_width
		var edge_reach := minf(_attack_reach_at(origin, edge_start, effective_reach), _attack_reach_at(origin, edge_end, effective_reach))
		if edge_reach > 8.0:
			_attack_band(origin, edge_start, edge_end, minf(reach * 0.30, edge_reach * 0.38), edge_reach, edge_color, 90.0)
	elif elapsed >= windup and player.attack_step == 3:
		# A visible inward pull replaces the generic blade sweep.
		var pull_radius := reach * lerpf(0.88, 0.43, active_progress)
		var pull_color := Color(0.47, 0.91, 1.0, 0.90 * fade)
		for i in range(24):
			var a0 := start + arc * float(i) / 24.0
			var a1 := start + arc * float(i + 1) / 24.0
			var limit := minf(_attack_reach_at(origin, a0, effective_reach), _attack_reach_at(origin, a1, effective_reach))
			if limit > pull_radius:
				_attack_band(origin, a0, a1, maxf(8.0, pull_radius - 12.0), minf(limit, pull_radius), pull_color, 88.0)
	elif elapsed >= windup and player.attack_step == 4:
		# The finisher grows out from the player rather than sweeping sideways.
		var burst_radius := reach * active_progress
		var burst_color := Color(1.0, 0.91, 0.53, 0.95 * fade)
		for i in range(24):
			var a0 := start + arc * float(i) / 24.0
			var a1 := start + arc * float(i + 1) / 24.0
			var limit := minf(_attack_reach_at(origin, a0, effective_reach), _attack_reach_at(origin, a1, effective_reach))
			if limit > burst_radius:
				_attack_band(origin, a0, a1, maxf(8.0, burst_radius - 18.0), minf(limit, burst_radius), burst_color, 91.0)
	attack_mesh.surface_end()


func _draw_moving_slash(player_point: Vector2) -> void:
	moving_slash_mesh.clear_surfaces()
	if not moving_slash_practice or player.moving_slash_visual_time <= 0.0: return
	var origin := player.moving_slash_origin
	var tip: Vector2 = player_point if player.moving_slash_time > 0.0 else player.moving_slash_tip
	var axis := player.moving_slash_direction
	var side := axis.orthogonal()
	var radius := SandboxPlayer.MOVING_SLASH_RADIUS + player.moving_slash_radius_bonus + ACTOR_CLEARANCE
	var lift := maxf(terrain.height_at(origin), terrain.height_at(tip)) + 83.0
	var fade := clampf(player.moving_slash_visual_time / 0.09, 0.0, 1.0)
	var fill := Color(0.25, 0.90, 0.96, 0.12 * fade)
	var edge := Color(0.77, 1.0, 1.0, 0.49 * fade)
	moving_slash_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := maxi(1, ceili(origin.distance_to(tip) / 14.0))
	for i in count:
		var first := origin.lerp(tip, float(i) / float(count))
		var second := origin.lerp(tip, float(i + 1) / float(count))
		var left_a := minf(radius, _attack_reach_at(first, side.angle(), radius))
		var right_a := minf(radius, _attack_reach_at(first, (-side).angle(), radius))
		var left_b := minf(radius, _attack_reach_at(second, side.angle(), radius))
		var right_b := minf(radius, _attack_reach_at(second, (-side).angle(), radius))
		_moving_slash_quad(first + side * left_a, second + side * left_b, second - side * right_b, first - side * right_a, fill, lift)
		_moving_slash_quad(first + side * maxf(0.0, left_a - 4.0), second + side * maxf(0.0, left_b - 4.0), second + side * left_b, first + side * left_a, edge, lift + 2.0)
		_moving_slash_quad(first - side * maxf(0.0, right_a - 4.0), second - side * maxf(0.0, right_b - 4.0), second - side * right_b, first - side * right_a, edge, lift + 2.0)
	for cap in [origin, tip]:
		var start := axis.angle() + (PI * 0.5 if cap == origin else -PI * 0.5)
		for i in 12:
			var angle_a := start + PI * float(i) / 12.0
			var angle_b := start + PI * float(i + 1) / 12.0
			var reach_a := _attack_reach_at(cap, angle_a, radius)
			var reach_b := _attack_reach_at(cap, angle_b, radius)
			_moving_slash_triangle(cap, cap + Vector2.from_angle(angle_a) * reach_a, cap + Vector2.from_angle(angle_b) * reach_b, fill, lift)
			_moving_slash_quad(cap + Vector2.from_angle(angle_a) * maxf(0.0, reach_a - 4.0), cap + Vector2.from_angle(angle_b) * maxf(0.0, reach_b - 4.0), cap + Vector2.from_angle(angle_b) * reach_b, cap + Vector2.from_angle(angle_a) * reach_a, edge, lift + 2.0)
	if player.moving_slash_time > 0.0:
		var progress := clampf(player.moving_slash_elapsed / SandboxPlayer.MOVING_SLASH_DURATION, 0.0, 1.0)
		var head := axis.angle() + lerpf(-1.15, 1.15, progress)
		var blade := Color(0.92, 1.0, 1.0, 0.96 * fade)
		for i in 12:
			var a0 := head - 0.47 + 0.47 * float(i) / 12.0
			var a1 := head - 0.47 + 0.47 * float(i + 1) / 12.0
			var blade_reach := minf(_attack_reach_at(tip, a0, radius), _attack_reach_at(tip, a1, radius))
			if blade_reach > 28.0:
				_moving_slash_quad(tip + Vector2.from_angle(a0) * 27.0, tip + Vector2.from_angle(a1) * 27.0, tip + Vector2.from_angle(a1) * blade_reach, tip + Vector2.from_angle(a0) * blade_reach, blade, lift + 7.0)
	moving_slash_mesh.surface_end()


func _moving_slash_quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color, lift: float) -> void:
	_moving_slash_triangle(a, b, c, color, lift)
	_moving_slash_triangle(a, c, d, color, lift)


func _moving_slash_triangle(a: Vector2, b: Vector2, c: Vector2, color: Color, lift: float) -> void:
	for point in [a, b, c]:
		moving_slash_mesh.surface_set_color(color)
		moving_slash_mesh.surface_add_vertex(Vector3(point.x, lift, point.y) * Terrain.SCALE)

func _attack_reach(angle: float, limit: float) -> float:
	return _attack_reach_at(player.global_position, angle, limit)

func _attack_reach_at(from: Vector2, angle: float, limit: float) -> float:
	var to := from + Vector2.from_angle(angle) * limit
	var query := PhysicsRayQueryParameters2D.create(from, to, 4)
	query.hit_from_inside = true
	var hit := simulation.get_world_2d().direct_space_state.intersect_ray(query)
	return maxf(0.0, from.distance_to(hit.position) - 1.0) if not hit.is_empty() else limit

func _attack_band(origin: Vector2, a0: float, a1: float, inner: float, outer: float, color: Color, lift: float) -> void:
	var elevation := terrain.height_at(origin) + lift
	var p0 := origin + Vector2.from_angle(a0) * inner
	var p1 := origin + Vector2.from_angle(a1) * inner
	var p2 := origin + Vector2.from_angle(a1) * outer
	var p3 := origin + Vector2.from_angle(a0) * outer
	for point in [p0, p1, p2, p0, p2, p3]:
		attack_mesh.surface_set_color(color)
		attack_mesh.surface_add_vertex(Vector3(point.x, elevation, point.y) * Terrain.SCALE)

func _draw_enemy_warnings(fraction: float) -> void:
	warning_mesh.clear_surfaces()
	var showing := false
	for actor in actors:
		if is_instance_valid(actor) and actor is TrainingEnemy and actor.warning_time > 0.0 and (actor.role == TrainingEnemy.Role.BEAST or actor.role == TrainingEnemy.Role.LAMP):
			showing = true
			break
	if not get_tree().get_nodes_in_group("enemy_zones").is_empty(): showing = true
	if player.attack_step == 3 and not player.gathered_enemies.is_empty(): showing = true
	if growth != null and growth.seal != null and (growth.seal.telegraph > 0.0 or growth.seal.burst_time > 0.0): showing = true
	if not get_tree().get_nodes_in_group("wisp_chain_arcs").is_empty(): showing = true
	if not showing: return
	warning_vertex_count = 0
	warning_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for actor in actors:
		if not is_instance_valid(actor) or not actor is TrainingEnemy or actor.warning_time <= 0.0: continue
		if actor.role != TrainingEnemy.Role.BEAST and actor.role != TrainingEnemy.Role.LAMP: continue
		var source: Vector2 = _render_position(actor, fraction)
		var length := TrainingEnemy.BEAST_CHARGE_SPEED * TrainingEnemy.BEAST_CHARGE_DURATION if actor.role == TrainingEnemy.Role.BEAST else EnemyBolt.MAXIMUM_DISTANCE
		var limit := _attack_reach_at(source, actor.locked_direction.angle(), length)
		var color := Color(1.0, 0.30, 0.20, 0.92) if actor.role == TrainingEnemy.Role.BEAST else Color(1.0, 0.89, 0.42, 0.95)
		var outline := Color(0.38, 0.07, 0.06, 0.78) if actor.role == TrainingEnemy.Role.BEAST else Color(0.40, 0.18, 0.04, 0.82)
		var is_boss := actor is GateBoss
		var width: float = actor.collision_radius * 2.0 + player.collision_radius * 2.0 + actor.contact_margin * 2.0 if is_boss else 9.0 if actor.role == TrainingEnemy.Role.BEAST else 6.0
		if limit > ACTOR_CLEARANCE:
			for i in 8:
				var first: Vector2 = source + actor.locked_direction * lerpf(ACTOR_CLEARANCE, limit, float(i) / 8.0)
				var second: Vector2 = source + actor.locked_direction * lerpf(ACTOR_CLEARANCE, limit, float(i + 1) / 8.0)
				_warning_strip(first, second, width + 7.0, outline, 62.0, terrain.height_at(source))
				_warning_strip(first, second, width, Color(color.r, color.g, color.b, 0.32) if is_boss else color, 65.0, terrain.height_at(source))
				if is_boss: _warning_strip(first, second, 7.0, color, 68.0, terrain.height_at(source))
	for zone in get_tree().get_nodes_in_group("enemy_zones"):
		if not is_instance_valid(zone) or zone.is_queued_for_deletion(): continue
		var center: Vector2 = zone.global_position
		var color := Color(0.75, 1.0, 0.94, 0.98) if zone.warning_time <= 0.0 else Color(0.68, 1.0, 0.93, 0.88)
		for i in 48:
			var a0 := TAU * float(i) / 48.0
			var a1 := TAU * float(i + 1) / 48.0
			if _ring_segment_clear(center, a0, a1, EnemyZone.RADIUS):
				_warning_arc(center, a0, a1, EnemyZone.RADIUS, 10.0, Color(0.04, 0.36, 0.38, 0.85), 10.0, terrain.height_at(center))
				_warning_arc(center, a0, a1, EnemyZone.RADIUS, 5.0, color, 13.0, terrain.height_at(center))
	if growth != null and growth.seal != null and (growth.seal.telegraph > 0.0 or growth.seal.burst_time > 0.0):
		var seal := growth.seal
		var center: Vector2 = seal.global_position
		var bursting := seal.burst_time > 0.0
		var fade := seal.burst_time / 0.19 if bursting else 1.0 - seal.telegraph / 0.45
		var color := Color(0.93, 0.74, 1.0, 0.95 if bursting else 0.48 + fade * 0.42)
		for i in 48:
			var a0 := TAU * float(i) / 48.0
			var a1 := TAU * float(i + 1) / 48.0
			if _ring_segment_clear(center, a0, a1, seal.radius):
				_warning_arc(center, a0, a1, seal.radius, 9.0 if bursting else 6.0, color, 60.0, terrain.height_at(center))
			if bursting and _ring_segment_clear(center, a0, a1, seal.radius * 0.55):
				_warning_arc(center, a0, a1, seal.radius * 0.55, 19.0, Color(0.7, 0.38, 1.0, 0.23 * fade), 58.0, terrain.height_at(center))
	for arc in get_tree().get_nodes_in_group("wisp_chain_arcs"):
		if not is_instance_valid(arc) or arc.is_queued_for_deletion(): continue
		var strength: float = 1.0 - arc.age / arc.duration
		var start: Vector2 = arc.global_position
		var finish: Vector2 = start + arc.end_point
		var middle: Vector2 = start.lerp(finish, 0.5) + arc.end_point.orthogonal().normalized() * 12.0 * strength
		var chain_height := maxf(terrain.height_at(start), terrain.height_at(finish))
		_warning_strip(start, middle, 4.0, Color(0.50, 0.93, 1.0, strength), 65.0, chain_height)
		_warning_strip(middle, finish, 4.0, Color(0.50, 0.93, 1.0, strength), 65.0, chain_height)
	if player.attack_step == 3:
		for enemy in player.gathered_enemies:
			if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or not enemy.gathering: continue
			var from: Vector3 = terrain.world_point(_render_position(enemy, fraction), 82.0)
			var to: Vector3 = terrain.world_point(enemy.gather_target, 82.0)
			var fade: float = 0.5 + 0.5 * (1.0 - enemy.gather_elapsed / TrainingEnemy.GATHER_DURATION)
			var origin: Vector3 = terrain.world_point(enemy.gather_origin, 79.0)
			_warning_3d_strip(origin, to, 0.075, Color(0.25, 0.69, 1.0, 0.62 * fade))
			_warning_3d_strip(from, to, 0.13, Color(0.22, 0.75, 1.0, 0.42 * fade))
			_warning_3d_strip(from, to, 0.052, Color(0.94, 0.99, 1.0, 0.98 * fade))
			_warning_3d_ring(to, 0.27, 0.075, Color(0.70, 0.93, 1.0, 0.95 * fade))
	if warning_vertex_count == 0:
		# A warning can be fully blocked by a wall; ImmediateMesh still needs a
		# completed surface after surface_begin, even when nothing is visible.
		for i in 3:
			warning_mesh.surface_set_color(Color.TRANSPARENT)
			warning_mesh.surface_add_vertex(Vector3.ZERO)
	warning_mesh.surface_end()

func _ring_segment_clear(center: Vector2, start_angle: float, end_angle: float, radius: float) -> bool:
	for angle in [start_angle, (start_angle + end_angle) * 0.5, end_angle]:
		if not clear_attack(center, center + Vector2.from_angle(angle) * radius):
			return false
	return true

func _warning_3d_strip(first: Vector3, second: Vector3, width: float, color: Color) -> void:
	var direction := second - first
	if direction.length_squared() < 0.0001: return
	var side := Vector3(-direction.z, 0.0, direction.x).normalized() * width * 0.5
	for point in [first - side, first + side, second + side, first - side, second + side, second - side]:
		warning_mesh.surface_set_color(color)
		warning_mesh.surface_add_vertex(point)
		warning_vertex_count += 1

func _warning_3d_ring(center: Vector3, radius: float, width: float, color: Color) -> void:
	for i in 24:
		var a0 := TAU * float(i) / 24.0
		var a1 := TAU * float(i + 1) / 24.0
		var inner0 := center + Vector3(cos(a0), 0.0, sin(a0)) * (radius - width)
		var inner1 := center + Vector3(cos(a1), 0.0, sin(a1)) * (radius - width)
		var outer0 := center + Vector3(cos(a0), 0.0, sin(a0)) * radius
		var outer1 := center + Vector3(cos(a1), 0.0, sin(a1)) * radius
		for point in [inner0, inner1, outer1, inner0, outer1, outer0]:
			warning_mesh.surface_set_color(color)
			warning_mesh.surface_add_vertex(point)
			warning_vertex_count += 1

func _warning_strip(first: Vector2, second: Vector2, width: float, color: Color, lift: float = 9.0, ground_height: float = -10000.0) -> void:
	var side := (second - first).normalized().orthogonal() * width * 0.5
	_warning_quad([first - side, first + side, second + side, second - side], color, lift, ground_height)

func _warning_arc(center: Vector2, a0: float, a1: float, radius: float, width: float, color: Color, lift: float = 9.0, ground_height: float = -10000.0) -> void:
	_warning_quad([
		center + Vector2.from_angle(a0) * (radius - width),
		center + Vector2.from_angle(a1) * (radius - width),
		center + Vector2.from_angle(a1) * radius,
		center + Vector2.from_angle(a0) * radius
	], color, lift, ground_height)

func _warning_quad(points: Array, color: Color, lift: float = 9.0, ground_height: float = -10000.0) -> void:
	for index in [0, 1, 2, 0, 2, 3]:
		warning_mesh.surface_set_color(color)
		var point: Vector2 = points[index]
		warning_mesh.surface_add_vertex(terrain.world_point(point, lift) if ground_height <= -9999.0 else Vector3(point.x, ground_height + lift, point.y) * Terrain.SCALE)
		warning_vertex_count += 1

func _flash(point: Vector2, color: Color, radius: float = 0.22) -> void:
	var flash := _sphere(radius, color)
	add_child(flash)
	flash.position = terrain.world_point(point, 45)
	var tween := create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE * 0.05, 0.18)
	tween.tween_callback(flash.queue_free)

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)
	var panel := ColorRect.new()
	panel.position = Vector2(16, 16)
	panel.size = Vector2(445, 172)
	panel.color = Color(0.05, 0.12, 0.14, 0.88)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(panel)
	hud = Label.new()
	hud.position = Vector2(28, 25)
	hud.add_theme_font_size_override("font_size", 20)
	canvas.add_child(hud)
	minimap = MinimapScript.new()
	minimap.position = Vector2(1022, 74)
	minimap.size = Vector2(242, 213)
	minimap.setup(self)
	canvas.add_child(minimap)
	var help := Label.new()
	help.text = "WASD 이동   J / 클릭 평타   Q 이동 베기   Space 대시   Tab 전체 보기   N 적 재배치   R 재시작   Esc 일시정지" if show_practice_controls and moving_slash_practice else "WASD 이동   J / 클릭 평타   Space 대시   Tab 전체 보기   N 적 재배치   R 재시작   Esc 일시정지" if show_practice_controls else "WASD 이동   J / 클릭 평타   Q 이동 베기   Space 대시   Tab 전체 보기   G 귀환   Esc 일시정지"
	help.position = Vector2(20, 681)
	help.add_theme_font_size_override("font_size", 17)
	help.add_theme_color_override("font_shadow_color", Color.BLACK)
	help.add_theme_constant_override("shadow_offset_x", 1)
	help.add_theme_constant_override("shadow_offset_y", 1)
	canvas.add_child(help)
	var roles := Label.new()
	roles.text = "적: 회색 추격 · 빨강 돌진 · 금빛 사격 · 청록 장판 · 보라 강화"
	roles.position = Vector2(20, 643)
	roles.add_theme_font_size_override("font_size", 17)
	roles.add_theme_color_override("font_shadow_color", Color.BLACK)
	roles.add_theme_constant_override("shadow_offset_x", 1)
	roles.add_theme_constant_override("shadow_offset_y", 1)
	canvas.add_child(roles)
	if moving_slash_practice:
		moving_slash_status = Label.new()
		moving_slash_status.position = Vector2(20, 611)
		moving_slash_status.add_theme_font_size_override("font_size", 18)
		moving_slash_status.add_theme_color_override("font_shadow_color", Color.BLACK)
		moving_slash_status.add_theme_constant_override("shadow_offset_x", 1)
		moving_slash_status.add_theme_constant_override("shadow_offset_y", 1)
		canvas.add_child(moving_slash_status)
	var row := HBoxContainer.new()
	row.position = Vector2(490 if landmark_points.size() > 5 else 590, 20)
	canvas.add_child(row)
	for title in landmark_points if show_practice_controls else []:
		var button := Button.new()
		button.text = title
		button.custom_minimum_size = Vector2(125, 42)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func(): teleport(landmark_points[title]))
		row.add_child(button)
	pause_backdrop = ColorRect.new()
	pause_backdrop.position = Vector2(450, 303)
	pause_backdrop.size = Vector2(380, 66)
	pause_backdrop.color = Color(0.05, 0.12, 0.14, 0.9)
	pause_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_backdrop.hide()
	canvas.add_child(pause_backdrop)
	pause_label = Label.new()
	pause_label.text = "일시정지 · Esc로 계속"
	pause_label.position = Vector2(480, 320)
	pause_label.add_theme_font_size_override("font_size", 28)
	pause_label.hide()
	canvas.add_child(pause_label)

func teleport(point: Vector2) -> void:
	player.position = point
	actor_motion[player] = [point, point]
	player.velocity = Vector2.ZERO
	player.dash_time = 0
	player.moving_slash_time = 0.0
	player.moving_slash_visual_time = 0.0
	player.moving_slash_requested = false
	player.hurt_recoil = Vector2.ZERO
	player.reset_physics_interpolation()
	for companion in wisp_visuals:
		var wisp_point: Vector2 = point + companion.formation_offset()
		companion.position = wisp_point
		companion.reset_physics_interpolation()
		wisp_motion[companion] = [wisp_point, wisp_point]
		wisp_visuals[companion].position = terrain.world_point(wisp_point, 80)
		wisp_visuals[companion].reset_physics_interpolation()
	actors[player].position = terrain.world_point(point)
	actors[player].reset_physics_interpolation()
	camera.position = terrain.world_point(point, 35) + camera_offset
	camera.reset_physics_interpolation()
	_update_hud()

func _set_paused(value: bool) -> void:
	paused = value
	get_tree().paused = value
	if pause_label != null: pause_label.visible = value
	if pause_backdrop != null: pause_backdrop.visible = value

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if growth != null and growth.choosing:
			if event.keycode >= KEY_1 and event.keycode <= KEY_3:
				growth.choose_index(event.keycode - KEY_1)
			return
		if event.keycode == KEY_TAB:
			overview = not overview
			camera.size = overview_camera_size if overview else combat_camera_size
		elif event.keycode == KEY_N and show_practice_controls and not paused:
			spawn_enemies()
		elif event.keycode == KEY_R:
			_set_paused(false)
			get_tree().reload_current_scene()
		elif event.keycode == KEY_ESCAPE:
			_set_paused(not paused)
