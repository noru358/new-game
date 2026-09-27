extends "res://game/hybrid_region.gd"

const PassTerrain = preload("res://game/jungle_pass_terrain.gd")


func _init() -> void:
	super._init()
	terrain = PassTerrain.new()
	start_point = Vector2(430, 1210)
	enemy_points = [
		Vector2(500, 1120), Vector2(970, 820), Vector2(1110, 1750),
		Vector2(1860, 1120), Vector2(2530, 830), Vector2(3300, 1440),
		Vector2(4210, 1100), Vector2(5080, 1150)
	]
	landmark_points = {
		"정글 입구": Vector2(430, 1210),
		"서쪽 상승로": Vector2(1410, 1180),
		"북쪽 덩굴길": Vector2(2180, 420),
		"정글 능선": Vector2(2640, 1120),
		"남쪽 우회로": Vector2(2870, 1970),
		"관문 상단": Vector2(4520, 1160),
	}
	region_id = RunProfile.JUNGLE_REGION
	boss_scene = preload("res://game/jungle_warden.tscn")
	boss_name = "관문 수호자"
	first_clear_notice = "관문 통과 · 새 3·4타 장비 선택 가능"
	scene_title = "Loop Conquest — Jungle Pass v09"
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


func _update_run_hud() -> void:
	super._update_run_hud()
	if run_hud == null or not is_instance_valid(boss) or not boss is JungleWarden: return
	if boss.sweep_warning > 0.0: run_hud.text += "  ·  횡쓸기! 옆/뒤로 피하기"
	elif boss.gust_warning > 0.0: run_hud.text += "  ·  강풍! 부채꼴 밖으로 피하기"


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
	for point in PassTerrain.CANOPY_POINTS:
		var root := terrain.world_point(point)
		var height := 2.3 + float(int(point.x + point.y) % 5) * 0.28
		var trunk := MeshInstance3D.new()
		var stem := CylinderMesh.new()
		stem.top_radius = 0.14
		stem.bottom_radius = 0.23
		stem.height = height
		trunk.mesh = stem
		trunk.position = root + Vector3(0, height * 0.5, 0)
		trunk.material_override = _material(Color("5c5344"))
		add_child(trunk)
		for branch in [Vector3(0, height, 0), Vector3(-0.45, height * 0.80, 0.12), Vector3(0.38, height * 0.89, -0.18)]:
			var leaves := MeshInstance3D.new()
			var crown := SphereMesh.new()
			crown.radius = 0.72 if branch.x == 0.0 else 0.55
			crown.height = 1.1 if branch.x == 0.0 else 0.85
			leaves.mesh = crown
			leaves.position = root + branch
			leaves.material_override = _material(Color("486d57") if int(point.x) % 3 == 0 else Color("657e5a"))
			add_child(leaves)
