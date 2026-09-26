extends Node3D

const Terrain = preload("res://game/hybrid_terrain.gd")
const PlayerScene = preload("res://game/player.tscn")
const EnemyScene = preload("res://game/enemy.tscn")
const ActorTexture = preload("res://game/hybrid_actor.svg")
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
var hud: Label
var pause_label: Label
var pause_backdrop: ColorRect
var overview := false
var kills := 0
var paused := false
var terrain_mesh: MeshInstance3D

func _ready() -> void:
	get_window().title = "Loop Conquest — Hybrid Height v01"
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
	wisp.enemy_hit.connect(func(enemy: TrainingEnemy): _flash(enemy.global_position, Color("66efff")))
	attack_visual.mesh = attack_mesh
	attack_visual.material_override = _material(Color("ffd486"), true)
	add_child(attack_visual)
	spawn_enemies()
	_build_ui()
	camera.position = terrain.world_point(player.position) + Vector3(14, 11.431, 14)
	camera.look_at(terrain.world_point(player.position), Vector3.UP)
	camera.reset_physics_interpolation()
	get_window().focus_exited.connect(func(): _set_paused(true))
	print("Hybrid height v01 ready: 2D simulation, shared terrain data, orthographic 3D presentation")

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

func _sides(st: SurfaceTool, area: Rect2, elevation: Callable, bottom: float, color: Color) -> void:
	var corners := [area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)]
	for i in range(4):
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		_quad(st, [Vector3(a.x, bottom, a.y), Vector3(b.x, bottom, b.y), Vector3(b.x, elevation.call(b), b.y), Vector3(a.x, elevation.call(a), a.y)], color)

func _build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_top(st, Rect2(Vector2.ZERO, Terrain.SIZE), func(_p): return 0.0, Color("93afa1"))
	for plateau in terrain.plateaus:
		var elevation := func(_p): return plateau.height
		_top(st, plateau.area, elevation, Color("d6cfb1") if plateau.height == 160 else Color("e7ddbd"))
		_sides(st, plateau.area, elevation, plateau.base, Color("798e80"))
	for ramp in terrain.ramps:
		var elevation := func(p): return terrain.ramp_height(ramp, p)
		_top(st, ramp.area, elevation, Color("c9bb91"))
		_sides(st, ramp.area, elevation, minf(ramp.from, ramp.to), Color("8c8e77"))
		# Thin transverse bands follow the inclined surface; they are not flat diamonds.
		var area: Rect2 = ramp.area
		for i in range(1, 10):
			var band := area
			band.position[ramp.axis] += area.size[ramp.axis] * float(i) / 10.0
			band.size[ramp.axis] = 3
			_top(st, band, func(p): return terrain.ramp_height(ramp, p) + 0.5, Color("9a957f"))
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
	camera.size = 14.4
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
	return point if clear_attack(player.global_position, point) else player.global_position

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
	wisp_visual.position = terrain.world_point(wisp.global_position, 80)
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
	var vertices := PackedVector3Array()
	for i in range(24):
		var angle: float = player.attack_direction.angle() - deg_to_rad(spec.angle) * 0.5 + deg_to_rad(spec.angle) * float(i) / 24.0
		var next: float = angle + deg_to_rad(spec.angle) / 24.0
		var a: Vector2 = player.position + Vector2.from_angle(angle) * spec.radius
		var b: Vector2 = player.position + Vector2.from_angle(next) * spec.radius
		if clear_attack(player.position, a) and clear_attack(player.position, b):
			vertices.append(terrain.world_point(a, 15))
			vertices.append(terrain.world_point(b, 15))
	if vertices.is_empty(): return
	attack_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for vertex in vertices:
		attack_mesh.surface_add_vertex(vertex)
	attack_mesh.surface_end()

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
	var places := {"남쪽 입구": Vector2(930, 1780), "북쪽 입구": Vector2(930, 220), "측면 입구": Vector2(2080, 1180), "테라스": Vector2(1390, 1000)}
	var row := HBoxContainer.new()
	row.position = Vector2(710, 20)
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
			camera.size = 30.0 if overview else 14.4
		elif event.keycode == KEY_N and not paused:
			spawn_enemies()
		elif event.keycode == KEY_R:
			_set_paused(false)
			get_tree().reload_current_scene()
		elif event.keycode == KEY_ESCAPE:
			_set_paused(not paused)
