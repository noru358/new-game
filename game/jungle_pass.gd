extends "res://game/hybrid_region.gd"

const PassTerrain = preload("res://game/jungle_pass_terrain.gd")
const GATE_BOSS_POINTS := [Vector2(4700, 800), Vector2(4700, 1200), Vector2(4700, 1650)]
var canopy_visuals: Dictionary = {}
var gate_route_encounter := ""
var gate_route_crest_triggered := false


func _init() -> void:
	super._init()
	terrain = PassTerrain.new()
	start_point = Vector2(430, 1210)
	enemy_points = [
		Vector2(500, 1120), Vector2(970, 820), Vector2(1110, 1750),
		Vector2(1860, 1120), Vector2(2530, 830), Vector2(3300, 1210),
		Vector2(4210, 1100), Vector2(5080, 1150)
	]
	landmark_points = {
		"정글 입구": Vector2(430, 1210),
		"서쪽 상승로": Vector2(1410, 1180),
		"북쪽 덩굴길": Vector2(2180, 420),
		"정글 능선": Vector2(2640, 1120),
		"석계단 정면길": Vector2(3070, 1110),
		"하층 협곡": Vector2(3010, 1850),
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
	combat_camera_size = 10.0
	overview_camera_size = 43.0
	camera_offset = Vector3(15, 16, 15)
	ground_color = Color("536e5e")
	plateau_color = Color("888d6c")
	cliff_color = Color("3d5953")
	ramp_color = Color("ada27b")


func _ready() -> void:
	super._ready()
	_build_gate_silhouette()
	_build_jungle_silhouette()
	_build_gate_approaches()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if run_ended or practice_mode or paused or growth.choosing or get_tree().paused or _active_enemy_count() > MAX_ENEMIES - 2: return
	var point: Vector2 = player.global_position
	if gate_route_encounter.is_empty():
		for route in terrain.gate_routes:
			if terrain.gate_routes[route].entry.has_point(point):
				gate_route_encounter = route
				_spawn_route_sentries(route, false)
				return
	elif not gate_route_crest_triggered and terrain.gate_routes[gate_route_encounter].crest.has_point(point):
		gate_route_crest_triggered = true
		_spawn_route_sentries(gate_route_encounter, true)


func _spawn_route_sentries(route: String, at_crest: bool) -> void:
	var sentries: Array = []
	if route == "stairs":
		sentries = [[Vector2(3970, 1010), TrainingEnemy.Role.BEAST], [Vector2(4020, 1330), TrainingEnemy.Role.LAMP]] if at_crest else [[Vector2(2890, 1050), TrainingEnemy.Role.BEAST], [Vector2(3080, 1250), TrainingEnemy.Role.LAMP]]
	else:
		sentries = [[Vector2(4140, 1560), TrainingEnemy.Role.ZONE], [Vector2(4060, 1840), TrainingEnemy.Role.BEAST]] if at_crest else [[Vector2(2830, 1770), TrainingEnemy.Role.ZONE], [Vector2(3130, 1840), TrainingEnemy.Role.BEAST]]
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


func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(boss) or not boss is JungleWarden or not actors.has(boss): return
	var figure: Node3D = actors[boss].get_node("BossFigure")
	(figure.get_node("BossCore").material_override as StandardMaterial3D).albedo_color = Color.WHITE if boss.hit_flash > 0.0 else Color("d6bc73") if boss.phase == 2 else Color("707d72")
	figure.rotation.z = 0.22 * (1.0 - boss.sweep_warning / JungleWarden.SWEEP_WARNING) if boss.sweep_warning > 0.0 else -0.34 if boss.sweep_burst_time > 0.0 else 0.0
	figure.rotation.x = -0.18 if boss.gust_warning > 0.0 else 0.22 if boss.gust_burst_time > 0.0 else 0.0


func _roll_role() -> TrainingEnemy.Role:
	if boss_spawned or run_time < 45.0: return TrainingEnemy.Role.FRAGMENT
	var weights := [45.0, 30.0, 5.0, 15.0, 5.0] if run_time < 120.0 else [35.0, 28.0, 12.0, 17.0, 8.0] if run_time < 200.0 else [30.0, 27.0, 15.0, 18.0, 10.0]
	var roll := rng.randf() * 100.0
	for role in 5:
		roll -= weights[role]
		if roll < 0.0: return role as TrainingEnemy.Role
	return TrainingEnemy.Role.FRAGMENT


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


func _run_hud_text() -> String:
	var result := super._run_hud_text()
	if run_time >= 270.0 and not boss_spawned:
		result += "\n관문 상단에 수호자 출현 예정"
	if not is_instance_valid(boss) or not boss is JungleWarden: return result
	if boss.global_position.distance_to(player.global_position) > 850.0:
		result += "\n관문 상단으로 이동"
	if boss.sweep_warning > 0.0: result += "  ·  횡쓸기! 옆/뒤로 피하기"
	elif boss.gust_warning > 0.0: result += "  ·  강풍! 부채꼴 밖으로 피하기"
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
				_warden_warning_quad(a, b, c, d, elevation, Color(1.0, 0.46, 0.18, 0.72 if boss.sweep_burst_time > 0.0 else 0.32))
	else:
		var reach: float = JungleWarden.GUST_REACH + (60.0 if boss.phase == 2 else 0.0)
		for i in 20:
			var f0 := reach * float(i) / 20.0
			var f1 := reach * float(i + 1) / 20.0
			var w0 := maxf(55.0, f0 * 0.58)
			var w1 := maxf(55.0, f1 * 0.58)
			var a := center + forward * f0 - side * w0
			var b := center + forward * f0 + side * w0
			var c := center + forward * f1 + side * w1
			var d := center + forward * f1 - side * w1
			if clear_attack(center, a) and clear_attack(center, b) and clear_attack(center, c) and clear_attack(center, d):
				_warden_warning_quad(a, b, c, d, elevation, Color(0.50, 0.94, 1.0, 0.68 if boss.gust_burst_time > 0.0 else 0.30))
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
	lintel.size = Vector3((last.x - first.x + PassTerrain.GATE_COLUMN_SIZE.x + 160.0) * PassTerrain.SCALE, 1.15, 1.45)
	bridge.mesh = lintel
	bridge.material_override = _material(Color("788879"), false)
	bridge.position = Vector3((first.x + last.x) * 0.5, column_top + 37.5, (first.y + last.y) * 0.5) * PassTerrain.SCALE
	add_child(bridge)


func _build_jungle_silhouette() -> void:
	# Decorative canopy massing sits beside the clear navigation routes.
	for i in PassTerrain.CANOPY_POINTS.size():
		var point: Vector2 = PassTerrain.CANOPY_POINTS[i]
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
			post.mesh = shape
			post.material_override = _material(Color("797d6c"))
			post.position = Vector3(x * PassTerrain.SCALE, (height + 31.0) * PassTerrain.SCALE, side_y * PassTerrain.SCALE)
			add_child(post)
	for side in [-1.0, 1.0]:
		for step in 5:
			var x: float = rocks.area.position.x + 30.0 + float(step) * 58.0
			var y: float = rocks.area.position.y - 24.0 if side < 0.0 else rocks.area.end.y + 24.0
			var height: float = terrain.ramp_height(rocks, Vector2(x, y))
			var shard := MeshInstance3D.new()
			shard.name = "RockEdge"
			var shape := BoxMesh.new()
			shape.size = Vector3(0.38, 0.44 + float(step % 3) * 0.17, 0.52)
			shard.mesh = shape
			shard.material_override = _material(Color("586c65") if step % 2 == 0 else Color("748379"))
			shard.position = Vector3(x * PassTerrain.SCALE, (height + shape.size.y * 50.0) * PassTerrain.SCALE, y * PassTerrain.SCALE)
			shard.rotation.y = float(step + 1) * 0.17 * side
			shard.rotation.z = (0.12 + float(step % 2) * 0.08) * side
			add_child(shard)
