extends "res://game/hybrid_height.gd"

const RegionTerrain = preload("res://game/temple_hybrid_terrain.gd")
const ProfileScript = preload("res://game/run_profile.gd")
const AwakeningCatalog = preload("res://game/awakening_catalog.gd")
const DiagnosticsScript = preload("res://game/run_diagnostics.gd")
const TempleEnvironmentScript = preload("res://game/temple_environment_kit.gd")
const TempleSanctuaryScript = preload("res://game/temple_sanctuary_environment.gd")
const BOSS_TIME := 300.0
const MAX_ENEMIES := 72
const TempleSectionScript = preload("res://game/temple_section.gd")
var temple_section: Node
var garden_terrain_mesh: MeshInstance3D
var garden_awakening_applied := false
var temple_environment_enabled := not OS.get_cmdline_user_args().has("--temple-baseline")
var temple_environment_root: Node3D
var temple_sanctuary_enabled := not OS.get_cmdline_user_args().has("--sanctuary-baseline")
var temple_sanctuary_root: Node3D

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
var ember_step_mod_enabled := false
var ember_step_cooldown := 0.0
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
var boss_health_bar: ProgressBar
var result_overlay: ColorRect
var result_text: Label
var replay_button: Button
var retry_button: Button
var boss_warning_mesh := ImmediateMesh.new()
var echo_wisp_mod_enabled := false
var ember_strike_mod_enabled := false
var echo_wisp_fired_sequence := -1
var grotto_awakening_applied := false
var echo_grotto_fired_sequence := -1
var echo_grotto_blasts: Array[Dictionary] = []
var pause_menu: ColorRect
var build_details_label: RichTextLabel
var pause_equipment_label: RichTextLabel
var awakening_overlay: ColorRect
var awakening_receipt: RichTextLabel
var retreat_overlay: ColorRect
var retreat_was_paused := false
var ending_remaining := 0.0
var ending_visual: Node3D
var save_folder_button: Button
var diagnostics_enabled := false
var diagnostics


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
	growth.heal_on_levelup = true
	growth.permanent_combo_progression = true
	growth.compact_hud = true
	growth.hud.position = Vector2(28, 588)
	growth.xp_bar.position = Vector2(28, 622)
	growth.xp_bar.visible = true
	growth._update_hud()
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
		result_text.text = "저장 기록과 정상 백업을 읽을 수 없습니다.\n기존 파일은 보존했습니다.\n저장 폴더를 열어 백업 파일을 확인하세요."
		replay_button.disabled = true
		retry_button.hide()
		save_folder_button.show()
		result_overlay.show()
	else:
		if region_id in [RunProfile.TEMPLE_REGION, RunProfile.JUNGLE_REGION]:
			temple_section = _create_region_section()
			temple_section.setup(self)
			add_child(temple_section)
		_update_run_hud()
		if diagnostics_enabled or OS.get_cmdline_user_args().has("--run-diagnostics"):
			diagnostics = DiagnosticsScript.new()
			growth.level_healed.connect(diagnostics.record_level_heal)
			player.damage_received.connect(diagnostics.record_damage)
			growth.choice_state_changed.connect(func(): diagnostics.observe(self))
			diagnostics.observe(self)


func _create_region_section() -> Node:
	return TempleSectionScript.new()


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
	if profile.attack_branch == "DIRECT":
		player.permanent_basic_damage_bonus += 0.10
		player.moving_slash_damage_bonus += 0.10
	elif profile.attack_branch == "COMPANION":
		wisp.permanent_damage_bonus += 0.10
	if profile.equipped_weapon == "W_FLOW":
		player.flow_weave_enabled = true
		player.moving_slash_distance_multiplier = 1.20
		player.permanent_slash_cooldown_reduction += 0.10
		if profile.mod_for("W_FLOW") == "KEEN": player.moving_slash_damage_bonus += 0.04
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
		wisp.permanent_damage_bonus += 0.15
		if profile.mod_for("A_EMBER") == "BRIGHT": wisp.permanent_damage_bonus += 0.05
		elif profile.mod_for("A_EMBER") == "EMBER_STEP": ember_step_mod_enabled = true
		elif profile.mod_for("A_EMBER") == "STEADY": player.max_health += 5.0
		elif profile.mod_for("A_EMBER") == "EMBER_STRIKE": ember_strike_mod_enabled = true
	apply_garden_awakening()
	apply_grotto_awakening()
	growth._sync_wisps()
	player.health = player.max_health
	supply_ready = profile.last_launch_supply_used
	if supply_ready: player.health_changed.connect(_try_use_supply)


func is_place_discovered(id: String) -> bool:
	return profile != null and profile.discovered_places.has(id)


func apply_garden_awakening() -> void:
	if garden_awakening_applied or profile.equipped_accessory != "A_EMBER" or not profile.awakenings.has("EMBER_GARDEN"): return
	garden_awakening_applied = true
	wisp.permanent_damage_bonus += 0.20
	growth.permanent_wisp_chain_bonus = 1
	growth._sync_wisps()


func apply_grotto_awakening() -> void:
	if grotto_awakening_applied or profile.equipped_weapon != "W_ECHO" or not profile.awakenings.has("ECHO_GROTTO"): return
	grotto_awakening_applied = true


func _on_card_applied(card_id: String) -> void:
	super._on_card_applied(card_id)
	if is_instance_valid(build_details_label): build_details_label.text = growth.build_details()


func _on_player_attack_landed(point: Vector2, direction: Vector2, step: int, finisher: bool) -> void:
	super._on_player_attack_landed(point, direction, step, finisher)
	if grotto_awakening_applied and step == 4 and echo_grotto_fired_sequence != player.attack_sequence:
		echo_grotto_fired_sequence = player.attack_sequence
		echo_grotto_blasts.append({"point": player.echo_finisher_center, "delay": 0.25, "damage": SandboxPlayer.ATTACK_DAMAGE * (1.0 + player.basic_damage_bonus + player.permanent_basic_damage_bonus) * 1.5 * (1.0 + player.echo_finisher_damage_bonus) * 0.35})
	if not echo_wisp_mod_enabled or step != 4 or echo_wisp_fired_sequence == player.attack_sequence: return
	for companion in growth.wisps:
		var target := companion.find_target()
		if target != null and companion.fire_bonus_shot(target):
			echo_wisp_fired_sequence = player.attack_sequence
			break


func _on_wisp_hit(enemy: TrainingEnemy) -> void:
	super._on_wisp_hit(enemy)
	if ember_strike_mod_enabled and is_instance_valid(player): player.grant_ember_followup()
	if ember_step_mod_enabled and not run_ended and not get_tree().paused and ember_step_cooldown <= 0.0 and player.dash_charges < player.dash_max_charges:
		player.dash_cooldown = maxf(0.0, player.dash_cooldown - 0.05)
		ember_step_cooldown = 0.30


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
		if temple_section != null and temple_section.handle_death(): return
		_finish_run("DEFEAT")
		return
	if paused or growth.choosing or get_tree().paused: return
	_tick_grotto_blasts(delta)
	ember_step_cooldown = maxf(0.0, ember_step_cooldown - delta)
	run_time += delta
	if temple_section != null: temple_section.tick(delta)
	_tick_pending(delta)
	spawn_credit += _spawn_rate() * delta
	while spawn_credit >= 1.0:
		spawn_credit -= 1.0
		if _active_enemy_count() < MAX_ENEMIES:
			var point := _choose_spawn_point(false)
			if point != Vector2.INF:
				_schedule_spawn(point, _roll_role(), false)
	if temple_section == null and run_time >= BOSS_TIME and not boss_announced and not boss_spawned:
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


func _tick_grotto_blasts(delta: float) -> void:
	for i in range(echo_grotto_blasts.size() - 1, -1, -1):
		var blast := echo_grotto_blasts[i]
		blast.delay -= delta
		if blast.delay > 0.0: continue
		echo_grotto_blasts.remove_at(i)
		var center: Vector2 = blast.point
		var visual: MeshInstance3D = _sphere(0.16, Color("a7f5e8"))
		visual.position = terrain.world_point(center, 50)
		add_child(visual)
		var tween := create_tween()
		tween.tween_property(visual, "scale", Vector3.ONE * 4.0, 0.16)
		tween.tween_callback(visual.queue_free)
		for enemy in get_tree().get_nodes_in_group("training_enemies"):
			if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or not enemy is TrainingEnemy or enemy.health <= 0.0: continue
			if enemy.global_position.distance_to(center) > 90.0 + enemy.collision_radius or not clear_attack(center, enemy.global_position): continue
			var direction := center.direction_to(enemy.global_position)
			enemy.take_hit(float(blast.damage), direction, false)


func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(temple_environment_root):
		temple_environment_root.visible = temple_section == null or not temple_section.in_garden
		_update_temple_environment_visibility()
	if is_instance_valid(temple_sanctuary_root):
		temple_sanctuary_root.visible = temple_section == null or not temple_section.in_garden
		TempleSanctuaryScript.update_visibility(temple_sanctuary_root, self)
	if practice_mode: return
	if diagnostics != null: diagnostics.observe(self)
	if ending_remaining > 0.0:
		ending_remaining = maxf(0.0, ending_remaining - delta)
		if ending_remaining <= 0.0: _show_result()
	if is_instance_valid(boss) and actors.has(boss):
		var visual: Node3D = actors[boss]
		var core: MeshInstance3D = visual.get_node("BossFigure/BossCore")
		(core.material_override as StandardMaterial3D).albedo_color = Color.WHITE if boss.hit_flash > 0.0 else Color("e78363") if boss.phase == 2 else Color("b99975")
		visual.get_node("BossFigure").rotation.z = -0.15 if boss.charge_time > 0.0 else 0.10 * sin(Time.get_ticks_msec() * 0.008) if boss.warning_time > 0.0 or boss.shock_warning > 0.0 or boss.ring_warning > 0.0 else 0.0
		if boss.recovery_time > 0.0:
			visual.get_node("BossFigure").rotation.z = 0.22
			if boss.hit_flash <= 0.0: (core.material_override as StandardMaterial3D).albedo_color = Color("8ee4df")
		visual.get_node("BossFigure").rotation.x = -0.18 if boss.shock_warning > 0.0 else 0.20 if boss.impact_flash > 0.0 else 0.0
		visual.get_node("BossFigure").rotation.y = atan2(boss.locked_direction.x, boss.locked_direction.y)
		_animate_boss_arms(visual.get_node("BossFigure"))
		if boss.counter_flash > 0.0:
			visual.get_node("BossFigure").rotation.z += sin(boss.counter_flash * 65.0) * 0.13
			(core.material_override as StandardMaterial3D).albedo_color = Color("fff0bd")
	_draw_boss_warning()


func _update_temple_environment_visibility() -> void:
	if not temple_environment_root.visible or not is_instance_valid(player): return
	var spec: Dictionary = temple_environment_root.get_meta("elevated_threshold", {})
	if spec.is_empty(): return
	var targets: Array[Vector2] = [player.position]
	for actor in actors:
		if not is_instance_valid(actor) or not actor is TrainingEnemy or actor.health <= 0.0: continue
		if actor.position.distance_to(player.position) > 1500.0: continue
		var screen := camera.unproject_position(terrain.world_point(actor.position, 60))
		if get_viewport().get_visible_rect().grow(40).has_point(screen): targets.append(actor.position)
	var obscures := false
	if not overview:
		for target in targets:
			if navigation._segment_hits_rect(target, target + Vector2.ONE * float(spec.height), (spec.visual_bounds as Rect2).grow(25.0)):
				obscures = true
				break
	# Only the complete far threshold fades; other masonry/paving stays solid.
	# Alpha materials work in Compatibility, unlike instance transparency.
	for item in temple_environment_root.get_meta("threshold_meshes", []):
		var instance := item as MeshInstance3D
		if not instance.has_meta("solid_material"):
			var solid := instance.material_override as StandardMaterial3D
			var faded := solid.duplicate() as StandardMaterial3D
			faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			faded.albedo_color.a = 0.16
			instance.set_meta("solid_material", solid)
			instance.set_meta("faded_material", faded)
		instance.material_override = instance.get_meta("faded_material" if obscures else "solid_material")
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if obscures else GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _warning_strength(remaining: float, duration: float) -> float:
	# One bright finish, rather than repeated flashing; the full danger area stays visible.
	return 0.65 if remaining <= 0.10 else lerpf(0.12, 0.42, clampf(1.0 - remaining / duration, 0.0, 1.0))


func _animate_boss_arms(figure: Node3D) -> void:
	var lift := 0.0
	var spread := 0.0
	if boss.shock_warning > 0.0 or boss.ring_warning > 0.0:
		var progress := 1.0 - (boss.shock_warning / GateBoss.SHOCK_WARNING if boss.shock_warning > 0.0 else boss.ring_warning / GateBoss.RING_WARNING)
		lift = lerpf(-0.65, -2.35, progress)
		spread = 0.22
	elif boss.impact_flash > 0.0:
		lift = -0.25
	elif boss.warning_time > 0.0:
		lift = 0.65
		spread = 0.30
	elif boss.charge_time > 0.0:
		lift = -1.30
	elif boss.recovery_time > 0.0:
		lift = 0.15
		spread = 0.12
	figure.get_node("ArmLeft").rotation = Vector3(lift, 0.0, spread)
	figure.get_node("ArmRight").rotation = Vector3(lift, 0.0, -spread)


# Equal-length pressure/recovery pairs keep the scheduled spawn budget unchanged.
func _encounter_phase() -> Dictionary:
	if boss_spawned or run_time >= BOSS_TIME: return {}
	if run_time >= 60.0 and run_time < 85.0:
		return {"name": "돌진 무리 · 돌진 경로를 비켜 공격", "rate": 0.30, "weights": [50.0, 40.0, 0.0, 10.0, 0.0]}
	if run_time >= 85.0 and run_time < 110.0:
		return {"name": "숨 고르기 · 남은 적 정리", "rate": -0.30, "weights": [80.0, 10.0, 0.0, 10.0, 0.0]}
	if run_time >= 130.0 and run_time < 155.0:
		return {"name": "원거리 진형 · 뒤의 적부터 돌파", "rate": 0.30, "weights": [40.0, 15.0, 30.0, 10.0, 5.0]}
	if run_time >= 155.0 and run_time < 180.0:
		return {"name": "숨 고르기 · 남은 적 정리", "rate": -0.30, "weights": [70.0, 15.0, 5.0, 5.0, 5.0]}
	if run_time >= 210.0 and run_time < 235.0:
		return {"name": "지원 진형 · 지원 적 우선 처치", "rate": 0.35, "weights": [35.0, 20.0, 15.0, 10.0, 20.0]}
	if run_time >= 235.0 and run_time < 260.0:
		return {"name": "숨 고르기 · 보스전 준비", "rate": -0.35, "weights": [65.0, 15.0, 10.0, 5.0, 5.0]}
	return {}


func _spawn_rate() -> float:
	if temple_section != null and (temple_section.boss_active or temple_section.in_garden): return 0.0
	if boss_spawned: return 0.25
	var base := 0.60 if run_time < 45.0 else 0.85 if run_time < 120.0 else 1.10 if run_time < 200.0 else 1.40
	return (base + float(_encounter_phase().get("rate", 0.0))) * 1.5


func _roll_role() -> TrainingEnemy.Role:
	if boss_spawned or run_time < 45.0: return TrainingEnemy.Role.FRAGMENT
	var roll := rng.randf() * 100.0
	var weights := [70.0, 20.0, 0.0, 10.0, 0.0] if run_time < 120.0 else [55.0, 20.0, 10.0, 10.0, 5.0] if run_time < 200.0 else [45.0, 20.0, 15.0, 10.0, 10.0]
	weights = _encounter_phase().get("weights", weights)
	for role in 5:
		roll -= weights[role]
		if roll < 0.0: return role as TrainingEnemy.Role
	return TrainingEnemy.Role.FRAGMENT


func _active_enemy_count() -> int:
	var count := 0
	for actor in actors:
		if is_instance_valid(actor) and actor is TrainingEnemy and not actor is GateBoss and not actor.is_queued_for_deletion():
			if temple_section != null and temple_section.field_area.has_point(actor.global_position) != temple_section.in_garden: continue
			count += 1
	for entry in pending_spawns:
		if not entry.boss and (temple_section == null or not temple_section.in_garden): count += 1
	if temple_section != null and temple_section.in_garden: count += temple_section.guardian_reservations
	return count


func _choose_spawn_point(for_boss: bool) -> Vector2:
	var visible_candidate := Vector2.INF
	for attempt in 60:
		var radius := rng.randf_range(380.0, 700.0)
		var point := player.global_position + Vector2.from_angle(rng.randf_range(0.0, TAU)) * radius
		if point.x < 60.0 or point.y < 60.0 or point.x > terrain.map_size.x - 60.0 or point.y > terrain.map_size.y - 60.0: continue
		if point.distance_to(player.global_position) < (450.0 if for_boss else 380.0): continue
		if temple_section != null and temple_section.excludes_ambient_spawn(point): continue
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
	if temple_section != null and temple_section.in_garden: return
	for i in range(pending_spawns.size() - 1, -1, -1):
		var entry := pending_spawns[i]
		entry.delay = float(entry.delay) - delta
		if entry.delay > 0.0: continue
		(entry.marker as Node3D).queue_free()
		pending_spawns.remove_at(i)
		var point: Vector2 = entry.point
		if not entry.boss and temple_section != null and temple_section.excludes_ambient_spawn(point): continue
		if point.distance_to(player.global_position) >= (350.0 if entry.boss else 260.0) and navigation.is_open(point, 48.0 if entry.boss else ACTOR_CLEARANCE + 6.0) and navigation.find_path(point, player.global_position).size() >= 2:
			_spawn_now(point, entry.role, entry.boss)
		elif entry.boss:
			boss_announced = false


func _spawn_now(point: Vector2, role: TrainingEnemy.Role, for_boss: bool) -> void:
	if not for_boss:
		if temple_section != null and temple_section.excludes_ambient_spawn(point): return
		var health: float = TrainingEnemy.Definitions.ROLES[int(role)].health
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
	boss.counter_struck.connect(_on_boss_counter_struck)
	boss_spawned = true
	if diagnostics != null: diagnostics.boss_event("ready", run_time)


func _on_boss_counter_struck(point: Vector2) -> void:
	_flash(point, Color("ffe4a3"), 0.34)
	var pulse := _sphere(0.16, Color("fff0c2"))
	add_child(pulse)
	pulse.position = terrain.world_point(point, 95.0)
	var tween := create_tween()
	tween.tween_property(pulse, "scale", Vector3(4.0, 1.2, 4.0), 0.16)
	tween.parallel().tween_property(pulse, "transparency", 1.0, 0.16)
	tween.tween_callback(pulse.queue_free)


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
		var arm := Node3D.new()
		arm.name = "ArmLeft" if side < 0.0 else "ArmRight"
		arm.position = Vector3(side * 0.49, 1.20, 0.0)
		figure.add_child(arm)
		_boss_box(arm, Vector3(0.25, 0.60, 0.27), Vector3(0.0, -0.32, 0.0), Color("70645b"))
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
		if boss_defeated: return
		boss_defeated = true
		if diagnostics != null: diagnostics.boss_event("kill", run_time)
		if actors.has(enemy):
			ending_visual = actors[enemy]
			actors.erase(enemy)
			actor_motion.erase(enemy)
			var bar := ending_visual.get_node_or_null("HealthBar")
			if bar != null: bar.hide()
		return
	super._on_enemy_defeated(enemy)
	run_currency += enemy.currency_reward()


func _finish_run(result: String) -> void:
	if run_ended: return
	if diagnostics != null: diagnostics.finish(self, result)
	if temple_section != null: temple_section.retry_overlay.hide()
	run_ended = true
	end_result = result
	paused = true
	get_tree().paused = true
	for entry in pending_spawns: (entry.marker as Node3D).queue_free()
	pending_spawns.clear()
	settlement_pending = not profile.settle(run_id, result, run_currency, region_id)
	pause_menu.hide()
	retreat_overlay.hide()
	pause_label.hide()
	pause_backdrop.hide()
	growth.end_run()
	_update_hud()
	if result == "RETREAT":
		_show_result()
	else:
		ending_remaining = 0.8
		if result == "DEFEAT": ending_visual = actors[player]
		if is_instance_valid(ending_visual):
			var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tween.set_parallel(true)
			tween.tween_property(ending_visual, "rotation:z", -0.8, 0.65)
			tween.tween_property(ending_visual, "scale", Vector3(1.15, 0.12, 1.15), 0.75)
			var pulse := MeshInstance3D.new()
			var ring := TorusMesh.new()
			ring.inner_radius = 0.34
			ring.outer_radius = 0.42
			pulse.mesh = ring
			var ring_material := _material(Color("f8d38a") if result == "SUCCESS" else Color("e98484"), true)
			ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ring_material.albedo_color.a = 0.65
			pulse.material_override = ring_material
			add_child(pulse)
			pulse.position = ending_visual.position + Vector3(0, 0.04, 0)
			var pulse_tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			pulse_tween.set_parallel(true)
			pulse_tween.tween_property(pulse, "scale", Vector3(3.0, 0.3, 3.0), 0.78)
			pulse_tween.tween_property(ring_material, "albedo_color:a", 0.0, 0.78)
			pulse_tween.set_parallel(false)
			pulse_tween.tween_callback(pulse.queue_free)


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
	var next_hud := _run_hud_text()
	if run_hud.text != next_hud: run_hud.text = next_hud
	if boss_health_bar != null:
		boss_health_bar.visible = is_instance_valid(boss) and boss.health > 0.0 and (temple_section == null or temple_section.boss_active)
		if boss_health_bar.visible:
			boss_health_bar.max_value = boss.max_health
			boss_health_bar.value = boss.health


func _encounter_cue() -> String:
	if _spawn_rate() <= 0.0: return ""
	var phase := _encounter_phase()
	return String(phase.get("name", ""))


func _run_hud_text() -> String:
	var remaining := maxi(0, ceili(BOSS_TIME - run_time))
	var result := "%s까지 %02d:%02d  ·  화폐 %d" % [boss_name, remaining / 60, remaining % 60, run_currency]
	var encounter_cue := _encounter_cue()
	if not encounter_cue.is_empty(): result += "\n" + encounter_cue
	if boss_announced and not boss_spawned: result += "\n%s 등장 예고" % boss_name
	if is_instance_valid(boss) and boss.health > 0.0:
		result = "경과 %02d:%02d · 화폐 %d\n%s · %d단계" % [floori(run_time / 60.0), floori(fmod(run_time, 60.0)), run_currency, boss_name, boss.phase]
		var cue := boss.combat_cue()
		if not cue.is_empty() and (temple_section == null or not temple_section.in_garden): result += "\n" + cue
	if profile != null and profile.recovered_backup: result += "\n이전 정상 기록을 복구했습니다."
	return result


func _draw_boss_warning() -> void:
	boss_warning_mesh.clear_surfaces()
	if not is_instance_valid(boss) or (boss.shock_warning <= 0.0 and boss.ring_warning <= 0.0 and boss.impact_flash <= 0.0): return
	var center := boss.global_position
	var elevation := terrain.height_at(center) + 65.0
	boss_warning_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	if boss.shock_warning > 0.0:
		_draw_boss_area(center, elevation, 0.0, GateBoss.SHOCK_RADIUS, Color(1.0, 0.38, 0.14, _warning_strength(boss.shock_warning, GateBoss.SHOCK_WARNING)))
		_draw_boss_ring(center, elevation, GateBoss.SHOCK_RADIUS, 18.0, Color(0.43, 0.08, 0.04, 0.80))
		_draw_boss_ring(center, elevation + 2.0, GateBoss.SHOCK_RADIUS, 7.0, Color(1.0, 0.55, 0.23, 0.98))
		_draw_boss_ring(center, elevation + 3.0, GateBoss.SHOCK_RADIUS * clampf(1.0 - boss.shock_warning / GateBoss.SHOCK_WARNING, 0.03, 1.0), 5.0, Color(1.0, 0.85, 0.50, 0.9))
	elif boss.ring_warning > 0.0:
		_draw_boss_area(center, elevation, GateBoss.RING_INNER_RADIUS, GateBoss.RING_OUTER_RADIUS, Color(1.0, 0.19, 0.12, _warning_strength(boss.ring_warning, GateBoss.RING_WARNING)))
		_draw_boss_ring(center, elevation, GateBoss.RING_INNER_RADIUS, 15.0, Color(0.40, 0.08, 0.04, 0.80))
		_draw_boss_ring(center, elevation + 2.0, GateBoss.RING_INNER_RADIUS, 6.0, Color(1.0, 0.76, 0.32, 0.98))
		_draw_boss_ring(center, elevation, GateBoss.RING_OUTER_RADIUS, 18.0, Color(0.40, 0.08, 0.04, 0.80))
		_draw_boss_ring(center, elevation + 2.0, GateBoss.RING_OUTER_RADIUS, 7.0, Color(1.0, 0.40, 0.20, 0.98))
		_draw_boss_ring(center, elevation + 3.0, lerpf(GateBoss.RING_INNER_RADIUS, GateBoss.RING_OUTER_RADIUS, clampf(1.0 - boss.ring_warning / GateBoss.RING_WARNING, 0.0, 1.0)), 5.0, Color(1.0, 0.85, 0.50, 0.9))
	if boss.impact_flash > 0.0:
		var alpha: float = boss.impact_flash / 0.18
		_draw_boss_area(center, elevation + 3.0, GateBoss.RING_INNER_RADIUS if boss.impact_is_ring else 0.0, GateBoss.RING_OUTER_RADIUS if boss.impact_is_ring else GateBoss.SHOCK_RADIUS, Color(1.0, 0.75, 0.34, 0.48 * alpha))
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
	run_hud.position = Vector2(450, 24)
	run_hud.size.x = 550
	run_hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	run_hud.add_theme_font_size_override("font_size", 18)
	run_hud.add_theme_color_override("font_color", Color("fff2c9"))
	run_hud.add_theme_color_override("font_shadow_color", Color.BLACK)
	run_hud.add_theme_constant_override("shadow_offset_x", 2)
	run_hud.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(run_hud)
	boss_health_bar = ProgressBar.new()
	boss_health_bar.position = Vector2(450, 132)
	boss_health_bar.size = Vector2(500, 10)
	boss_health_bar.show_percentage = false
	boss_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var boss_fill := StyleBoxFlat.new()
	boss_fill.bg_color = Color("e49d6e")
	boss_health_bar.add_theme_stylebox_override("fill", boss_fill)
	boss_health_bar.hide()
	canvas.add_child(boss_health_bar)
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
	save_folder_button = Button.new()
	save_folder_button.text = "저장 폴더 열기"
	save_folder_button.position = Vector2(475, 530)
	save_folder_button.size = Vector2(330, 54)
	save_folder_button.pressed.connect(func(): OS.shell_open(ProjectSettings.globalize_path(profile_save_prefix).get_base_dir()))
	result_overlay.add_child(save_folder_button)
	save_folder_button.hide()
	_build_pause_menu(canvas)


func _build_pause_menu(canvas: CanvasLayer) -> void:
	pause_menu = ColorRect.new()
	pause_menu.position = Vector2(250, 70)
	pause_menu.size = Vector2(780, 570)
	pause_menu.color = Color(0.035, 0.08, 0.10, 0.98)
	canvas.add_child(pause_menu)
	var title := Label.new()
	title.text = "여행 중 · 일시정지"
	title.position = Vector2(32, 22)
	title.add_theme_font_size_override("font_size", 26)
	pause_menu.add_child(title)
	var baseline := Label.new()
	baseline.text = "장비와 각성은 영구 보유 · 카드는 이번 런에서만 유지"
	baseline.position = Vector2(32, 64)
	pause_menu.add_child(baseline)
	var pages := TabContainer.new()
	pages.position = Vector2(32, 104)
	pages.size = Vector2(716, 365)
	pause_menu.add_child(pages)
	build_details_label = _pause_page(pages, "이번 런 카드")
	pause_equipment_label = _pause_page(pages, "장비·각성")
	var controls := _pause_page(pages, "조작·상태")
	controls.text = "WASD  이동\nJ / 왼쪽 클릭  평타\nSpace  이동 베기\nShift  대시\nTab  전체 지도\nE  장소 상호작용\nG  귀환 확인\nEsc  일시정지 / 계속\n\n적 역할\n회색 추격 · 빨강 돌진 · 금빛 사격 · 청록 장판 · 보라 강화"
	var resume := Button.new()
	resume.text = "계속  [Esc]"
	resume.position = Vector2(32, 490)
	resume.size = Vector2(342, 50)
	resume.pressed.connect(func(): _set_paused(false))
	pause_menu.add_child(resume)
	var retreat := Button.new()
	retreat.text = "귀환…  [G]"
	retreat.position = Vector2(406, 490)
	retreat.size = Vector2(342, 50)
	retreat.pressed.connect(_request_retreat)
	pause_menu.add_child(retreat)
	pause_menu.hide()
	retreat_overlay = ColorRect.new()
	retreat_overlay.size = Vector2(1280, 720)
	retreat_overlay.color = Color(0.015, 0.04, 0.055, 0.97)
	canvas.add_child(retreat_overlay)
	var warning := Label.new()
	warning.text = "야영지로 귀환할까요?\n이번 런은 끝나며 획득 화폐의 20%를 잃습니다.\n최소 1개는 보존되며 손실은 올림 계산됩니다."
	warning.position = Vector2(250, 240)
	warning.size = Vector2(780, 130)
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.add_theme_font_size_override("font_size", 24)
	retreat_overlay.add_child(warning)
	var cancel := Button.new()
	cancel.name = "Cancel"
	cancel.text = "취소  [Esc]"
	cancel.position = Vector2(320, 400)
	cancel.size = Vector2(300, 55)
	cancel.pressed.connect(_cancel_retreat)
	retreat_overlay.add_child(cancel)
	var confirm := Button.new()
	confirm.text = "귀환하기"
	confirm.position = Vector2(660, 400)
	confirm.size = Vector2(300, 55)
	confirm.pressed.connect(func(): _finish_run("RETREAT"))
	retreat_overlay.add_child(confirm)
	retreat_overlay.hide()
	_build_awakening_receipt()


func _pause_page(pages: TabContainer, title: String) -> RichTextLabel:
	var margin := MarginContainer.new()
	margin.name = title
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 14)
	pages.add_child(margin)
	var label := RichTextLabel.new()
	label.add_theme_font_size_override("normal_font_size", 19)
	label.bbcode_enabled = true
	margin.add_child(label)
	return label


func _build_awakening_receipt() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 40
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)
	awakening_overlay = ColorRect.new()
	awakening_overlay.size = Vector2(1280, 720)
	awakening_overlay.color = Color(0.015, 0.04, 0.05, 0.97)
	canvas.add_child(awakening_overlay)
	awakening_receipt = RichTextLabel.new()
	awakening_receipt.position = Vector2(280, 110)
	awakening_receipt.size = Vector2(720, 440)
	awakening_receipt.add_theme_font_size_override("normal_font_size", 23)
	awakening_receipt.bbcode_enabled = true
	awakening_overlay.add_child(awakening_receipt)
	var resume := Button.new()
	resume.name = "Continue"
	resume.text = "확인 · 탐험 계속  [Esc]"
	resume.position = Vector2(430, 578)
	resume.size = Vector2(420, 58)
	resume.pressed.connect(_close_awakening_receipt)
	awakening_overlay.add_child(resume)
	awakening_overlay.hide()


func show_awakening_reward(id: String) -> void:
	if run_ended or not profile.awakenings.has(id): return
	_set_paused(true)
	pause_menu.hide()
	awakening_receipt.text = "[font_size=28][color=#f5d99c]영구 각성 획득 — %s[/color][/font_size]\n[color=#8ee4df]%s[/color]\n\n%s\n\n[font_size=18]저장 완료 · 보스에게 패배해도 유지됩니다.\n야영지 ‘발견·각성’에서 다시 확인할 수 있습니다.[/font_size]" % [AwakeningCatalog.ENTRIES[id].title, AwakeningCatalog.status(profile, id, growth.unlocks.lifetime_levelups), AwakeningCatalog.comparison(id)]
	awakening_overlay.show()
	awakening_overlay.get_node("Continue").grab_focus()


func _close_awakening_receipt() -> void:
	awakening_overlay.hide()
	_set_paused(false)


func _equipment_details() -> String:
	var lines: Array[String] = []
	for gear in [profile.equipped_weapon, profile.equipped_accessory]:
		if gear.is_empty(): continue
		var option: String = profile.mod_for(gear)
		lines.append("%s\n옵션: %s" % [RunProfile.gear_name(gear), RunProfile.affix_description(option) if not option.is_empty() else "없음"])
	return "\n\n".join(lines) + "\n\n영구 각성\n" + AwakeningCatalog.records(profile, growth.unlocks.lifetime_levelups)


func _request_retreat() -> void:
	if run_ended or growth.choosing or retreat_overlay.visible or awakening_overlay.visible or (temple_section != null and temple_section.retry_pending): return
	retreat_was_paused = paused
	_set_paused(true)
	pause_menu.hide()
	retreat_overlay.show()
	retreat_overlay.get_node("Cancel").grab_focus()


func _cancel_retreat() -> void:
	retreat_overlay.hide()
	_set_paused(retreat_was_paused)


func _set_paused(value: bool) -> void:
	if run_ended or (temple_section != null and temple_section.retry_pending): return
	super._set_paused(value)
	if diagnostics != null: diagnostics.observe(self)
	if practice_mode or pause_menu == null: return
	player.require_attack_release()
	player.dash_requested = false
	player.moving_slash_requested = false
	player.moving_slash_buffer = 0.0
	pause_label.hide()
	pause_backdrop.hide()
	pause_menu.visible = value and not retreat_overlay.visible and not awakening_overlay.visible
	if value:
		build_details_label.text = growth.build_details()
		pause_equipment_label.text = _equipment_details()


func _return_to_hub() -> void:
	if settlement_pending or profile.load_error or ending_remaining > 0.0: return
	get_tree().paused = false
	paused = false
	get_tree().change_scene_to_file("res://game/travel_camp.tscn")


func _input(event: InputEvent) -> void:
	if awakening_overlay != null and awakening_overlay.visible:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE: _close_awakening_receipt()
		# Leave mouse/keyboard focus activation to the receipt's own button.
		return
	if temple_section != null and temple_section.handle_input(event): return
	if temple_section != null and temple_section.retry_pending: return
	if practice_mode:
		super._input(event)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if run_ended:
			if event.keycode == KEY_R: _return_to_hub()
			return
		if retreat_overlay.visible:
			if event.keycode == KEY_ESCAPE:
				_cancel_retreat()
				get_viewport().set_input_as_handled()
			# Tab/Enter/Space must reach the modal's focused buttons.
			# Returning here still prevents underlying run hotkeys.
			return
		if event.keycode == KEY_R:
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_G and not growth.choosing:
			_request_retreat()
			get_viewport().set_input_as_handled()
			return
	super._input(event)


func region_layout():
	return TempleSectionScript.Garden


func set_main_decor_visible(_value: bool) -> void:
	pass


func display_bounds() -> Rect2:
	var layout = region_layout()
	return layout.FIELD_BOUNDS if temple_section != null and temple_section.in_garden else layout.MAIN_BOUNDS


func _build_terrain(render_bounds := Rect2()) -> void:
	var layout = region_layout()
	var use_temple_kit := region_id == RunProfile.TEMPLE_REGION and temple_environment_enabled
	var use_sanctuary := use_temple_kit and temple_sanctuary_enabled
	if region_id == RunProfile.TEMPLE_REGION:
		for wall in terrain.wall_areas:
			if TempleEnvironmentScript.replaces_wall(wall): wall["visual"] = not use_temple_kit
			if TempleSanctuaryScript.replaces_wall(wall): wall["visual"] = not use_sanctuary
	super._build_terrain(layout.MAIN_BOUNDS)
	var main_mesh := terrain_mesh
	var main_faces := resolved_vertical_faces.duplicate(true)
	var main_lips := resolved_lips.duplicate(true)
	super._build_terrain(layout.FIELD_BOUNDS)
	garden_terrain_mesh = terrain_mesh
	garden_terrain_mesh.hide()
	terrain_mesh = main_mesh
	resolved_vertical_faces = main_faces
	resolved_lips = main_lips
	if use_temple_kit:
		temple_environment_root = TempleEnvironmentScript.build(self)
		add_child(temple_environment_root)
	if use_sanctuary:
		temple_sanctuary_root = TempleSanctuaryScript.build(self)
		add_child(temple_sanctuary_root)
