class_name RunGrowth
extends Node

signal card_applied(card_id: String)

const WispScript = preload("res://game/wisp.gd")
const SealScript = preload("res://game/seal_attack.gd")

const CARDS := {
	"U_EDGE": {"name": "마력 날", "detail": "평타 피해 +15%", "max": 3, "group": "BASIC"},
	"U_TEMPO": {"name": "빠른 손짓", "detail": "평타 공격 속도 +12%", "max": 3, "group": "BASIC"},
	"U_REACH": {"name": "넓은 궤적", "detail": "평타 범위 +15%", "max": 3, "group": "BASIC"},
	"U_CHAIN": {"name": "연속 손짓", "detail": "3타, 다음 등급에서 4타 해금", "max": 2, "group": "BASIC"},
	"S_WISP_DAMAGE": {"name": "여우불 화력", "detail": "마탄 피해 계수 +0.20·적중 충격 강화", "max": 3, "group": "AUTO"},
	"S_WISP_CADENCE": {"name": "빠른 여우불", "detail": "발사 간격 -10%", "max": 3, "group": "AUTO"},
	"S_WISP_COUNT": {"name": "여우불 분화", "detail": "여우불 +1, 최대 3개", "max": 2, "group": "AUTO"},
	"S_WISP_ORBIT": {"name": "회전 불꽃", "detail": "마탄을 유지하며 회전 접촉 피해", "max": 2, "group": "AUTO"},
	"S_WISP_CHAIN": {"name": "연쇄 불꽃", "detail": "마탄 명중 후 가까운 적에게 연쇄", "max": 2, "group": "AUTO"},
	"S_WISP_FOLLOWUP": {"name": "베기 뒤 불꽃", "detail": "평타 적중 후 여우불 발사 대기 단축", "max": 2, "group": "AUTO"},
	"S_WISP_SWEEP": {"name": "베기에 실린 불꽃", "detail": "이동 베기 적중 시 여우불 대기 단축", "max": 2, "group": "AUTO"},
	"S_WISP_REPLY": {"name": "불꽃의 응답", "detail": "여우불 적중 후 이동 베기 재사용 단축", "max": 2, "group": "AUTO"},
	"S_SEAL": {"name": "자동 마력진", "detail": "가까운 적에게 예고 후 범위 공격", "max": 3, "group": "AUTO"},
	"U_STEP": {"name": "민첩한 대시", "detail": "대시 충전 강화", "max": 3, "group": "DASH"},
	"U_SLASH_SWEEP": {"name": "넓은 이동 베기", "detail": "이동 베기가 더 넓게 적을 쓸어냅니다", "max": 2, "group": "BASIC"},
	"U_SLASH_CADENCE": {"name": "이어지는 이동 베기", "detail": "이동 베기를 더 자주 사용합니다", "max": 2, "group": "BASIC"},
}

var arena: Node2D
var player: SandboxPlayer
var wisps: Array[WispCompanion] = []
var seal: SealAttack
var unlocks := UnlockProgress.new()
var rng := RandomNumberGenerator.new()
var level := 1
var xp := 0
var pending_choices := 0
var heal_on_levelup := false
var points_earned := 0
var points_spent := 0
var exhausted_points := 0
var choice_windows_opened := 0
var growth_ended := false
var paused_before_choice := false
var last_choice_label: Label
var card_ranks: Dictionary = {}
var selected_card_ranks: Dictionary = {}
var current_choices: Array[String] = []
var choosing := false
var hud: Label
var overlay: ColorRect
var choice_title: Label
var choice_buttons: Array[Button] = []
var reroll_button: Button
var rerolls_left := 0
var unlock_notice := ""
var basic_speed_base := 0.0
var hud_position := Vector2(20, 104)
var permanent_combo_progression := false
var compact_hud := false
var xp_bar: ProgressBar
var permanent_wisp_cadence_reduction := 0.0
var permanent_wisp_chain_bonus := 0.0
var last_followup_attack := -1
var last_followup_slash := -1


func setup(battle: Node2D, actor: SandboxPlayer, starting_wisp: WispCompanion) -> void:
	arena = battle
	player = actor
	wisps.append(starting_wisp)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	unlocks.load_progress()
	_build_ui()
	if is_instance_valid(player):
		player.attack_landed.connect(_on_player_attack_landed)
		player.moving_slash_landed.connect(_on_player_slash_landed)
	for wisp in wisps:
		_connect_wisp(wisp)
	_update_hud()


func next_xp() -> int:
	return 8 + 2 * (level - 1)


func on_enemy_defeated(enemy: TrainingEnemy) -> void:
	gain_xp(enemy.xp_reward())


func gain_xp(amount: int) -> void:
	if amount <= 0 or growth_ended:
		return
	unlock_notice = ""
	xp += amount
	while xp >= next_xp():
		xp -= next_xp()
		level += 1
		pending_choices += 1
		points_earned += 1
		if heal_on_levelup: _heal(0.20)
		var newly_unlocked := unlocks.add_levelup()
		if not newly_unlocked.is_empty():
			var names: Array[String] = []
			for card_id in newly_unlocked:
				names.append(CARDS[card_id].name)
			unlock_notice = "새 카드 해금: " + ", ".join(names)
	if permanent_combo_progression: _sync_permanent_moves()
	_update_hud()
	if choosing:
		_refresh_choices()
	elif pending_choices > 0:
		_start_choice()


func _sync_permanent_moves() -> void:
	var lifetime := unlocks.lifetime_levelups
	var desired_rank := 2 if lifetime >= 3 else 1 if lifetime >= 1 else 0
	if player.combo_rank != desired_rank: player.set_combo_rank(desired_rank)
	player.moving_slash_enabled = lifetime >= 1


func _start_choice() -> void:
	if pending_choices <= 0 or growth_ended or choosing:
		return
	paused_before_choice = get_tree().paused
	last_choice_label.text = ""
	_prepare_next_choice()
	if current_choices.is_empty():
		return
	choice_windows_opened += 1
	choosing = true
	get_tree().paused = true
	overlay.show()
	_refresh_choices()


func _prepare_next_choice() -> void:
	current_choices.clear()
	if pending_choices > 0: current_choices = roll_choices()
	rerolls_left = 1
	# No recursive UI openings when the whole card pool is exhausted.
	if pending_choices > 0 and current_choices.is_empty():
		if not heal_on_levelup:
			_heal(0.20 * pending_choices)
		exhausted_points += pending_choices
		pending_choices = 0
	_update_hud()


func end_run() -> void:
	growth_ended = true
	choosing = false
	current_choices.clear()
	overlay.hide()
	# The result screen owns the pause; never resume it here.


func _refresh_choices() -> void:
	choice_title.text = "레벨 %d  ·  강화 선택  ·  남은 %dpt" % [level, pending_choices]
	for i in range(choice_buttons.size()):
		var button := choice_buttons[i]
		if i >= current_choices.size():
			button.hide()
			continue
		var card_id := current_choices[i]
		var data: Dictionary = CARDS[card_id]
		var next_rank := int(card_ranks.get(card_id, 0)) + 1
		var detail := describe_card(card_id, next_rank)
		button.text = "%d  %s\n\n%s\n\n등급 %d / %d" % [
			i + 1, data.name, detail, next_rank, data.max
		]
		button.show()
	if reroll_button != null:
		reroll_button.disabled = rerolls_left == 0 or current_choices.size() >= _available_card_count()
		reroll_button.text = "다른 카드 보기 · 남은 횟수 %d" % rerolls_left


func describe_card(card_id: String, next_rank: int) -> String:
	var old_rank := next_rank - 1
	match card_id:
		"U_EDGE": return "평타 피해 %d%% → %d%%" % [roundi(100.0 * (1.0 + player.permanent_basic_damage_bonus)) + 15 * old_rank, roundi(100.0 * (1.0 + player.permanent_basic_damage_bonus)) + 15 * next_rank]
		"U_TEMPO": return "평타가 더 빨라집니다\n공격 속도 +%d%% → +%d%%" % [roundi(100.0 * basic_speed_base) + 12 * old_rank, roundi(100.0 * basic_speed_base) + 12 * next_rank]
		"U_REACH": return "평타가 더 멀리 닿습니다\n기본 사거리 %d → %d" % [100 + 15 * old_rank, 100 + 15 * next_rank]
		"U_CHAIN": return "앞의 적을 모으는 3타 추가" if next_rank == 1 else "모인 적을 터뜨리는 4타 추가"
		"S_WISP_DAMAGE": return "여우불 한 발이 더 강해집니다\n기본 피해 %.1f → %.1f" % [10.0 * (1.0 + wisps[0].permanent_damage_bonus) + 2.0 * old_rank, 10.0 * (1.0 + wisps[0].permanent_damage_bonus) + 2.0 * next_rank]
		"S_WISP_CADENCE": return "여우불이 더 자주 쏩니다\n발사 간격 %.2f초 → %.2f초" % [1.25 * (1.0 - permanent_wisp_cadence_reduction - 0.10 * old_rank), 1.25 * (1.0 - permanent_wisp_cadence_reduction - 0.10 * next_rank)]
		"S_WISP_COUNT": return "함께 공격하는 여우불 %d개 → %d개" % [1 + old_rank, 1 + next_rank]
		"S_WISP_ORBIT": return "회전하며 닿은 적에게 피해" if next_rank == 1 else "회전 접촉 피해 4 → 7"
		"S_WISP_CHAIN": return "연쇄 대상 %d명 → %d명" % [old_rank + int(permanent_wisp_chain_bonus), next_rank + int(permanent_wisp_chain_bonus)]
		"S_WISP_FOLLOWUP": return "평타 적중 한 동작당\n여우불 발사 대기\n%.2f초 → %.2f초 단축" % [0.08 * old_rank, 0.08 * next_rank]
		"S_WISP_SWEEP": return "이동 베기 한 동작당 첫 적중\n여우불 대기 %.2f초 → %.2f초 단축" % [0.12 * old_rank, 0.12 * next_rank]
		"S_WISP_REPLY": return "여우불 적중마다\n이동 베기 재사용 대기\n%.2f초 → %.2f초 단축" % [0.06 * old_rank, 0.06 * next_rank]
		"S_SEAL": return "적 위치에 자동 마력진 추가" if next_rank == 1 else "마력진 범위 %d → %d" % [66 + 10 * (old_rank - 1), 66 + 10 * (next_rank - 1)]
		"U_STEP": return "대시 저장 1회 → 2회" if next_rank == 2 else "대시 재충전 %.2f초 → %.2f초" % [1.2 * (1.0 - (0.15 if old_rank > 0 else 0.0) - player.permanent_dash_cooldown_reduction), 1.2 * (1.0 - (0.30 if next_rank >= 3 else 0.15) - player.permanent_dash_cooldown_reduction)]
		"U_SLASH_SWEEP": return "이동 베기 폭 %d → %d" % [110 + 40 * old_rank, 110 + 40 * next_rank]
		"U_SLASH_CADENCE": return "이동 베기 재사용 %.2f초 → %.2f초" % [1.1 * (1.0 - 0.15 * old_rank - player.permanent_slash_cooldown_reduction), 1.1 * (1.0 - 0.15 * next_rank - player.permanent_slash_cooldown_reduction)]
	return String(CARDS[card_id].detail)


func _available_card_count() -> int:
	var count := 0
	for card_id in CARDS:
		if card_id.begins_with("U_SLASH_") and not player.moving_slash_enabled: continue
		if card_id in ["S_WISP_REPLY", "S_WISP_SWEEP"] and not player.moving_slash_enabled: continue
		if card_id == "U_CHAIN" and permanent_combo_progression: continue
		if int(card_ranks.get(card_id, 0)) < int(CARDS[card_id].max) and unlocks.is_unlocked(card_id): count += 1
	return count


func reroll_choices() -> bool:
	if not choosing or rerolls_left <= 0 or current_choices.size() >= _available_card_count(): return false
	var before := current_choices.duplicate()
	for attempt in 8:
		var after := roll_choices()
		var has_new_card := false
		for card_id in after:
			if not before.has(card_id): has_new_card = true
		if has_new_card:
			current_choices = after
			rerolls_left -= 1
			_refresh_choices()
			return true
	return false


func roll_choices() -> Array[String]:
	var basic: Array[String] = []
	var wisp_cards: Array[String] = []
	var others: Array[String] = []
	for card_id in CARDS:
		if card_id.begins_with("U_SLASH_") and not player.moving_slash_enabled: continue
		if card_id in ["S_WISP_REPLY", "S_WISP_SWEEP"] and not player.moving_slash_enabled: continue
		if card_id == "U_CHAIN" and permanent_combo_progression: continue
		if int(card_ranks.get(card_id, 0)) >= int(CARDS[card_id].max) or not unlocks.is_unlocked(card_id):
			continue
		match CARDS[card_id].group:
			"BASIC": basic.append(card_id)
			"AUTO":
				if card_id.begins_with("S_WISP_"): wisp_cards.append(card_id)
				else: others.append(card_id)
			_: others.append(card_id)
	var result: Array[String] = []
	if basic.has("U_CHAIN"):
		basic.erase("U_CHAIN")
		result.append("U_CHAIN")
	elif not basic.is_empty():
		result.append(_take_random(basic))
	if not wisp_cards.is_empty():
		result.append(_take_random(wisp_cards))
	var remaining: Array[String] = []
	remaining.append_array(basic)
	remaining.append_array(wisp_cards)
	remaining.append_array(others)
	while result.size() < 3 and not remaining.is_empty():
		result.append(_take_random(remaining))
	return result


func _take_random(cards: Array[String]) -> String:
	var index := rng.randi_range(0, cards.size() - 1)
	var card_id := cards[index]
	cards.remove_at(index)
	return card_id


func choose_index(index: int) -> bool:
	if not choosing or index < 0 or index >= current_choices.size():
		return false
	var card_id := current_choices[index]
	if int(card_ranks.get(card_id, 0)) >= int(CARDS[card_id].max) or not unlocks.is_unlocked(card_id):
		return false
	var detail := describe_card(card_id, int(card_ranks.get(card_id, 0)) + 1)
	apply_card(card_id)
	last_choice_label.text = "적용: %s · %s" % [CARDS[card_id].name, detail.replace("\n", " · ")]
	if permanent_combo_progression: _sync_permanent_moves()
	pending_choices -= 1
	points_spent += 1
	if not heal_on_levelup: _heal(0.20)
	player.require_attack_release()
	_prepare_next_choice()
	if pending_choices > 0:
		_refresh_choices()
	else:
		choosing = false
		overlay.hide()
		get_tree().paused = paused_before_choice
	_update_hud()
	return true


func apply_card(card_id: String) -> void:
	if not CARDS.has(card_id):
		return
	var rank := int(card_ranks.get(card_id, 0))
	if rank >= int(CARDS[card_id].max) or not unlocks.is_unlocked(card_id):
		return
	rank += 1
	card_ranks[card_id] = rank
	selected_card_ranks[card_id] = int(selected_card_ranks.get(card_id, 0)) + 1
	match card_id:
		"U_EDGE": player.basic_damage_bonus = 0.15 * rank
		"U_TEMPO": player.basic_speed_bonus = basic_speed_base + 0.12 * rank
		"U_REACH": player.basic_reach_bonus = 0.15 * rank
		"U_CHAIN": player.set_combo_rank(rank)
		"U_STEP": player.set_dash_upgrade(rank)
		"U_SLASH_SWEEP": player.moving_slash_radius_bonus = 20.0 * rank
		"U_SLASH_CADENCE": player.moving_slash_cooldown_reduction = 0.15 * rank
		"S_SEAL": _sync_seal(rank)
		_: _sync_wisps()
	card_applied.emit(card_id)
	_update_hud()


func _sync_wisps() -> void:
	var count := 1 + int(card_ranks.get("S_WISP_COUNT", 0))
	while wisps.size() < count:
		var companion: WispCompanion = WispScript.new()
		companion.name = "Wisp%d" % (wisps.size() + 1)
		companion.player = player
		companion.navigation = wisps[0].navigation
		companion.facing_formation = wisps[0].facing_formation
		companion.formation_index = wisps.size()
		companion.formation_count = count
		companion.fire_cooldown = WispCompanion.BASE_ATTACK_INTERVAL * float(wisps.size()) / float(count)
		companion.process_mode = Node.PROCESS_MODE_PAUSABLE
		arena.add_child(companion)
		_connect_wisp(companion)
		wisps.append(companion)
	for i in range(wisps.size()):
		var wisp := wisps[i]
		wisp.formation_index = i
		wisp.formation_count = wisps.size()
		wisp.follow_offset = [Vector2(-42, -30), Vector2(42, -30), Vector2(0, -57)][i]
		wisp.orbit_phase = TAU * float(i) / float(wisps.size())
		wisp.attack_interval = WispCompanion.BASE_ATTACK_INTERVAL * (1.0 - permanent_wisp_cadence_reduction - 0.10 * float(card_ranks.get("S_WISP_CADENCE", 0)))
		wisp.power_rank = int(card_ranks.get("S_WISP_DAMAGE", 0))
		wisp.damage_multiplier = WispCompanion.BASE_DAMAGE_MULTIPLIER + WispCompanion.DAMAGE_BONUS_PER_RANK * float(wisp.power_rank)
		wisp.permanent_damage_bonus = wisps[0].permanent_damage_bonus
		wisp.orbit_enabled = int(card_ranks.get("S_WISP_ORBIT", 0)) > 0
		wisp.orbit_damage = 4.0 + 3.0 * float(int(card_ranks.get("S_WISP_ORBIT", 0)) - 1)
		wisp.chain_jumps = int(card_ranks.get("S_WISP_CHAIN", 0)) + int(permanent_wisp_chain_bonus)


func _connect_wisp(wisp: WispCompanion) -> void:
	if not wisp.enemy_hit.is_connected(_on_wisp_enemy_hit):
		wisp.enemy_hit.connect(_on_wisp_enemy_hit)


func _on_player_attack_landed(_point: Vector2, _direction: Vector2, _step: int, _finisher: bool) -> void:
	var rank := int(card_ranks.get("S_WISP_FOLLOWUP", 0))
	if rank <= 0 or last_followup_attack == player.attack_sequence: return
	last_followup_attack = player.attack_sequence
	for wisp in wisps:
		wisp.fire_cooldown = maxf(0.0, wisp.fire_cooldown - 0.08 * rank)


func _on_player_slash_landed(_point: Vector2) -> void:
	var rank := int(card_ranks.get("S_WISP_SWEEP", 0))
	if rank <= 0 or last_followup_slash == player.moving_slash_sequence: return
	last_followup_slash = player.moving_slash_sequence
	for wisp in wisps:
		wisp.fire_cooldown = maxf(0.0, wisp.fire_cooldown - 0.12 * rank)


func _on_wisp_enemy_hit(_enemy: TrainingEnemy) -> void:
	var rank := int(card_ranks.get("S_WISP_REPLY", 0))
	if rank > 0:
		player.moving_slash_cooldown = maxf(0.0, player.moving_slash_cooldown - 0.06 * rank)


func _sync_seal(rank: int) -> void:
	if seal == null:
		seal = SealScript.new()
		seal.name = "SealAttack"
		seal.player = player
		arena.add_child(seal)
	seal.rank = rank
	seal.radius = 66.0 + 10.0 * float(rank - 1)


func _heal(fraction: float) -> void:
	player.health = minf(player.max_health, player.health + player.max_health * fraction)
	player.health_changed.emit()


func _update_hud() -> void:
	if hud == null:
		return
	if compact_hud:
		hud.text = "레벨 %d   경험치 %d / %d" % [level, xp, next_xp()]
		if xp_bar != null:
			xp_bar.max_value = next_xp()
			xp_bar.value = xp
		return
	hud.text = "LV %d  |  XP %d / %d  |  누적 레벨업 %d  |  여우불 %d" % [
		level, xp, next_xp(), unlocks.lifetime_levelups, wisps.size()
	]
	if not unlock_notice.is_empty():
		hud.text += "\n" + unlock_notice
	else:
		for card_id in unlocks.MILESTONES:
			if not unlocks.is_unlocked(card_id):
				hud.text += "\n다음 해금: %s  ·  누적 레벨업 %d회" % [CARDS[card_id].name, unlocks.MILESTONES[card_id]]
				break


func build_summary() -> String:
	var count := 0
	for rank in selected_card_ranks.values(): count += int(rank)
	var recent: Array[String] = []
	var ids := selected_card_ranks.keys()
	for id in ids.slice(maxi(0, ids.size() - 2)):
		recent.append("%s %d등급" % [CARDS[id].name, card_ranks[id]])
	return "선택 카드 %d회 · Esc 전체 목록" % count + ("\n" + " · ".join(recent) if not recent.is_empty() else "")


func build_details() -> String:
	var lines: Array[String] = []
	for id in CARDS:
		if not selected_card_ranks.has(id): continue
		lines.append("%s  %d/%d등급\n  마지막 선택: %s" % [CARDS[id].name, card_ranks[id], CARDS[id].max, describe_card(id, int(card_ranks[id])).replace("\n", " · ")])
	return "선택한 카드가 없습니다." if lines.is_empty() else "\n\n".join(lines)


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)
	hud = Label.new()
	hud.position = hud_position
	hud.add_theme_font_size_override("font_size", 17)
	hud.add_theme_color_override("font_color", Color("e5fff5"))
	hud.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	canvas.add_child(hud)
	xp_bar = ProgressBar.new()
	xp_bar.position = hud_position + Vector2(0, 28)
	xp_bar.size = Vector2(300, 14)
	xp_bar.show_percentage = false
	xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var xp_fill := StyleBoxFlat.new()
	xp_fill.bg_color = Color("e8c67e")
	xp_bar.add_theme_stylebox_override("fill", xp_fill)
	canvas.add_child(xp_bar)
	xp_bar.visible = compact_hud
	overlay = ColorRect.new()
	overlay.position = Vector2.ZERO
	overlay.size = Vector2(1280, 720)
	overlay.color = Color(0.015, 0.045, 0.065, 0.83)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var modal_canvas := CanvasLayer.new()
	modal_canvas.layer = 30
	modal_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(modal_canvas)
	modal_canvas.add_child(overlay)
	choice_title = Label.new()
	choice_title.position = Vector2(140, 130)
	choice_title.add_theme_font_size_override("font_size", 38)
	choice_title.add_theme_color_override("font_color", Color("f5e8bd"))
	overlay.add_child(choice_title)
	last_choice_label = Label.new()
	last_choice_label.position = Vector2(140, 600)
	last_choice_label.size = Vector2(1000, 85)
	last_choice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	last_choice_label.add_theme_font_size_override("font_size", 19)
	overlay.add_child(last_choice_label)
	var help := Label.new()
	help.text = "1 / 2 / 3 키 또는 카드를 클릭  ·  선택하는 동안 전투 정지"
	help.position = Vector2(140, 190)
	help.add_theme_font_size_override("font_size", 19)
	help.add_theme_color_override("font_color", Color("c4e9e8"))
	overlay.add_child(help)
	for i in range(3):
		var button := Button.new()
		button.position = Vector2(140 + i * 335, 250)
		button.size = Vector2(310, 245)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 21)
		button.pressed.connect(choose_index.bind(i))
		overlay.add_child(button)
		choice_buttons.append(button)
	reroll_button = Button.new()
	reroll_button.position = Vector2(456, 535)
	reroll_button.size = Vector2(368, 48)
	reroll_button.add_theme_font_size_override("font_size", 19)
	reroll_button.pressed.connect(reroll_choices)
	overlay.add_child(reroll_button)
	overlay.hide()
