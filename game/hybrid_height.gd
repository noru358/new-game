extends Node3D

const Terrain = preload("res://game/hybrid_terrain.gd")
const PlayerScene = preload("res://game/player.tscn")
const EnemyScene = preload("res://game/enemy.tscn")
const ActorTexture = preload("res://game/hybrid_actor.svg")
const COMBAT_CAMERA_SIZE := 10.8
const OVERVIEW_CAMERA_SIZE := 30.0
var terrain := Terrain.new()
var simulation := Node2D.new()
var player: SandboxPlayer
var wisp: WispCompanion
var navigation := ArenaNavigation.new()
var camera := Camera3D.new()
var actors: Dictionary = {}
var shots: Dictionary = {}
var wisp_visual: MeshInstance3D
var attack_visual := MeshInstance3D.new()
var attack_mesh := ImmediateMesh.new()
var attack_ray_limits: Dictionary = {}
var attack_ray_reach := 0.0
var hud: Label
var pause_label: Label
var pause_backdrop: ColorRect
var overview := false
var kills := 0
var paused := false
var terrain_mesh: MeshInstance3D

func _ready() -> void:
	get_window().title = "Loop Conquest — Hybrid Height v02"
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
		block.setup(area, false)
		simulation.add_child(block)
		obstacles.append(block)
	navigation.setup(obstacles, Terrain.SIZE)
	player = PlayerScene.instantiate()
	player.get_node("Camera2D").enabled = false
	player.position = Vector2(930, 1780)
	player.arena_bounds = Rect2(Vector2.ZERO, Terrain.SIZE)
	player.collision_mask = 4
	player.input_rotation = -PI / 4.0
	player.move_speed_multiplier = 1.12
	player.dash_distance_multiplier = 1.16
	player.basic_speed_bonus = 0.18
	player.attack_active_multiplier = 1.6
	player.attack_recovery_multiplier = 0.78
	player.attack_path_filter = clear_attack
	simulation.add_child(player)
	player.set_dash_upgrade(2)
	actors[player] = _actor_visual(Color.WHITE)
	player.attack_landed.connect(func(point: Vector2, _direction: Vector2, _step: int, _finisher: bool): _flash(point, Color("ffd486")))
	wisp = WispCompanion.new()
	wisp.player = player
	wisp.navigation = navigation
	wisp.target_visibility_filter = _on_screen
	wisp.follow_position_filter = _constrain_wisp
	simulation.add_child(wisp)
	wisp_visual = _sphere(0.13, Color("49dce8"))
	add_child(wisp_visual)
	wisp_visual.position = terrain.world_point(wisp.global_position, 80)
	wisp_visual.reset_physics_interpolation()
	wisp.enemy_hit.connect(func(enemy: TrainingEnemy): _flash(enemy.global_position, Color("66efff")))
	attack_visual.mesh = attack_mesh
	var attack_material := _material(Color.WHITE, true)
	attack_material.vertex_color_use_as_albedo = true
	attack_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	attack_visual.material_override = attack_material
	add_child(attack_visual)
	spawn_enemies()
	_build_ui()
	camera.position = terrain.world_point(player.position) + Vector3(14, 11.431, 14)
	camera.look_at(terrain.world_point(player.position), Vector3.UP)
	camera.reset_physics_interpolation()
	get_window().focus_exited.connect(func(): _set_paused(true))
	print("Hybrid height v02 ready: 2D simulation, shared terrain data, orthographic 3D presentation")

func _register_inputs() -> void:
	var keys := {"move_left": KEY_A, "move_right": KEY_D, "move_up": KEY_W, "move_down": KEY_S, "attack": KEY_J, "dash": KEY_SPACE}
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

func _build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_top(st, Rect2(Vector2.ZERO, Terrain.SIZE), func(_p): return 0.0, Color("93afa1"))
	for plateau in terrain.plateaus:
		var elevation := func(_p): return plateau.height
		_top(st, plateau.area, elevation, Color("d6cfb1") if plateau.height == 160 else Color("e7ddbd"))
		_sides(st, plateau.area, elevation, plateau.base, Color("798e80"), plateau.openings)
	for ramp in terrain.ramps:
		var elevation := func(p): return terrain.ramp_height(ramp, p)
		var is_stone_path: bool = ramp.get("kind", "") == "stone_path"
		_top(st, ramp.area, elevation, Color("a6aaa0") if is_stone_path else Color("c9bb91"))
		_sides(st, ramp.area, elevation, minf(ramp.from, ramp.to), Color("677d78") if is_stone_path else Color("8c8e77"), {}, ["north", "south"] if ramp.axis == 1 else ["west", "east"])
		# Thin transverse bands follow the inclined surface; they are not flat diamonds.
		var area: Rect2 = ramp.area
		for i in range(1, 9 if is_stone_path else 10):
			var band := area
			band.position[ramp.axis] += area.size[ramp.axis] * float(i) / (9.0 if is_stone_path else 10.0)
			band.size[ramp.axis] = 5 if is_stone_path else 3
			_top(st, band, func(p): return terrain.ramp_height(ramp, p) + 0.5, Color("667e79") if is_stone_path else Color("9a957f"))
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
	camera.size = COMBAT_CAMERA_SIZE
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

func spawn_enemies() -> void:
	for actor in actors.keys():
		if actor != player:
			if is_instance_valid(actor): actor.queue_free()
			actors[actor].queue_free()
			actors.erase(actor)
	for point in [Vector2(480, 1660), Vector2(720, 680), Vector2(1430, 1000), Vector2(2200, 1170)]:
		var enemy: TrainingEnemy = EnemyScene.instantiate()
		enemy.position = point
		enemy.target = player
		enemy.arena_bounds = Rect2(Vector2.ZERO, Terrain.SIZE)
		enemy.collision_mask = 6
		enemy.navigation = navigation
		simulation.add_child(enemy)
		actors[enemy] = _actor_visual(Color("e9a09a"))
		enemy.defeated.connect(func(): kills += 1)

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

func _physics_process(delta: float) -> void:
	if paused or not is_instance_valid(player): return
	for actor in actors.keys():
		if not is_instance_valid(actor):
			actors[actor].queue_free()
			actors.erase(actor)
			continue
		var visual: Node3D = actors[actor]
		visual.position = terrain.world_point(actor.global_position)
		if actor == player:
			visual.get_node("Body").flip_h = player.facing.x - player.facing.y < -0.1
		var p: Vector2 = actor.global_position
		var dx: float = (terrain.height_at(p + Vector2(1, 0)) - terrain.height_at(p - Vector2(1, 0))) * 0.5
		var dz: float = (terrain.height_at(p + Vector2(0, 1)) - terrain.height_at(p - Vector2(0, 1))) * 0.5
		visual.get_node("Shadow").quaternion = Quaternion(Vector3.UP, Vector3(-dx, 1, -dz).normalized())
	wisp_visual.position = wisp_visual.position.lerp(terrain.world_point(wisp.global_position, 80), minf(1.0, 13.0 * delta))
	for shot in get_tree().get_nodes_in_group("wisp_projectiles"):
		if not shots.has(shot):
			var visual := _sphere(0.075, Color("96f4ff"))
			add_child(visual)
			shots[shot] = visual
		shots[shot].position = terrain.world_point(shot.global_position, 55)
	for shot in shots.keys():
		if not is_instance_valid(shot):
			shots[shot].queue_free()
			shots.erase(shot)
	var focus := terrain.world_point(player.global_position, 35)
	if overview: focus = Vector3(12, 0.8, 10)
	camera.position = camera.position.lerp(focus + Vector3(14, 11.431, 14), 1.0 - exp(-8.0 * delta))
	_draw_attack()
	_update_hud()

func _update_hud() -> void:
	if hud == null: return
	hud.text = "높이 비교  ·  %s\nHP %d   대시 %d/%d   처치 %d\n%s" % [terrain.surface_name(player.position), player.health, player.dash_charges, player.dash_max_charges, kills, "쓰러졌습니다 · R로 다시 시작" if player.health <= 0 else ""]

func _draw_attack() -> void:
	attack_mesh.clear_surfaces()
	if player.attack_step == 0: return
	var spec: Dictionary = player._attack_spec(player.attack_step)
	var elapsed: float = player.attack_elapsed
	var windup: float = spec.windup
	var active: float = spec.active
	var recovery: float = spec.recovery
	var reach: float = spec.radius
	attack_ray_reach = reach + TrainingEnemy.RADIUS + 8.0
	attack_ray_limits.clear()
	var half_angle: float = deg_to_rad(spec.angle) * 0.5
	var start: float = player.attack_direction.angle() - half_angle
	var arc: float = half_angle * 2.0
	var active_progress: float = clampf((elapsed - windup) / active, 0.0, 1.0)
	var fade: float = 1.0 if elapsed < windup + active else clampf(1.0 - (elapsed - windup - active) / recovery, 0.0, 1.0)
	var base := Color("49e6eb") if player.attack_step == 1 else Color("bda0ff") if player.attack_step == 2 else Color("e9a6fa") if player.attack_step == 3 else Color("ffe19a")
	attack_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	# The translucent footprint is the same fan used by the hit test. The pale
	# outer fringe represents the enemy's 17 px body radius at the boundary.
	for i in range(32):
		var a0 := start + arc * float(i) / 32.0
		var a1 := start + arc * float(i + 1) / 32.0
		for band in range(5):
			var inner := reach * float(band) / 5.0
			var outer := reach * float(band + 1) / 5.0
			var tint := base
			tint.a = (0.19 if elapsed >= windup else 0.055) * fade
			_attack_band(a0, a1, inner, outer, tint)
		var fringe := base
		fringe.a = 0.09 * fade
		_attack_band(a0, a1, reach, reach + TrainingEnemy.RADIUS, fringe)
		var rim := base.lightened(0.55)
		rim.a = (0.75 if elapsed >= windup else 0.4) * fade
		_attack_band(a0, a1, reach + TrainingEnemy.RADIUS - 3.0, reach + TrainingEnemy.RADIUS + 2.0, rim)
	# A moving broad blade gives the two starter slashes opposite directions.
	if elapsed >= windup:
		var direction := 1.0 if player.attack_step != 2 else -1.0
		var head := start + arc * (active_progress if direction > 0.0 else 1.0 - active_progress)
		var tail := head - direction * minf(0.64, arc * 0.45)
		var slash_color := base.lightened(0.48)
		slash_color.a = 0.93 * fade
		for i in range(10):
			var first := lerpf(tail, head, float(i) / 10.0)
			var second := lerpf(tail, head, float(i + 1) / 10.0)
			_attack_band(first, second, reach * 0.55, reach * 1.02, slash_color, 60.0)
		var edge_color := Color.WHITE
		edge_color.a = 0.56 * fade
		_attack_band(head - direction * 0.055, head + direction * 0.055, reach * 0.32, reach * 1.06, edge_color, 67.0)
	attack_mesh.surface_end()

func _attack_band(a0: float, a1: float, inner: float, outer: float, color: Color, lift: float = 22.0) -> void:
	var visible_distance := minf(_attack_visible_distance(a0), _attack_visible_distance(a1))
	if visible_distance <= inner:
		return
	outer = minf(outer, visible_distance)
	var origin := player.global_position
	var p0 := origin + Vector2.from_angle(a0) * inner
	var p1 := origin + Vector2.from_angle(a1) * inner
	var p2 := origin + Vector2.from_angle(a1) * outer
	var p3 := origin + Vector2.from_angle(a0) * outer
	for point in [p0, p1, p2, p0, p2, p3]:
		attack_mesh.surface_set_color(color)
		attack_mesh.surface_add_vertex(terrain.world_point(point, lift))

func _attack_visible_distance(angle: float) -> float:
	if attack_ray_limits.has(angle):
		return attack_ray_limits[angle]
	var origin := player.global_position
	var query := PhysicsRayQueryParameters2D.create(origin, origin + Vector2.from_angle(angle) * attack_ray_reach, 4)
	query.hit_from_inside = true
	var hit := simulation.get_world_2d().direct_space_state.intersect_ray(query)
	var result := attack_ray_reach if hit.is_empty() else maxf(0.0, origin.distance_to(hit.position) - 2.0)
	attack_ray_limits[angle] = result
	return result

func _flash(point: Vector2, color: Color) -> void:
	var flash := _sphere(0.22, color)
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
	panel.size = Vector2(300, 104)
	panel.color = Color(0.05, 0.12, 0.14, 0.88)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(panel)
	hud = Label.new()
	hud.position = Vector2(28, 25)
	hud.add_theme_font_size_override("font_size", 20)
	canvas.add_child(hud)
	var help := Label.new()
	help.text = "WASD 이동   J / 클릭 평타   Space 대시   Tab 전체 보기   N 적 재배치   R 재시작   Esc 일시정지"
	help.position = Vector2(20, 681)
	help.add_theme_font_size_override("font_size", 17)
	help.add_theme_color_override("font_shadow_color", Color.BLACK)
	help.add_theme_constant_override("shadow_offset_x", 1)
	help.add_theme_constant_override("shadow_offset_y", 1)
	canvas.add_child(help)
	var places := {"남쪽 입구": Vector2(930, 1780), "바위길": Vector2(1290, 1840), "북쪽 입구": Vector2(930, 220), "측면 입구": Vector2(2080, 1180), "테라스": Vector2(1390, 1000)}
	var row := HBoxContainer.new()
	row.position = Vector2(590, 20)
	canvas.add_child(row)
	for title in places:
		var button := Button.new()
		button.text = title
		button.custom_minimum_size = Vector2(125, 42)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func(): teleport(places[title]))
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
	player.velocity = Vector2.ZERO
	player.dash_time = 0
	player.hurt_recoil = Vector2.ZERO
	player.reset_physics_interpolation()
	wisp.position = point
	wisp.reset_physics_interpolation()
	wisp_visual.position = terrain.world_point(point, 80)
	wisp_visual.reset_physics_interpolation()
	actors[player].position = terrain.world_point(point)
	actors[player].reset_physics_interpolation()
	camera.position = terrain.world_point(point, 35) + Vector3(14, 11.431, 14)
	camera.reset_physics_interpolation()
	_update_hud()

func _set_paused(value: bool) -> void:
	paused = value
	get_tree().paused = value
	if pause_label != null: pause_label.visible = value
	if pause_backdrop != null: pause_backdrop.visible = value

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			overview = not overview
			camera.size = OVERVIEW_CAMERA_SIZE if overview else COMBAT_CAMERA_SIZE
		elif event.keycode == KEY_N and not paused:
			spawn_enemies()
		elif event.keycode == KEY_R:
			_set_paused(false)
			get_tree().reload_current_scene()
		elif event.keycode == KEY_ESCAPE:
			_set_paused(not paused)
