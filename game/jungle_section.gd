extends "res://game/temple_section.gd"

const Grotto = preload("res://game/jungle_grotto_layout.gd")
var wave := 0
var wave_kills := 0
var wave_markers: Array[Dictionary] = []
var counted_guards := {}
var started_waves := {}

func _init() -> void:
	layout = Grotto
	field_area = Grotto.FIELD_BOUNDS
	boss_area = Rect2(4320, 520, 880, 1450)
	boss_point = Vector2(4750, 850)
	retry_point = Vector2(4740, 1400)
	boss_spawn_points = [boss_point, Vector2(4800, 1650), Vector2(4700, 1100)]
	destination_point = Vector2(4320, 1120)


func _destination_place_name() -> String:
	return "관문"


func _tick_garden(delta: float) -> void:
	discovery_retry = maxf(0.0, discovery_retry - delta)
	if in_garden and not arena.is_place_discovered("JUNGLE_GROTTO") and discovery_retry <= 0.0:
		discovery_retry = 1.0
		if not arena.profile.discover_place("JUNGLE_GROTTO"):
			garden_message = "계곡 발견 저장 실패 · 기록을 보존하고 재시도 중"
		else:
			garden_message = "폭포 뒤 숨은 계곡 발견"
	if not in_garden: return
	if not started_waves.has(1) and arena.player.global_position.distance_to(Grotto.FIRST_APPROACH) < 620.0:
		_start_wave(1)
	if not started_waves.has(2) and arena.player.global_position.distance_to(Grotto.SECOND_APPROACH) < 720.0:
		_start_wave(2)
	for i in range(wave_markers.size() - 1, -1, -1):
		var entry := wave_markers[i]
		if arena.player.global_position.distance_to(entry.point) > 740.0: continue
		entry.delay -= delta
		if entry.delay > 0.0 or arena.player.global_position.distance_to(entry.point) < 145.0: continue
		var enemy: TrainingEnemy = arena._spawn_enemy_at(entry.point, entry.role, TrainingEnemy.Definitions.ROLES[entry.role].health * 2.4)
		enemy.arena_bounds = entry.area
		enemy.defeated.connect(_on_guard_defeated.bind(enemy))
		entry.marker.queue_free()
		wave_markers.remove_at(i)
		guardian_reservations -= 1
	altar_label.visible = in_garden and arena.player.global_position.distance_to(layout.ALTAR) < 600.0
	altar_ember.visible = altar_label.visible
	altar_label.text = "계곡 안쪽 유적\nE · 보상 받기" if not garden_claimed else "계곡 안쪽 유적\n이번 런 보상 완료"


func _start_wave(number: int) -> void:
	if started_waves.has(number): return
	started_waves[number] = true
	wave = number
	guardian_reservations += 3
	var points: Array = Grotto.FIRST_WAVE if number == 1 else Grotto.SECOND_WAVE
	var roles: Array = [TrainingEnemy.Role.BEAST, TrainingEnemy.Role.LAMP, TrainingEnemy.Role.FRAGMENT] if number == 1 else [TrainingEnemy.Role.ZONE, TrainingEnemy.Role.SUPPORT, TrainingEnemy.Role.BEAST]
	for i in 3:
		var marker: MeshInstance3D = arena._sphere(0.20, Color("9debe5"))
		marker.position = arena.terrain.world_point(points[i], 20)
		add_child(marker)
		wave_markers.append({"point": points[i], "role": roles[i], "delay": 0.8, "marker": marker, "area": Grotto.FIRST_WAVE_AREA if number == 1 else Grotto.SECOND_WAVE_AREA})
	garden_message = "물길 수호 무리 접근" if number == 1 else "안쪽 유적 수호 무리 접근"


func _on_guard_defeated(enemy: TrainingEnemy) -> void:
	var id := enemy.get_instance_id()
	if counted_guards.has(id): return
	counted_guards[id] = true
	wave_kills += 1


func claim_garden_reward() -> bool:
	if not in_garden or arena.run_ended or retry_pending or get_tree().paused or arena.player.health <= 0.0 or garden_claimed or arena.player.global_position.distance_to(layout.ALTAR) > 105.0: return false
	var already_awakened: bool = arena.profile.awakenings.has("ECHO_GROTTO")
	if not arena.profile.claim_grotto_awakening():
		garden_message = "각성 저장 실패 · 지급하지 않았습니다. E로 재시도"
		_update_hud()
		return false
	garden_claimed = true
	if already_awakened:
		arena.growth._heal(0.20)
		garden_message = "계곡 재방문 · HP 20% 회복 (이번 런 1회)"
	else:
		arena.apply_grotto_awakening()
		garden_message = "계곡 각성 저장 완료 · 집결의 마력장 4타 후 작은 추가 폭발"
		if arena.profile.equipped_weapon != "W_ECHO": garden_message += "\n야영지에서 집결의 마력장을 구매·장착하면 적용됩니다."
		arena.show_awakening_reward("ECHO_GROTTO")
	_update_hud()
	return true


func handle_input(event: InputEvent) -> bool:
	if retry_pending: return true
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E and not arena.run_ended and not get_tree().paused and arena.player.global_position.distance_to(layout.ALTAR) <= 105.0:
		claim_garden_reward()
		get_viewport().set_input_as_handled()
		return true
	return false


func _update_hud() -> void:
	section_hud.text = "관문 수호자 · 4분 이후 관문 안쪽에 접근하여 교전"
	if boss_ready: section_hud.text = "관문 수호자가 깨어났습니다 · 관문 안쪽으로"
	if boss_entered:
		section_hud.text = ("관문 교전 중" if boss_active else "관문 밖 · 보스 대기 / HP 유지") + "\n보스전 재도전 " + ("사용 완료" if retry_used else "1회 남음") + " · 출입 자유"
	if in_garden:
		section_hud.text = "물길 너머 안쪽 유적 탐색\n길목 적은 돌파하거나 피해 갈 수 있습니다." if not garden_claimed else "유적 보상 획득 · 들어온 물길로 복귀"
	if garden_message.contains("실패"): section_hud.text += "\n" + garden_message


func _build_garden() -> void:
	_build_hidden_roots()
	hidden_visual_root.add_child(preload("res://game/jungle_hidden_sanctuary.gd").build(arena, layout))
	altar_label = Label3D.new()
	altar_label.font_size = 27
	altar_label.pixel_size = 0.006
	altar_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	altar_label.position = arena.terrain.world_point(layout.ALTAR, 150)
	altar_label.hide()
	hidden_visual_root.add_child(altar_label)
	altar_ember = arena._sphere(0.18, Color("b0e9f3"))
	altar_ember.position = arena.terrain.world_point(layout.ALTAR, 50)
	altar_ember.hide()
	hidden_visual_root.add_child(altar_ember)
	_build_exit_label()


func _hidden_place_id() -> String: return "JUNGLE_GROTTO"
func _hidden_place_name() -> String: return "계곡"
func _hidden_return_name() -> String: return "정글로"
func _hidden_marker_color() -> Color: return Color("a1e8e7")


func _build_entry_clues() -> void:
	main_entry_root.add_child(preload("res://game/jungle_hidden_sanctuary.gd").build_entry(arena, layout))
