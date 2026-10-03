extends "res://game/hybrid_region.gd"

const WornStone = preload("res://game/jungle_worn_stone_visuals.gd")
const RouteTerrain = preload("res://game/jungle_route_terrain.gd")
const RouteEnvironment = preload("res://game/jungle_route_environment.gd")
const PassTerrain = preload("res://game/jungle_pass_terrain.gd")
const GATE_BOSS_POINTS := [Vector2(4700, 800), Vector2(4700, 1200), Vector2(4700, 1650)]
var canopy_visuals: Dictionary = {}
var gate_route_encounter := ""
var gate_route_crest_triggered := false
var main_decor: Array[Node3D] = []


func region_layout():
	return preload("res://game/jungle_grotto_layout.gd")


func _create_region_section() -> Node:
	return preload("res://game/jungle_section.gd").new()


func _init() -> void:
	super._init()
	terrain = PassTerrain.new() if OS.get_cmdline_user_args().has("--jungle-route-baseline") else RouteTerrain.new()
	start_point = Vector2(430, 1210)
	enemy_points = [
		Vector2(500, 1120), Vector2(970, 820), Vector2(1160, 1750),
		Vector2(1860, 1120), Vector2(2530, 830), Vector2(3300, 1210),
		Vector2(4210, 1100), Vector2(5080, 1150)
	]
	landmark_points = {
		"정글 입구": Vector2(430, 1210),
		"서쪽 상승로": Vector2(1410, 1180),
		"북쪽 덩굴길": Vector2(1640, 265),
		"정글 능선": Vector2(2640, 1120),
		"석교 직행로": Vector2(2850, 1140),
		"강변 연결 비탈": Vector2(2890, 1480),
		"강변 우회로": Vector2(3010, 2050),
		"끊어진 바위 다리": Vector2(3410, 1790),
		"남쪽 우회로": Vector2(2180, 2120),
		"관문 상단": Vector2(4520, 1160),
	}
	region_id = RunProfile.JUNGLE_REGION
	boss_scene = preload("res://game/jungle_warden.tscn")
	boss_name = "관문 수호자"
	first_clear_notice = "관문 통과 · 새 3·4타 장비 선택 가능"
	scene_title = "Loop Conquest — 정글 절벽 관문"
	scene_hud_title = "정글 절벽 관문"
	combat_camera_size = 9.0
	overview_camera_size = 43.0
	camera_offset = Vector3(14, 13.864, 14)
	ground_color = Color("536e5e")
	plateau_color = Color("888d6c")
	cliff_color = Color("3d5953")
	ramp_color = Color("ada27b")


func _ready() -> void:
	super._ready()
	var before := get_children()
	_build_gate_silhouette()
	_build_jungle_silhouette()
	_build_gate_approaches()
	_build_river_route()
	_build_route_scenery()
	if terrain is RouteTerrain: add_child(RouteEnvironment.build(self))
	for child in get_children():
		if child is Node3D and not before.has(child): main_decor.append(child)


func set_main_decor_visible(value: bool) -> void:
	for visual in main_decor: visual.visible = value


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if run_ended or practice_mode or paused or growth.choosing or get_tree().paused or _active_enemy_count() > MAX_ENEMIES - 2: return
	if temple_section != null and (temple_section.in_garden or temple_section.boss_active): return
	var point: Vector2 = player.global_position
	if gate_route_encounter.is_empty():
		for route in terrain.gate_routes:
			if terrain.gate_routes[route].entry.has_point(point):
				gate_route_encounter = route
				_spawn_route_sentries(route, false)
				return
	elif not gate_route_crest_triggered:
		for route in terrain.gate_routes:
			if terrain.gate_routes[route].crest.has_point(point):
				gate_route_crest_triggered = true
				_spawn_route_sentries(route, true)
				return


func _spawn_route_sentries(route: String, at_crest: bool) -> void:
	var sentries: Array = []
	if route == "stairs":
		sentries = [[Vector2(3970, 1010), TrainingEnemy.Role.BEAST], [Vector2(4020, 1330), TrainingEnemy.Role.LAMP]] if at_crest else [[Vector2(2890, 1100), TrainingEnemy.Role.BEAST], [Vector2(2960, 1180), TrainingEnemy.Role.LAMP]]
	else:
		sentries = [[Vector2(4450, 1760), TrainingEnemy.Role.ZONE], [Vector2(4620, 1840), TrainingEnemy.Role.BEAST]] if at_crest else [[Vector2(2820, 1930), TrainingEnemy.Role.ZONE], [Vector2(2960, 2100), TrainingEnemy.Role.FRAGMENT]]
	for entry in sentries:
		var spawn_point: Vector2 = entry[0]
		if navigation.is_open(spawn_point, ACTOR_CLEARANCE + 6.0) and navigation.find_path(spawn_point, player.global_position).size() >= 2:
			_schedule_spawn(spawn_point, entry[1], false)


func _choose_spawn_point(for_boss: bool) -> Vector2:
	if not for_boss: return super._choose_spawn_point(false)
	var chosen := Vector2.INF
	var farthest := 0.0
	for candidate in GATE_BOSS_POINTS:
		var point: Vector2 = candidate
		if not navigation.is_open(point, 48.0): continue
		var distance: float = point.distance_to(player.global_position)
		if distance > farthest and navigation.find_path(point, player.global_position).size() >= 2:
			chosen = point
			farthest = distance
	return chosen


func _animate_boss_figure() -> void:
	super._animate_boss_figure()
	if not is_instance_valid(boss) or not boss is JungleWarden or not actors.has(boss): return
	var figure: Node3D = actors[boss].get_node("BossFigure")
	(figure.get_node("BossCore").material_override as StandardMaterial3D).albedo_color = Color.WHITE if boss.hit_flash > 0.0 else Color("d6bc73") if boss.phase == 2 else Color("707d72")
	figure.rotation.z = 0.22 * (1.0 - boss.sweep_warning / JungleWarden.SWEEP_WARNING) if boss.sweep_warning > 0.0 else -0.34 if boss.sweep_burst_time > 0.0 else 0.0
	figure.rotation.x = 0.25 if boss.recovery_time > 0.0 else -0.18 if boss.gust_warning > 0.0 else 0.22 if boss.gust_burst_time > 0.0 else 0.0
	if boss.recovery_time > 0.0 and boss.hit_flash <= 0.0: (figure.get_node("BossCore").material_override as StandardMaterial3D).albedo_color = Color("8ee4df")
	if boss.counter_flash > 0.0:
		figure.rotation.z += sin(boss.counter_flash * 65.0) * 0.13
		(figure.get_node("BossCore").material_override as StandardMaterial3D).albedo_color = Color("fff0bd")


func _animate_boss_arms(figure: Node3D) -> void:
	var lift := 0.0
	var spread := 0.0
	var swing := 0.0
	if boss.sweep_warning > 0.0:
		var duration: float = boss.warning_duration
		var progress := clampf(1.0 - boss.sweep_warning / duration, 0.0, 1.0)
		lift = -1.10
		swing = lerpf(0.35, 1.20, progress)
	elif boss.sweep_burst_time > 0.0:
		lift = -1.10
		swing = lerpf(-1.15, 1.20, boss.sweep_burst_time / 0.16)
	elif boss.gust_warning > 0.0:
		var duration: float = boss.warning_duration
		spread = lerpf(0.40, 1.30, clampf(1.0 - boss.gust_warning / duration, 0.0, 1.0))
	elif boss.gust_burst_time > 0.0:
		lift = -1.45
	elif boss.recovery_time > 0.0:
		lift = 0.15
		spread = 0.12
	figure.get_node("ArmLeft").rotation = Vector3(lift, swing, spread)
	figure.get_node("ArmRight").rotation = Vector3(lift, swing, -spread)


func _roll_role() -> TrainingEnemy.Role:
	if boss_spawned or run_time < 45.0: return TrainingEnemy.Role.FRAGMENT
	var weights := _route_role_weights(player.global_position)
	var roll := rng.randf() * 100.0
	for role in 5:
		roll -= weights[role]
		if roll < 0.0: return role as TrainingEnemy.Role
	return TrainingEnemy.Role.FRAGMENT


func _route_role_weights(point: Vector2) -> Array[float]:
	if point.x < 1550.0: return [55.0, 30.0, 0.0, 15.0, 0.0]
	if point.x >= 2500.0 and point.x < 4360.0 and point.y < 1500.0: return [25.0, 45.0, 10.0, 15.0, 5.0]
	if point.x >= 2500.0 and point.y >= 1500.0: return [35.0, 15.0, 25.0, 15.0, 10.0]
	return [40.0, 30.0, 10.0, 15.0, 5.0]


func _spawn_now(point: Vector2, role: TrainingEnemy.Role, for_boss: bool) -> void:
	super._spawn_now(point, role, for_boss)
	if for_boss and is_instance_valid(boss):
		actors[boss].get_node("HealthBar").position.y = 3.30


func _build_boss_figure(visual: Node3D) -> void:
	super._build_boss_figure(visual)
	var figure: Node3D = visual.get_node("BossFigure")
	figure.scale = Vector3(1.5, 1.65, 1.45)
	_boss_box(figure, Vector3(0.54, 0.32, 0.36), Vector3(-0.59, 1.46, 0.0), Color("627162"))
	_boss_box(figure, Vector3(0.54, 0.32, 0.36), Vector3(0.59, 1.46, 0.0), Color("627162"))
	_boss_box(figure, Vector3(0.18, 0.52, 0.15), Vector3(-0.32, 2.02, 0.0), Color("d4b881"))
	_boss_box(figure, Vector3(0.18, 0.52, 0.15), Vector3(0.32, 2.02, 0.0), Color("d4b881"))


func _encounter_cue() -> String:
	if _spawn_rate() <= 0.0: return ""
	var phase := _encounter_phase()
	if phase.is_empty(): return ""
	if float(phase.get("rate", 0.0)) < 0.0:
		return "새 적 합류 감소 · 남은 적 경계"
	# Jungle spawns use the player's authored route weights, not the temple's
	# timed role weights. Describe the two most likely incoming roles only.
	var weights := _route_role_weights(player.global_position)
	var roles: Array[int] = [0, 1, 2, 3, 4]
	roles.sort_custom(func(a: int, b: int): return weights[a] > weights[b])
	var names := ["추격", "돌진", "원거리", "장판", "지원"]
	var incoming: Array[String] = []
	for role in roles:
		if weights[role] > 0.0: incoming.append(names[role])
		if incoming.size() == 2: break
	return "새 적: %s · 합류 증가" % "·".join(incoming)


func _run_hud_text() -> String:
	var result := super._run_hud_text()
	if run_time >= BOSS_TIME - 30.0 and not boss_spawned:
		result += "\n관문 상단에 수호자 출현 예정"
	if not is_instance_valid(boss) or not boss is JungleWarden: return result
	if boss.global_position.distance_to(player.global_position) > 850.0:
		result += "\n관문 상단으로 이동"
	return result


func _draw_boss_warning() -> void:
	boss_warning_mesh.clear_surfaces()
	if not is_instance_valid(boss) or not boss is JungleWarden: return
	if boss.sweep_warning <= 0.0 and boss.gust_warning <= 0.0 and boss.sweep_burst_time <= 0.0 and boss.gust_burst_time <= 0.0: return
	var center: Vector2 = boss.global_position
	var forward: Vector2 = boss.locked_direction
	var side: Vector2 = forward.orthogonal()
	var elevation: float = terrain.height_at(center) + 64.0
	boss_warning_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	if boss.sweep_warning > 0.0 or boss.sweep_burst_time > 0.0:
		var half_width: float = JungleWarden.SWEEP_HALF_WIDTH + (35.0 if boss.phase == 2 else 0.0)
		for i in 24:
			var s0 := lerpf(-half_width, half_width, float(i) / 24.0)
			var s1 := lerpf(-half_width, half_width, float(i + 1) / 24.0)
			var a := center + forward * JungleWarden.SWEEP_FORWARD_MIN + side * s0
			var b := center + forward * JungleWarden.SWEEP_FORWARD_MIN + side * s1
			var c := center + forward * JungleWarden.SWEEP_FORWARD_MAX + side * s1
			var d := center + forward * JungleWarden.SWEEP_FORWARD_MAX + side * s0
			if clear_attack(center, a) and clear_attack(center, b) and clear_attack(center, c) and clear_attack(center, d):
				if boss.sweep_warning > 0.0 and float(i + 1) / 24.0 <= 1.0 - boss.sweep_warning / boss.warning_duration:
					_warden_warning_quad(a, b, c, d, elevation + 1.0, Color(1.0, 0.76, 0.32, 0.22))
				_warden_warning_quad(a, b, c, d, elevation, Color(1.0, 0.46, 0.18, 0.72 if boss.sweep_burst_time > 0.0 else _warning_strength(boss.sweep_warning, boss.warning_duration)))
	else:
		var reach: float = JungleWarden.GUST_REACH + (60.0 if boss.phase == 2 else 0.0)
		var inner: float = JungleWarden.GUST_SAFE_RADIUS
		var alpha := 0.68 if boss.gust_burst_time > 0.0 else _warning_strength(boss.gust_warning, boss.warning_duration)
		_draw_boss_area(center, elevation, inner, reach, Color(0.50, 0.94, 1.0, alpha))
		_draw_boss_ring(center, elevation + 1.0, inner, 10.0, Color(0.82, 1.0, 0.93, 0.95))
		_draw_boss_ring(center, elevation + 1.0, reach, 8.0, Color(0.50, 0.94, 1.0, 0.9))
		if boss.gust_warning > 0.0:
			var progress := clampf(1.0 - boss.gust_warning / boss.warning_duration, 0.0, 1.0)
			_draw_boss_ring(center, elevation + 2.0, lerpf(reach, inner, progress), 5.0, Color(0.85, 1.0, 1.0, 0.9))
	boss_warning_mesh.surface_end()


func _warden_warning_quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, elevation: float, color: Color) -> void:
	for point in [a, b, c, a, c, d]:
		boss_warning_mesh.surface_set_color(color)
		boss_warning_mesh.surface_add_vertex(Vector3(point.x, elevation, point.y) * PassTerrain.SCALE)


func _build_gate_silhouette() -> void:
	# Columns come from the same terrain records that draw and block them.
	# The lintel overhangs their outer faces, avoiding coincident mesh surfaces.
	var first: Vector2 = PassTerrain.GATE_COLUMN_CENTERS[0]
	var last: Vector2 = PassTerrain.GATE_COLUMN_CENTERS[-1]
	var column_top: float = terrain.gate_columns[0].height
	var bridge := MeshInstance3D.new()
	bridge.name = "GateLintel"
	var lintel := BoxMesh.new()
	lintel.size = Vector3((last.x - first.x + PassTerrain.GATE_COLUMN_SIZE.x + 160.0) * PassTerrain.SCALE, 0.45, 0.65)
	bridge.mesh = lintel
	bridge.material_override = _material(Color("788879"), false)
	bridge.position = Vector3((first.x + last.x) * 0.5, column_top + 10.0, (first.y + last.y) * 0.5) * PassTerrain.SCALE
	add_child(bridge)


func _build_jungle_silhouette() -> void:
	# Decorative canopy massing sits beside the clear navigation routes.
	var canopy_points: Array = terrain.route_canopy_points if terrain is RouteTerrain else PassTerrain.CANOPY_POINTS
	for i in canopy_points.size():
		var point: Vector2 = canopy_points[i]
		var root := terrain.world_point(point)
		var height := 2.9 + float(int(point.x + point.y) % 5) * 0.32
		var trunk := MeshInstance3D.new()
		trunk.name = "CanopyTrunk%d" % i
		var stem := CylinderMesh.new()
		stem.top_radius = 0.14
		stem.bottom_radius = 0.23
		stem.height = height
		trunk.mesh = stem
		trunk.position = root + Vector3(0, height * 0.5, 0)
		trunk.material_override = _material(Color("5c5344"))
		add_child(trunk)
		canopy_visuals[point] = trunk
		for branch in [Vector3(0, height, 0), Vector3(-0.62, height * 0.82, 0.12), Vector3(0.50, height * 0.90, -0.18)]:
			var leaves := MeshInstance3D.new()
			var crown := SphereMesh.new()
			crown.radius = 0.93 if branch.x == 0.0 else 0.67
			crown.height = 0.72 if branch.x == 0.0 else 0.58
			crown.radial_segments = 8
			crown.rings = 4
			leaves.mesh = crown
			leaves.position = root + branch
			leaves.material_override = _material(Color("486d57") if int(point.x) % 3 == 0 else Color("657e5a"))
			add_child(leaves)


func _build_gate_approaches() -> void:
	var stairs: Dictionary = terrain.ramps[3]
	var rocks: Dictionary = terrain.ramps[4]
	for side_y in [stairs.area.position.y + 15.0, stairs.area.end.y - 15.0]:
		for step in [0, 4, 8, 12]:
			var x: float = stairs.area.position.x + stairs.area.size.x * float(step) / 12.0
			var height: float = terrain.ramp_height(stairs, Vector2(x, side_y))
			var post := MeshInstance3D.new()
			post.name = "StairPost"
			var shape := BoxMesh.new()
			shape.size = Vector3(0.24, 0.62, 0.30)
			post.set_meta("worn_stone_kind", "post")
			post.mesh = WornStone.post_mesh(shape.size, step / 4) if WornStone.enabled() else shape
			post.material_override = _material(Color("797d6c"))
			post.position = Vector3(x * PassTerrain.SCALE, (height + 31.0) * PassTerrain.SCALE, side_y * PassTerrain.SCALE)
			add_child(post)
	for side in [-1.0, 1.0]:
		for step in 5:
			var x: float = rocks.area.position.x + rocks.area.size.x * (float(step) + 0.5) / 5.0
			var y: float = rocks.area.position.y - 24.0 if side < 0.0 else rocks.area.end.y + 24.0
			var height: float = terrain.ramp_height(rocks, Vector2(x, y))
			if terrain is RouteTerrain:
				var point: Vector2 = RouteTerrain.ROCK_EDGE_POINTS[step + (0 if side < 0 else 5)]
				x = point.x
				y = point.y
				height = terrain.height_at(point)
			var shard := MeshInstance3D.new()
			shard.name = "RockEdge"
			var shape := BoxMesh.new()
			shape.size = Vector3(0.38, 0.44 + float(step % 3) * 0.17, 0.52)
			shard.set_meta("worn_stone_kind", "rock")
			shard.mesh = WornStone.rock_mesh(shape.size, step + (0 if side < 0 else 5)) if WornStone.enabled() else shape
			shard.material_override = _material(Color("586c65") if step % 2 == 0 else Color("748379"))
			shard.position = Vector3(x * PassTerrain.SCALE, (height + shape.size.y * 50.0) * PassTerrain.SCALE, y * PassTerrain.SCALE)
			shard.rotation.y = float(step + 1) * 0.17 * side
			shard.rotation.z = (0.12 + float(step % 2) * 0.08) * side
			add_child(shard)


func _build_river_route() -> void:
	# Low water ribbons and rooted banks keep the path and actors readable.
	if not terrain is RouteTerrain:
		for i in 28:
			var point := Vector2(2790 + i * 48, 2200 + sin(i * 0.7) * 14)
			var water := MeshInstance3D.new()
			water.name = "RiverRibbon"
			var shape := BoxMesh.new()
			shape.size = Vector3(0.52, 0.025, 0.55)
			water.mesh = shape
			water.position = terrain.world_point(point, 2)
			water.material_override = _material(Color("76b2ad"))
			add_child(water)
	var root_points: Array = RouteTerrain.RIVER_ROOT_POINTS if terrain is RouteTerrain else [Vector2(2790, 2030), Vector2(3170, 2090), Vector2(2810, 1590)]
	for point in root_points:
		var root := MeshInstance3D.new()
		root.name = "RiverRoot"
		var shape := BoxMesh.new()
		shape.size = Vector3(0.22, 0.10, 0.65)
		root.mesh = shape
		root.position = terrain.world_point(point, 5)
		root.rotation.y = 0.7
		root.material_override = _material(Color("685d48"))
		add_child(root)


func _build_route_scenery() -> void:
	# Low silhouettes give forest, causeway and riverbank different visual rhythms.
	for center in [Vector2(420, 480), Vector2(850, 430), Vector2(420, 1740), Vector2(1150, 1830), Vector2(1850, 640), Vector2(2220, 1850)]:
		for i in 6:
			var angle := float(i) * TAU / 6.0
			var point: Vector2 = center + Vector2.from_angle(angle) * (45.0 + float(i % 3) * 30.0)
			var shrub := _sphere(0.18 + float(i % 3) * 0.04, Color("456c53") if i % 2 == 0 else Color("789165"))
			shrub.name = "ForestUnderstory"
			shrub.position = terrain.world_point(point, 18.0)
			add_child(shrub)
	for i in 16:
		var point := Vector2(2600 + i * 75, 820 + float(i % 3) * 32)
		var fragment := MeshInstance3D.new()
		fragment.name = "CausewayFragment"
		var shape := BoxMesh.new()
		shape.size = Vector3(0.22 + float(i % 3) * 0.09, 0.08, 0.27)
		fragment.mesh = shape
		fragment.position = terrain.world_point(point, 4.0)
		fragment.rotation.y = float(i) * 0.37
		fragment.material_override = _material(Color("b5aa88") if i % 2 == 0 else Color("7b806d"))
		add_child(fragment)
	for i in 24:
		var point := Vector2(2770 + i * 57, 2180 + sin(float(i) * 0.72) * 26.0)
		if terrain is RouteTerrain: point = terrain.route_reed_points[i]
		var reed := MeshInstance3D.new()
		reed.name = "RiverReed"
		var shape := CylinderMesh.new()
		shape.top_radius = 0.025
		shape.bottom_radius = 0.055
		shape.height = 0.42 + float(i % 3) * 0.08
		reed.mesh = shape
		reed.position = terrain.world_point(point, 27.0)
		reed.rotation.z = -0.15 + 0.12 * float(i % 4)
		reed.material_override = _material(Color("b4b17e") if i % 2 == 0 else Color("799b78"))
		add_child(reed)
