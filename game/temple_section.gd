extends Node

const BOSS_AREA := Rect2(4050, 580, 850, 940)
const BOSS_POINT := Vector2(4520, 1050)
const RETRY_POINT := Vector2(4160, 1100)
const Garden = preload("res://game/temple_garden_layout.gd")
const GARDEN_AREA := Garden.FIELD_BOUNDS
const ALTAR_POINT := Garden.ALTAR
const GUARD_POINTS := Garden.GUARDS
var in_garden := false
var portal_cooldown := 0.0
var sleeping_actors: Dictionary = {}
var main_overview_size := 0.0
var transition_shade: ColorRect

var boss_active := false
var spawn_warning_time := -1.0
var spawn_marker: MeshInstance3D
var destination_spawn := BOSS_POINT
var guardian_reservations := 0
var garden_started := false
var garden_claimed := false
var guardians_defeated := 0
var guard_warnings: Array[Dictionary] = []
var discovery_retry := 0.0
var garden_message := ""
var altar_label: Label3D
var altar_ember: MeshInstance3D

var arena
var boss_ready := false
var boss_entered := false
var retry_used := false
var retry_pending := false
var retry_overlay: ColorRect
var section_hud: Label
var boundary_visual: Node3D
var destination_label: Label3D

# Region-specific geometry; constants above remain the temple test contract.
var layout = Garden
var field_area := GARDEN_AREA
var boss_area := BOSS_AREA
var boss_point := BOSS_POINT
var retry_point := RETRY_POINT
var boss_spawn_points := [BOSS_POINT, Vector2(4620, 780), Vector2(4610, 1330), Vector2(4200, 790)]
var destination_point := Vector2(4090, 1100)


func setup(scene) -> void:
	arena = scene


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_destination()
	_build_garden()
	_build_ui()
	arena.player.arena_bounds = layout.MAIN_BOUNDS
	main_overview_size = arena.overview_camera_size


func tick(delta: float) -> void:
	if arena.run_ended or retry_pending: return
	portal_cooldown = maxf(0.0, portal_cooldown - delta)
	if portal_cooldown <= 0.0:
		if not in_garden and layout.ENTRY_TRIGGER.has_point(arena.player.global_position): enter_garden()
		elif in_garden and layout.EXIT_TRIGGER.has_point(arena.player.global_position): leave_garden()
	if arena.run_time >= arena.BOSS_TIME and not arena.boss_spawned:
		if spawn_warning_time < 0.0:
			for point in boss_spawn_points:
				if arena.navigation.is_open(point, 48.0) and arena.player.global_position.distance_to(point) >= 250.0:
					destination_spawn = point
					break
			arena.boss_announced = true
			spawn_warning_time = 1.2
			spawn_marker = arena._sphere(0.40, Color("ffb36b"))
			spawn_marker.position = arena.terrain.world_point(destination_spawn, 30)
			add_child(spawn_marker)
		else:
			spawn_warning_time = maxf(0.0, spawn_warning_time - delta)
			if spawn_warning_time <= 0.0 and arena.player.global_position.distance_to(destination_spawn) >= 140.0:
				spawn_marker.queue_free()
				arena._spawn_now(destination_spawn, TrainingEnemy.Role.BEAST, true)
				arena.boss.arena_bounds = boss_area
				arena.boss.encounter_area = boss_area
				arena.boss.suspend_encounter()
				arena.boss.remove_from_group("training_enemies")
				boss_ready = true
	if boss_ready and is_instance_valid(arena.boss):
		var inside := boss_area.has_point(arena.player.global_position)
		if inside != boss_active:
			boss_active = inside
			_clear_transients()
			if inside:
				boss_entered = true
				arena.boss.encounter_active = true
				arena.boss.add_to_group("training_enemies")
			else:
				arena.boss.suspend_encounter()
				arena.boss.remove_from_group("training_enemies")
		if boss_active: _clear_arena_intruders()
	_sync_field_actors()
	_tick_garden(delta)
	destination_label.visible = arena.player.global_position.distance_to(destination_point) < 650.0
	destination_label.text = "성소 · 문지기의 영역\n" + ("경계 진입 시 교전 · 출입 자유" if boss_ready else "5분 이후 접근하여 교전")
	_update_hud()


func excludes_ambient_spawn(point: Vector2) -> bool:
	return in_garden or not layout.MAIN_BOUNDS.has_point(point) or field_area.grow(40).has_point(point) or (boss_ready and boss_area.grow(100).has_point(point))


func _clear_arena_intruders() -> void:
	for actor in arena.actors.keys():
		if is_instance_valid(actor) and actor is TrainingEnemy and actor != arena.boss and boss_area.grow(100).has_point(actor.global_position):
			_remove_actor(actor)
	for group in ["enemy_bolts", "enemy_zones"]:
		for node in get_tree().get_nodes_in_group(group):
			if arena.simulation.is_ancestor_of(node): node.queue_free()


func _tick_garden(delta: float) -> void:
	discovery_retry = maxf(0.0, discovery_retry - delta)
	if in_garden and field_area.has_point(arena.player.global_position):
		if not arena.is_place_discovered("TEMPLE_GARDEN") and discovery_retry <= 0.0:
			discovery_retry = 1.0
			if not arena.profile.discover_garden():
				garden_message = "정원 발견 저장 실패 · 기록을 보존하고 재시도 중"
			else:
				garden_message = "숨은 정원 발견 · 수호 적 3명을 정리하세요"
		if not garden_started:
			garden_started = true
			guardian_reservations = 3
			for i in 3:
				var mark: MeshInstance3D = arena._sphere(0.20, Color("ffdb92"))
				mark.position = arena.terrain.world_point(GUARD_POINTS[i], 20)
				add_child(mark)
				guard_warnings.append({"point": GUARD_POINTS[i], "delay": 1.0, "index": i, "marker": mark})
	if not in_garden: return
	for i in range(guard_warnings.size() - 1, -1, -1):
		var entry := guard_warnings[i]
		if arena.player.global_position.distance_to(entry.point) > 760.0: continue
		entry.delay -= delta
		if entry.delay > 0.0 or arena.player.global_position.distance_to(entry.point) < 140.0: continue
		var role: int = [TrainingEnemy.Role.BEAST, TrainingEnemy.Role.LAMP, TrainingEnemy.Role.ZONE][entry.index]
		var enemy: TrainingEnemy = arena._spawn_enemy_at(entry.point, role, TrainingEnemy.Definitions.ROLES[role].health * 3.0)
		enemy.arena_bounds = layout.GUARD_AREAS[entry.index]
		enemy.defeated.connect(func(): guardians_defeated += 1)
		entry.marker.queue_free()
		guard_warnings.remove_at(i)
		guardian_reservations -= 1
	altar_label.visible = in_garden and arena.player.global_position.distance_to(ALTAR_POINT) < 600.0
	altar_ember.visible = altar_label.visible
	altar_label.text = "정원의 불씨\n수호 적 %d / 3" % guardians_defeated if guardians_defeated < 3 else "정원의 불씨\nE · 보상 받기" if not garden_claimed else "정원의 불씨\n이번 런 보상 완료"


func claim_garden_reward() -> bool:
	if not in_garden or arena.run_ended or retry_pending or get_tree().paused or arena.player.health <= 0.0 or garden_claimed or guardians_defeated < 3 or arena.player.global_position.distance_to(ALTAR_POINT) > 105.0: return false
	var already_awakened: bool = arena.profile.awakenings.has("EMBER_GARDEN")
	if not arena.profile.claim_garden_awakening():
		garden_message = "각성 저장 실패 · 지급하지 않았습니다. E로 재시도"
		_update_hud()
		return false
	garden_claimed = true
	if already_awakened:
		arena.growth._heal(0.20)
		garden_message = "정원 재방문 · HP 20% 회복 (이번 런 1회)"
	else:
		arena.apply_garden_awakening()
		garden_message = "정원 각성 저장 완료 · 여우불 장신구 마탄 +20%p / 연쇄 +1"
		if arena.profile.equipped_accessory != "A_EMBER": garden_message += "\n야영지에서 여우불 장신구를 구매·장착하면 적용됩니다."
		arena.show_awakening_reward("EMBER_GARDEN")
	_update_hud()
	return true


func handle_input(event: InputEvent) -> bool:
	if retry_pending: return true
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E and not arena.run_ended and not get_tree().paused and arena.player.global_position.distance_to(ALTAR_POINT) <= 105.0:
		claim_garden_reward()
		get_viewport().set_input_as_handled()
		return true
	return false


func handle_death() -> bool:
	if retry_pending: return true
	if retry_used or not boss_entered or not boss_area.has_point(arena.player.global_position): return false
	retry_pending = true
	arena.paused = true
	get_tree().paused = true
	arena.pause_menu.hide()
	arena.retreat_overlay.hide()
	arena.growth.overlay.hide()
	retry_overlay.show()
	retry_overlay.get_node("Retry").grab_focus()
	return true


func retry_boss() -> void:
	if not retry_pending or retry_used or arena.run_ended: return
	retry_used = true
	retry_pending = false
	retry_overlay.hide()
	_clear_transients()
	_clear_arena_intruders()
	if is_instance_valid(arena.boss):
		_remove_actor(arena.boss)
	arena.boss_defeated = false
	arena.death_pending = false
	arena.player.restore_for_boss_retry()
	arena.teleport(retry_point)
	arena._spawn_now(boss_point, TrainingEnemy.Role.BEAST, true)
	arena.boss.arena_bounds = boss_area
	arena.boss.encounter_area = boss_area
	boss_active = true
	arena.boss.attack_cooldown = 1.0
	arena.ember_step_cooldown = 0.0
	arena._set_paused(false)
	if arena.growth.choosing:
		arena.growth.paused_before_choice = false
		arena.growth.overlay.show()
		get_tree().paused = true
	_update_hud()


func decline_retry() -> void:
	if not retry_pending: return
	retry_pending = false
	retry_overlay.hide()
	arena._finish_run("DEFEAT")


func _remove_actor(actor: Node) -> void:
	if arena.actors.has(actor):
		arena.actors[actor].queue_free()
		arena.actors.erase(actor)
	arena.actor_motion.erase(actor)
	actor.remove_from_group("training_enemies")
	actor.set_physics_process(false)
	actor.queue_free()


func _clear_transients() -> void:
	arena.echo_grotto_blasts.clear()
	for group in ["enemy_bolts", "enemy_zones", "wisp_projectiles"]:
		for node in get_tree().get_nodes_in_group(group):
			if arena.simulation.is_ancestor_of(node): node.queue_free()
	if arena.growth.seal != null:
		arena.growth.seal.telegraph = 0.0
		arena.growth.seal.burst_time = 0.0


func _update_hud() -> void:
	section_hud.text = "성소의 문지기 · 5분 이후 성소에 접근하여 교전"
	if boss_ready:
		section_hud.text = "성소의 문지기가 깨어났습니다 · 동쪽 성소로"
	if boss_entered:
		section_hud.text = ("성소 교전 중" if boss_active else "성소 밖 · 보스 대기 / HP 유지") + "\n보스전 재도전 " + ("사용 완료" if retry_used else "1회 남음") + " · 출입 자유 / 보스 HP 유지"

	if in_garden:
		section_hud.text = "숨은 정원 · 수호 적 %d / 3 · 안쪽 제단으로" % guardians_defeated
		section_hud.text += "\n서쪽 입구로 회랑 복귀"
	if garden_message.contains("실패"): section_hud.text += "\n" + garden_message


func _build_destination() -> void:
	boundary_visual = Node3D.new()
	add_child(boundary_visual)
	for rect in [Rect2(boss_area.position, Vector2(boss_area.size.x, 8)), Rect2(Vector2(boss_area.position.x, boss_area.end.y - 8), Vector2(boss_area.size.x, 8)), Rect2(boss_area.position, Vector2(8, boss_area.size.y)), Rect2(Vector2(boss_area.end.x - 8, boss_area.position.y), Vector2(8, boss_area.size.y))]:
		var mark := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(rect.size.x * 0.01, 0.025, rect.size.y * 0.01)
		mark.mesh = box
		mark.material_override = arena._material(Color("d8b86a"), true)
		mark.position = arena.terrain.world_point(rect.get_center(), 8.0)
		boundary_visual.add_child(mark)
	var title := Label3D.new()
	destination_label = title
	title.text = "성소 · 문지기의 영역\n5분 이후 접근하여 교전"
	title.font_size = 34
	title.pixel_size = 0.006
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.position = arena.terrain.world_point(destination_point, 200)
	boundary_visual.add_child(title)


func _build_garden() -> void:
	# Separate garden field: bent entry, pond forks, and a distant altar.
	for point in [Vector2(5860, 1770), Vector2(6100, 1770), Vector2(6320, 1600), Vector2(6320, 1250), Vector2(6650, 550), Vector2(7000, 550), Vector2(7500, 550), Vector2(6800, 1560), Vector2(7300, 1560), Vector2(7950, 1500), Vector2(8020, 920), Vector2(8200, 490)]:
		var stone := MeshInstance3D.new()
		var slab := BoxMesh.new()
		slab.size = Vector3(0.85, 0.035, 0.65)
		stone.mesh = slab
		stone.material_override = arena._material(Color("c5c7a7"))
		stone.position = arena.terrain.world_point(point, 5)
		stone.rotation.y = 0.3
		add_child(stone)
	for point in [Vector2(2990, 350), Vector2(3040, 155), Vector2(5940, 1640), Vector2(6070, 1910), Vector2(6250, 330), Vector2(6660, 350), Vector2(6840, 720), Vector2(7500, 730), Vector2(7640, 1320), Vector2(6920, 1410), Vector2(7630, 1870), Vector2(8230, 1850), Vector2(8420, 730), Vector2(8050, 260)]:
		var bush: MeshInstance3D = arena._sphere(0.65, Color("4d835c"))
		bush.position = arena.terrain.world_point(point, 45)
		bush.scale = Vector3(1.3, 0.9, 1.0)
		add_child(bush)
	var exit_label := Label3D.new()
	exit_label.text = "회랑으로"
	exit_label.font_size = 28
	exit_label.pixel_size = 0.006
	exit_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	exit_label.position = arena.terrain.world_point(layout.EXIT_TRIGGER.get_center(), 90)
	add_child(exit_label)
	var altar := MeshInstance3D.new()
	var base := CylinderMesh.new()
	base.top_radius = 0.38
	base.bottom_radius = 0.50
	base.height = 0.28
	altar.mesh = base
	altar.material_override = arena._material(Color("c7c9a1"))
	altar.position = arena.terrain.world_point(ALTAR_POINT, 15)
	add_child(altar)
	var ember: MeshInstance3D = arena._sphere(0.18, Color("b0f3b0"))
	altar_ember = ember
	ember.visible = false
	ember.position = arena.terrain.world_point(ALTAR_POINT, 55)
	add_child(ember)
	altar_label = Label3D.new()
	altar_label.font_size = 27
	altar_label.pixel_size = 0.006
	altar_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	altar_label.position = arena.terrain.world_point(ALTAR_POINT, 140)
	altar_label.visible = false
	add_child(altar_label)


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 35
	add_child(canvas)
	section_hud = Label.new()
	section_hud.position = Vector2(28, 138)
	section_hud.size.x = 380
	section_hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section_hud.add_theme_font_size_override("font_size", 17)
	section_hud.add_theme_color_override("font_shadow_color", Color.BLACK)
	section_hud.add_theme_constant_override("shadow_offset_x", 2)
	section_hud.add_theme_constant_override("shadow_offset_y", 2)
	# Ordinary HUD stays below modal choices.
	var hud_canvas := CanvasLayer.new()
	hud_canvas.layer = 21
	add_child(hud_canvas)
	hud_canvas.add_child(section_hud)
	retry_overlay = ColorRect.new()
	retry_overlay.size = Vector2(1280, 720)
	retry_overlay.color = Color(0.015, 0.035, 0.045, 0.97)
	canvas.add_child(retry_overlay)
	var label := Label.new()
	label.position = Vector2(180, 190)
	label.size = Vector2(920, 190)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = "한 번 더 도전할까요?\n같은 카드·레벨·획득 화폐를 유지합니다.\n내 체력과 보스 체력은 전부 회복합니다.\n사용한 소모품은 돌아오지 않습니다."
	label.add_theme_font_size_override("font_size", 25)
	retry_overlay.add_child(label)
	var retry := Button.new()
	retry.name = "Retry"
	retry.text = "보스 재도전 · 이번 런 1회"
	retry.position = Vector2(300, 420)
	retry.size = Vector2(330, 60)
	retry.pressed.connect(retry_boss)
	retry_overlay.add_child(retry)
	var leave := Button.new()
	leave.text = "이번 런 종료 · 사망 정산"
	leave.position = Vector2(650, 420)
	leave.size = Vector2(330, 60)
	leave.pressed.connect(decline_retry)
	retry_overlay.add_child(leave)
	retry_overlay.hide()


func enter_garden() -> void:
	if in_garden or arena.run_ended or retry_pending or get_tree().paused: return
	_set_field(true)


func leave_garden() -> void:
	if not in_garden or arena.run_ended or retry_pending or get_tree().paused: return
	_set_field(false)


func _set_field(value: bool) -> void:
	_clear_transients()
	in_garden = value
	portal_cooldown = 0.8
	arena.terrain_mesh.visible = not value
	arena.garden_terrain_mesh.visible = value
	arena.set_main_decor_visible(not value)
	boundary_visual.visible = not value
	arena.player.arena_bounds = layout.FIELD_BOUNDS if value else layout.MAIN_BOUNDS
	arena.overview_camera_size = maxf(37.0, layout.FIELD_BOUNDS.size.x * 0.012) if value else main_overview_size
	arena.overview = false
	arena.camera.size = arena.combat_camera_size
	arena.teleport(layout.FIELD_ENTRY if value else layout.RETURN_POINT)
	altar_label.visible = false
	altar_ember.visible = false
	_sync_field_actors()
	if transition_shade == null:
		transition_shade = ColorRect.new()
		transition_shade.color = Color("263e3d")
		transition_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		transition_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		section_hud.get_parent().add_child(transition_shade)
	transition_shade.modulate.a = 1.0
	create_tween().tween_property(transition_shade, "modulate:a", 0.0, 0.25)
	_update_hud()


func _sync_field_actors() -> void:
	for actor in sleeping_actors.keys():
		if not is_instance_valid(actor): sleeping_actors.erase(actor)
	for actor in arena.actors:
		if not is_instance_valid(actor) or not actor is TrainingEnemy or actor.is_queued_for_deletion(): continue
		var on_field := field_area.has_point(actor.global_position) == in_garden
		arena.actors[actor].visible = on_field
		if not on_field and not sleeping_actors.has(actor):
			sleeping_actors[actor] = {"mode": actor.process_mode, "group": actor.is_in_group("training_enemies")}
			actor.process_mode = Node.PROCESS_MODE_DISABLED
			actor.remove_from_group("training_enemies")
		elif on_field and sleeping_actors.has(actor):
			var state: Dictionary = sleeping_actors[actor]
			actor.process_mode = state.mode
			if state.group: actor.add_to_group("training_enemies")
			sleeping_actors.erase(actor)
