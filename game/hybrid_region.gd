extends "res://game/hybrid_height.gd"

const RegionTerrain = preload("res://game/temple_hybrid_terrain.gd")
const ProfileScript = preload("res://game/run_profile.gd")
const BOSS_TIME := 300.0
const MAX_ENEMIES := 48

var practice_mode := false
var region_id := RunProfile.TEMPLE_REGION
var boss_name := "문지기"
var first_clear_notice := "첫 지역 완료 · 새 장비 선택 가능"
var boss_scene: PackedScene = preload("res://game/gate_boss.tscn")
var profile_save_prefix := "user://loop_conquest_profile"
var profile: RunProfile
var run_id := ""
var run_time := 0.0
var run_currency := 0
var spawn_credit := 0.0
var boss_retry := 0.0
var boss_announced := false
var boss_spawned := false
var boss_defeated := false
var death_pending := false
var run_ended := false
var end_result := ""
var settlement_pending := false
var supply_ready := false
var boss: GateBoss
var pending_spawns: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var run_hud: Label
var result_overlay: ColorRect
var result_text: Label
var replay_button: Button
var retry_button: Button
var boss_warning_mesh := ImmediateMesh.new()
var echo_wisp_mod_enabled := false
var ember_strike_mod_enabled := false
var echo_wisp_fired_sequence := -1


func _init() -> void:
	terrain = RegionTerrain.new()
	start_point = Vector2(650, 1870)
	enemy_points = [
		Vector2(120, 1850), Vector2(650, 920), Vector2(960, 1100),
		Vector2(1910, 1050), Vector2(2690, 900), Vector2(3390, 1220),
		Vector2(4170, 850), Vector2(4680, 1380)
	]
	landmark_points = {
		"수변 남쪽": Vector2(650, 1870),
		"중정": Vector2(660, 1120),
		"테라스": Vector2(1000, 1100),
		"사원 뜰": Vector2(1950, 900),
		"회랑": Vector2(3410, 900),
		"성소": Vector2(4750, 1100)
	}
	scene_title = "Loop Conquest — 청록 폐사원"
	scene_hud_title = "청록 폐사원"
	combat_camera_size = 9.0
	overview_camera_size = 40.0
	camera_offset = Vector3(14, 13.864, 14)
	# Continue the original 1F cumulative card-unlock record in the main scene.
	growth_save_prefix = "user://loop_conquest_1d_unlocks"


func _ready() -> void:
	show_practice_controls = practice_mode
	# Keep the new move available in the live run while its final unlock is designed.
	moving_slash_practice = true
	super._ready()
	player.attack_hitstop_scale = 1.0
	if practice_mode: return
	growth.permanent_combo_progression = true
	growth._sync_permanent_moves()
	rng.randomize()
	run_id = "%d-%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec(), rng.randi()]
	profile = ProfileScript.new()
	profile.save_prefix = profile_save_prefix
	profile.load_state()
	if not profile.load_error and not profile.begin_run(run_id): profile.load_error = true
	if not profile.load_error:
		_apply_preparation()
	player.defeated.connect(func(): death_pending = true)
	_build_run_ui()
	if profile.load_error:
		run_ended = true
		paused = true
		get_tree().paused = true
		result_text.text = "저장 기록을 읽을 수 없습니다.\n기존 기록을 덮어쓰지 않았습니다."
		replay_button.disabled = true
		retry_button.hide()
		result_overlay.show()
	else:
		_update_run_hud()


func _apply_preparation() -> void:
	var ranks: Dictionary = profile.growth_ranks
	player.permanent_basic_damage_bonus = 0.05 * int(ranks.POWER)
	player.max_health += 10.0 * int(ranks.VITALITY)
	player.permanent_dash_cooldown_reduction = 0.04 * int(ranks.MOBILITY)
	player.permanent_slash_cooldown_reduction = 0.03 * int(ranks.SLASH)
	player.permanent_finisher_reach_bonus = 0.05 * int(ranks.FINISH)
	player.permanent_damage_reduction = 0.05 * int(ranks.GUARD)
	player.permanent_move_speed_bonus = 0.04 * int(ranks.SPEED)
	growth.permanent_wisp_cadence_reduction = 0.04 * int(ranks.WISP)
	if profile.equipped_weapon == "W_FLOW":
		player.flow_weave_enabled = true
		player.moving_slash_distance_multiplier = 1.20
		player.permanent_slash_cooldown_reduction += 0.10
		if profile.mod_for("W_FLOW") == "KEEN": player.moving_slash_damage_bonus = 0.04
		elif profile.mod_for("W_FLOW") == "SWIFT": player.permanent_slash_cooldown_reduction += 0.04
		elif profile.mod_for("W_FLOW") == "WEAVE": player.flow_weave_refund_bonus = 0.10
		elif profile.mod_for("W_FLOW") == "RIPPLE": player.flow_wave_enabled = true
	elif profile.equipped_weapon == "W_ECHO":
		player.echo_finisher_enabled = true
		if profile.mod_for("W_ECHO") == "WIDE": player.echo_finisher_radius_bonus = 0.10
		elif profile.mod_for("W_ECHO") == "HEAVY": player.echo_finisher_damage_bonus = 0.08
		elif profile.mod_for("W_ECHO") == "DRAW": player.echo_gather_reach_bonus = 0.08
		elif profile.mod_for("W_ECHO") == "ECHO_WISP": echo_wisp_mod_enabled = true
	if profile.equipped_accessory == "A_EMBER":
		wisp.permanent_damage_bonus = 0.15
		if profile.mod_for("A_EMBER") == "BRIGHT": wisp.permanent_damage_bonus += 0.05
		elif profile.mod_for("A_EMBER") == "STEADY": player.max_health += 5.0
		elif profile.mod_for("A_EMBER") == "EMBER_STRIKE": ember_strike_mod_enabled = true
	growth._sync_wisps()
	player.health = player.max_health
	supply_ready = profile.last_launch_supply_used
	if supply_ready: player.health_changed.connect(_try_use_supply)


func _on_player_attack_landed(point: Vector2, direction: Vector2, step: int, finisher: bool) -> void:
	super._on_player_attack_landed(point, direction, step, finisher)
	if not echo_wisp_mod_enabled or step != 4 or echo_wisp_fired_sequence == player.attack_sequence: return
	for companion in growth.wisps:
		var target := companion.find_target()
		if target != null and companion.fire_bonus_shot(target):
			echo_wisp_fired_sequence = player.attack_sequence
			break


func _on_wisp_hit(enemy: TrainingEnemy) -> void:
	super._on_wisp_hit(enemy)
	if ember_strike_mod_enabled and is_instance_valid(player): player.grant_ember_followup()


func _try_use_supply() -> void:
	if not supply_ready or player.health <= 0.0 or player.health > player.max_health * 0.35: return
	supply_ready = false
	player.health = minf(player.max_health, player.health + 30.0)
	player.health_changed.emit()
	if run_hud != null: run_hud.text += "\n회복 부적 발동 · HP +30"


func spawn_enemies() -> void:
	if practice_mode: super.spawn_enemies()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if practice_mode or run_ended: return
	if boss_defeated:
		_finish_run("SUCCESS")
		return
	if death_pending or player.health <= 0.0:
		_finish_run("DEFEAT")
		return
	if paused or growth.choosing or get_tree().paused: return
	run_time += delta
	_tick_pending(delta)
	spawn_credit += _spawn_rate() * delta
	while spawn_credit >= 1.0:
		spawn_credit -= 1.0
		if _active_enemy_count() < MAX_ENEMIES:
			var point := _choose_spawn_point(false)
			if point != Vector2.INF:
				_schedule_spawn(point, _roll_role(), false)
	if run_time >= BOSS_TIME and not boss_announced and not boss_spawned:
		boss_retry -= delta
		if boss_retry <= 0.0:
			boss_retry = 1.0
			var point := _choose_spawn_point(true)
			if point != Vector2.INF:
				boss_announced = true
				_schedule_spawn(point, TrainingEnemy.Role.BEAST, true)
			else:
				push_warning("No safe boss spawn point; retrying")
	_update_run_hud()


func _process(delta: float) -> void:
	super._process(delta)
	if practice_mode: return
	if is_instance_valid(boss) and actors.has(boss):
		var visual: Node3D = actors[boss]
		var core: MeshInstance3D = visual.get_node("BossFigure/BossCore")
		(core.material_override as StandardMaterial3D).albedo_color = Color.WHITE if boss.hit_flash > 0.0 else Color("e78363") if boss.phase == 2 else Color("b99975")
		visual.get_node("BossFigure").rotation.z = -0.15 if boss.charge_time > 0.0 else 0.10 * sin(Time.get_ticks_msec() * 0.008) if boss.warning_time > 0.0 or boss.shock_warning > 0.0 or boss.ring_warning > 0.0 else 0.0
	_draw_boss_warning()


func _spawn_rate() -> float:
	if boss_spawned: return 0.25
	if run_time < 45.0: return 0.60
	if run_time < 120.0: return 0.85
	if run_time < 200.0: return 1.10
	return 1.40


func _roll_role() -> TrainingEnemy.Role:
	if boss_spawned or run_time < 45.0: return TrainingEnemy.Role.FRAGMENT
	var roll := rng.randf() * 100.0
	var weights := [70.0, 20.0, 0.0, 10.0, 0.0] if run_time < 120.0 else [55.0, 20.0, 10.0, 10.0, 5.0] if run_time < 200.0 else [45.0, 20.0, 15.0, 10.0, 10.0]
	for role in 5:
		roll -= weights[role]
		if roll < 0.0: return role as TrainingEnemy.Role
	return TrainingEnemy.Role.FRAGMENT


func _active_enemy_count() -> int:
	var count := 0
	for actor in actors:
		if is_instance_valid(actor) and actor is TrainingEnemy and not actor is GateBoss and not actor.is_queued_for_deletion(): count += 1
	for entry in pending_spawns:
		if not entry.boss: count += 1
	return count


func _choose_spawn_point(for_boss: bool) -> Vector2:
	var visible_candidate := Vector2.INF
	for attempt in 60:
		var radius := rng.randf_range(500.0, 850.0)
		var point := player.global_position + Vector2.from_angle(rng.randf_range(0.0, TAU)) * radius
		if point.x < 60.0 or point.y < 60.0 or point.x > terrain.map_size.x - 60.0 or point.y > terrain.map_size.y - 60.0: continue
		if point.distance_to(player.global_position) < (450.0 if for_boss else 380.0): continue
		if not navigation.is_open(point, 48.0 if for_boss else ACTOR_CLEARANCE + 6.0): continue
		if navigation.find_path(point, player.global_position).size() < 2: continue
		if not _point_on_screen(point): return point
		if visible_candidate == Vector2.INF: visible_candidate = point
	return visible_candidate


func _point_on_screen(point: Vector2) -> bool:
	var world := terrain.world_point(point, 60.0)
	return not camera.is_position_behind(world) and get_viewport().get_visible_rect().grow(-45.0).has_point(camera.unproject_position(world))


func _schedule_spawn(point: Vector2, role: TrainingEnemy.Role, for_boss: bool) -> void:
	var delay := 1.2 if for_boss else 0.8 if _point_on_screen(point) else 0.0
	if delay <= 0.0:
		_spawn_now(point, role, for_boss)
		return
	var marker := _sphere(0.28 if for_boss else 0.18, Color("ff9c68") if for_boss else Color("f7e6a2"))
	marker.position = terrain.world_point(point, 18.0)
	add_child(marker)
	pending_spawns.append({"point": point, "role": role, "boss": for_boss, "delay": delay, "marker": marker})


func _tick_pending(delta: float) -> void:
	for i in range(pending_spawns.size() - 1, -1, -1):
		var entry := pending_spawns[i]
		entry.delay = float(entry.delay) - delta
		if entry.delay > 0.0: continue
		(entry.marker as Node3D).queue_free()
		pending_spawns.remove_at(i)
		var point: Vector2 = entry.point
		if point.distance_to(player.global_position) >= (350.0 if entry.boss else 260.0) and navigation.is_open(point, 48.0 if entry.boss else ACTOR_CLEARANCE + 6.0) and navigation.find_path(point, player.global_position).size() >= 2:
			_spawn_now(point, entry.role, entry.boss)
		elif entry.boss:
			boss_announced = false


func _spawn_now(point: Vector2, role: TrainingEnemy.Role, for_boss: bool) -> void:
	if not for_boss:
		var health: float = [22.0, 45.0, 30.0, 32.0, 36.0][int(role)]
		_spawn_enemy_at(point, role, health)
		return
	boss = boss_scene.instantiate()
	boss.position = point
	boss.collision_radius = 38.0
	boss.contact_margin = 3.0
	boss.target = player
	boss.arena_bounds = Rect2(Vector2.ZERO, terrain.map_size)
	boss.collision_mask = 6
	boss.navigation = navigation
	boss.projectile_parent = simulation
	boss.zone_path_filter = clear_attack
	simulation.add_child(boss)
	var visual := _actor_visual(Color("f2b66f"))
	_build_boss_figure(visual)
	_add_health_bar(visual, boss)
	visual.get_node("HealthBar").position.y = 2.30
	actors[boss] = visual
	actor_motion[boss] = [boss.global_position, boss.global_position]
	boss.defeated.connect(_on_enemy_defeated.bind(boss))
	boss_spawned = true


func _build_boss_figure(visual: Node3D) -> void:
	visual.get_node("Body").hide()
	var shadow: MeshInstance3D = visual.get_node("Shadow")
	(shadow.mesh as CylinderMesh).top_radius = 0.52
	(shadow.mesh as CylinderMesh).bottom_radius = 0.52
	var figure := Node3D.new()
	figure.name = "BossFigure"
	visual.add_child(figure)
	var torso := CylinderMesh.new()
	torso.top_radius = 0.29
	torso.bottom_radius = 0.43
	torso.height = 1.0
	torso.radial_segments = 8
	var core := MeshInstance3D.new()
	core.name = "BossCore"
	core.mesh = torso
	core.position.y = 0.85
	core.material_override = _material(Color("b99975"), true)
	figure.add_child(core)
	_boss_box(figure, Vector3(0.25, 0.52, 0.30), Vector3(-0.19, 0.26, 0.0), Color("625d55"))
	_boss_box(figure, Vector3(0.25, 0.52, 0.30), Vector3(0.19, 0.26, 0.0), Color("625d55"))
	for side in [-1.0, 1.0]:
		_boss_box(figure, Vector3(0.31, 0.35, 0.33), Vector3(side * 0.40, 1.25, 0.0), Color("8f7866"))
		_boss_box(figure, Vector3(0.25, 0.60, 0.27), Vector3(side * 0.49, 0.88, 0.0), Color("70645b"))
		_boss_box(figure, Vector3(0.12, 0.34, 0.13), Vector3(side * 0.18, 1.93, 0.0), Color("e6b775"))
	var head := _sphere(0.28, Color("d9bd94"))
	head.position.y = 1.60
	figure.add_child(head)
	var heart := _sphere(0.14, Color("ffb765"))
	heart.position = Vector3(0.0, 0.94, 0.40)
	figure.add_child(heart)


func _boss_box(parent: Node3D, dimensions: Vector3, at: Vector3, color: Color) -> void:
	var block := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	block.mesh = mesh
	block.position = at
	block.material_override = _material(color, true)
	parent.add_child(block)


func _on_enemy_defeated(enemy: TrainingEnemy) -> void:
	if practice_mode:
		super._on_enemy_defeated(enemy)
		return
	if run_ended: return
	if enemy is GateBoss:
		boss_defeated = true
		return
	super._on_enemy_defeated(enemy)
	run_currency += 1 if enemy.role == TrainingEnemy.Role.FRAGMENT else 2


func _finish_run(result: String) -> void:
	if run_ended: return
	run_ended = true
	end_result = result
	paused = true
	get_tree().paused = true
	for entry in pending_spawns: (entry.marker as Node3D).queue_free()
	pending_spawns.clear()
	settlement_pending = not profile.settle(run_id, result, run_currency, region_id)
	_show_result()


func _show_result() -> void:
	result_overlay.show()
	replay_button.disabled = settlement_pending
	retry_button.visible = settlement_pending
	var heading := boss_name + " 격파 · 성공" if end_result == "SUCCESS" else "런 종료 · 사망" if end_result == "DEFEAT" else "런 종료 · 귀환"
	if settlement_pending:
		result_text.text = "%s\n정산 저장에 실패했습니다. 저장을 재시도하세요.\n종료하면 미저장 화폐가 사라집니다.\n현재 획득 화폐 %d" % [heading, run_currency]
		return
	result_text.text = "%s\n생존 시간 %02d:%02d  ·  처치 %d\n획득 %d  ·  손실 %d  ·  정산 +%d  ·  누적 %d%s\n\n야영지에서 다음 지역과 장비를 고를 수 있습니다." % [
		heading, floori(run_time / 60.0), floori(fmod(run_time, 60.0)), kills,
		run_currency, profile.last_lost, profile.last_award, profile.currency, "\n" + first_clear_notice if profile.last_first_clear else ""
	]
	if not profile.last_mod_award.is_empty():
		var option_gear := RunProfile.gear_for_affix(profile.last_mod_award)
		result_text.text += "\n%s 옵션 획득: %s\n야영지 장비창에서 장착할 수 있습니다." % [RunProfile.gear_name(option_gear), RunProfile.affix_description(profile.last_mod_award)]


func _retry_settlement() -> void:
	if not settlement_pending: return
	settlement_pending = not profile.settle(run_id, end_result, run_currency, region_id)
	_show_result()


func _update_run_hud() -> void:
	if run_hud == null: return
	var remaining := maxi(0, ceili(BOSS_TIME - run_time))
	run_hud.text = "경과 %02d:%02d  ·  %s까지 %02d:%02d  ·  화폐 %d  ·  적 %d/%d" % [floori(run_time / 60.0), floori(fmod(run_time, 60.0)), boss_name, remaining / 60, remaining % 60, run_currency, _active_enemy_count(), MAX_ENEMIES]
	if boss_announced and not boss_spawned: run_hud.text += "\n%s 등장 예고" % boss_name
	if is_instance_valid(boss) and boss.health > 0.0:
		run_hud.text = "경과 %02d:%02d  ·  화폐 %d  ·  적 %d/%d\n%s %d단계 · HP %d / %d" % [floori(run_time / 60.0), floori(fmod(run_time, 60.0)), run_currency, _active_enemy_count(), MAX_ENEMIES, boss_name, boss.phase, ceili(boss.health), ceili(boss.max_health)]
		if boss.warning_time > 0.0: run_hud.text += "  ·  붉은 띠 밖으로 회피!"
		elif boss.shock_warning > 0.0: run_hud.text += "  ·  주황 원 밖으로 회피!"
		elif boss.ring_warning > 0.0: run_hud.text += "  ·  바깥 고리 회피! 안쪽이 안전"
	if profile != null and profile.recovered_backup: run_hud.text += "\n이전 정상 기록을 복구했습니다."


func _draw_boss_warning() -> void:
	boss_warning_mesh.clear_surfaces()
	if not is_instance_valid(boss) or (boss.shock_warning <= 0.0 and boss.ring_warning <= 0.0): return
	var center := boss.global_position
	var elevation := terrain.height_at(center) + 65.0
	boss_warning_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	if boss.shock_warning > 0.0:
		_draw_boss_area(center, elevation, 0.0, GateBoss.SHOCK_RADIUS, Color(1.0, 0.38, 0.14, 0.11))
		_draw_boss_ring(center, elevation, GateBoss.SHOCK_RADIUS, 18.0, Color(0.43, 0.08, 0.04, 0.80))
		_draw_boss_ring(center, elevation + 2.0, GateBoss.SHOCK_RADIUS, 7.0, Color(1.0, 0.55, 0.23, 0.98))
	else:
		_draw_boss_area(center, elevation, GateBoss.RING_INNER_RADIUS, GateBoss.RING_OUTER_RADIUS, Color(1.0, 0.19, 0.12, 0.15))
		_draw_boss_ring(center, elevation, GateBoss.RING_INNER_RADIUS, 15.0, Color(0.40, 0.08, 0.04, 0.80))
		_draw_boss_ring(center, elevation + 2.0, GateBoss.RING_INNER_RADIUS, 6.0, Color(1.0, 0.76, 0.32, 0.98))
		_draw_boss_ring(center, elevation, GateBoss.RING_OUTER_RADIUS, 18.0, Color(0.40, 0.08, 0.04, 0.80))
		_draw_boss_ring(center, elevation + 2.0, GateBoss.RING_OUTER_RADIUS, 7.0, Color(1.0, 0.40, 0.20, 0.98))
	boss_warning_mesh.surface_end()


func _draw_boss_area(center: Vector2, elevation: float, inner_radius: float, outer_radius: float, color: Color) -> void:
	for i in 48:
		var a0 := TAU * float(i) / 48.0
		var a1 := TAU * float(i + 1) / 48.0
		if not _ring_segment_clear(center, a0, a1, outer_radius): continue
		var inner0 := center + Vector2.from_angle(a0) * inner_radius
		var inner1 := center + Vector2.from_angle(a1) * inner_radius
		var outer0 := center + Vector2.from_angle(a0) * outer_radius
		var outer1 := center + Vector2.from_angle(a1) * outer_radius
		for point in [inner0, outer0, outer1, inner0, outer1, inner1]:
			boss_warning_mesh.surface_set_color(color)
			boss_warning_mesh.surface_add_vertex(Vector3(point.x, elevation - 1.0, point.y) * RegionTerrain.SCALE)


func _draw_boss_ring(center: Vector2, elevation: float, radius: float, width: float, color: Color) -> void:
	for i in 48:
		var a0 := TAU * float(i) / 48.0
		var a1 := TAU * float(i + 1) / 48.0
		if not _ring_segment_clear(center, a0, a1, radius): continue
		var inner0 := center + Vector2.from_angle(a0) * (radius - width)
		var inner1 := center + Vector2.from_angle(a1) * (radius - width)
		var outer0 := center + Vector2.from_angle(a0) * radius
		var outer1 := center + Vector2.from_angle(a1) * radius
		for point in [inner0, outer0, outer1, inner0, outer1, inner1]:
			boss_warning_mesh.surface_set_color(color)
			boss_warning_mesh.surface_add_vertex(Vector3(point.x, elevation, point.y) * RegionTerrain.SCALE)


func _build_run_ui() -> void:
	var visual := MeshInstance3D.new()
	visual.mesh = boss_warning_mesh
	var material := _material(Color.WHITE, true)
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	visual.material_override = material
	add_child(visual)
	var canvas := CanvasLayer.new()
	canvas.layer = 25
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)
	run_hud = Label.new()
	run_hud.position = Vector2(28, 204)
	run_hud.add_theme_font_size_override("font_size", 18)
	run_hud.add_theme_color_override("font_color", Color("fff2c9"))
	run_hud.add_theme_color_override("font_shadow_color", Color.BLACK)
	run_hud.add_theme_constant_override("shadow_offset_x", 2)
	run_hud.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(run_hud)
	result_overlay = ColorRect.new()
	result_overlay.position = Vector2.ZERO
	result_overlay.size = Vector2(1280, 720)
	result_overlay.color = Color(0.02, 0.04, 0.05, 0.9)
	result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(result_overlay)
	result_text = Label.new()
	result_text.position = Vector2(300, 160)
	result_text.size = Vector2(680, 285)
	result_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_text.add_theme_font_size_override("font_size", 24)
	result_overlay.add_child(result_text)
	replay_button = Button.new()
	replay_button.text = "야영지로  [R]"
	replay_button.position = Vector2(475, 465)
	replay_button.size = Vector2(330, 54)
	replay_button.pressed.connect(_return_to_hub)
	result_overlay.add_child(replay_button)
	retry_button = Button.new()
	retry_button.text = "저장 재시도"
	retry_button.position = Vector2(475, 530)
	retry_button.size = Vector2(330, 54)
	retry_button.pressed.connect(_retry_settlement)
	result_overlay.add_child(retry_button)
	var quit_button := Button.new()
	quit_button.text = "게임 종료"
	quit_button.position = Vector2(475, 595)
	quit_button.size = Vector2(330, 54)
	quit_button.pressed.connect(func(): get_tree().quit())
	result_overlay.add_child(quit_button)
	result_overlay.hide()


func _return_to_hub() -> void:
	if settlement_pending or profile.load_error: return
	get_tree().paused = false
	paused = false
	get_tree().change_scene_to_file("res://game/travel_camp.tscn")


func _input(event: InputEvent) -> void:
	if practice_mode:
		super._input(event)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if run_ended:
			if event.keycode == KEY_R: _return_to_hub()
			return
		if event.keycode == KEY_R and not growth.choosing:
			_finish_run("RETREAT")
			return
		if event.keycode == KEY_G and not paused and not growth.choosing:
			_finish_run("RETREAT")
			return
	super._input(event)
