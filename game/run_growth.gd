class_name RunGrowth
extends Node

signal card_applied(card_id: String)

const OrbScript = preload("res://game/experience_orb.gd")
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
	"S_SEAL": {"name": "자동 마력진", "detail": "가까운 적에게 예고 후 범위 공격", "max": 3, "group": "AUTO"},
	"U_STEP": {"name": "민첩한 대시", "detail": "대시 충전 강화", "max": 3, "group": "DASH"},
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
var card_ranks: Dictionary = {}
var current_choices: Array[String] = []
var choosing := false
var hud: Label
var overlay: ColorRect
var choice_title: Label
var choice_buttons: Array[Button] = []
var unlock_notice := ""


func setup(battle: Node2D, actor: SandboxPlayer, starting_wisp: WispCompanion) -> void:
	arena = battle
	player = actor
	wisps.append(starting_wisp)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	unlocks.load_progress()
	_build_ui()
	_update_hud()


func next_xp() -> int:
	return 8 + 2 * (level - 1)


func on_enemy_defeated(enemy: TrainingEnemy) -> void:
	var orb: ExperienceOrb = OrbScript.new()
	orb.setup(4 if enemy.max_health > enemy.MAX_HEALTH else 2, player)
	orb.collected.connect(gain_xp)
	arena.add_child(orb)
	orb.global_position = enemy.global_position


func gain_xp(amount: int) -> void:
	if amount <= 0:
		return
	unlock_notice = ""
	xp += amount
	while xp >= next_xp():
		xp -= next_xp()
		level += 1
		pending_choices += 1
		var newly_unlocked := unlocks.add_levelup()
		if not newly_unlocked.is_empty():
			var names: Array[String] = []
			for card_id in newly_unlocked:
				names.append(CARDS[card_id].name)
			unlock_notice = "새 카드 해금: " + ", ".join(names)
	_update_hud()
	if pending_choices > 0 and not choosing:
		_start_choice()


func _start_choice() -> void:
	if pending_choices <= 0:
		return
	current_choices = roll_choices()
	if current_choices.is_empty():
		_heal(0.20)
		pending_choices -= 1
		if pending_choices > 0:
			_start_choice()
		else:
			get_tree().paused = false
			_update_hud()
		return
	choosing = true
	get_tree().paused = true
	overlay.show()
	choice_title.text = "레벨 %d  ·  강화 선택" % level
	for i in range(choice_buttons.size()):
		var button := choice_buttons[i]
		if i >= current_choices.size():
			button.hide()
			continue
		var card_id := current_choices[i]
		var data: Dictionary = CARDS[card_id]
		var next_rank := int(card_ranks.get(card_id, 0)) + 1
		var detail: String = data.detail
		if card_id == "U_STEP":
			detail = ["재충전 15% 단축", "최대 충전 2회", "재충전 총 30% 단축"][next_rank - 1]
		button.text = "%d  %s\n\n%s\n\n등급 %d / %d" % [
			i + 1, data.name, detail, next_rank, data.max
		]
		button.show()


func roll_choices() -> Array[String]:
	var basic: Array[String] = []
	var automatic: Array[String] = []
	var others: Array[String] = []
	for card_id in CARDS:
		if int(card_ranks.get(card_id, 0)) >= int(CARDS[card_id].max) or not unlocks.is_unlocked(card_id):
			continue
		match CARDS[card_id].group:
			"BASIC": basic.append(card_id)
			"AUTO": automatic.append(card_id)
			_: others.append(card_id)
	var result: Array[String] = []
	if basic.has("U_CHAIN"):
		basic.erase("U_CHAIN")
		result.append("U_CHAIN")
	elif not basic.is_empty():
		result.append(_take_random(basic))
	if not automatic.is_empty():
		result.append(_take_random(automatic))
	var remaining: Array[String] = []
	remaining.append_array(basic)
	remaining.append_array(automatic)
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
	apply_card(card_id)
	pending_choices -= 1
	_heal(0.20)
	choosing = false
	overlay.hide()
	current_choices.clear()
	player.require_attack_release()
	if pending_choices > 0:
		_start_choice()
	else:
		get_tree().paused = false
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
	match card_id:
		"U_EDGE": player.basic_damage_bonus = 0.15 * rank
		"U_TEMPO": player.basic_speed_bonus = 0.12 * rank
		"U_REACH": player.basic_reach_bonus = 0.15 * rank
		"U_CHAIN": player.set_combo_rank(rank)
		"U_STEP": player.set_dash_upgrade(rank)
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
		companion.process_mode = Node.PROCESS_MODE_PAUSABLE
		arena.add_child(companion)
		wisps.append(companion)
	for i in range(wisps.size()):
		var wisp := wisps[i]
		wisp.follow_offset = [Vector2(-42, -30), Vector2(42, -30), Vector2(0, -57)][i]
		wisp.orbit_phase = TAU * float(i) / float(wisps.size())
		wisp.attack_interval = WispCompanion.BASE_ATTACK_INTERVAL * (1.0 - 0.10 * float(card_ranks.get("S_WISP_CADENCE", 0)))
		wisp.power_rank = int(card_ranks.get("S_WISP_DAMAGE", 0))
		wisp.damage_multiplier = WispCompanion.BASE_DAMAGE_MULTIPLIER + WispCompanion.DAMAGE_BONUS_PER_RANK * float(wisp.power_rank)
		wisp.orbit_enabled = int(card_ranks.get("S_WISP_ORBIT", 0)) > 0
		wisp.orbit_damage = 4.0 + 3.0 * float(int(card_ranks.get("S_WISP_ORBIT", 0)) - 1)
		wisp.chain_jumps = int(card_ranks.get("S_WISP_CHAIN", 0))
		if i > 0:
			wisp.fire_cooldown = wisp.attack_interval * float(i) / float(wisps.size())


func _sync_seal(rank: int) -> void:
	if seal == null:
		seal = SealScript.new()
		seal.name = "SealAttack"
		seal.player = player
		arena.add_child(seal)
	seal.rank = rank
	seal.radius = 66.0 + 10.0 * float(rank - 1)


func _heal(fraction: float) -> void:
	player.health = minf(player.MAX_HEALTH, player.health + player.MAX_HEALTH * fraction)
	player.health_changed.emit()


func _update_hud() -> void:
	if hud == null:
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


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)
	hud = Label.new()
	hud.position = Vector2(20, 104)
	hud.add_theme_font_size_override("font_size", 17)
	hud.add_theme_color_override("font_color", Color("e5fff5"))
	hud.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	canvas.add_child(hud)
	overlay = ColorRect.new()
	overlay.position = Vector2.ZERO
	overlay.size = Vector2(1280, 720)
	overlay.color = Color(0.015, 0.045, 0.065, 0.83)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(overlay)
	choice_title = Label.new()
	choice_title.position = Vector2(140, 130)
	choice_title.add_theme_font_size_override("font_size", 38)
	choice_title.add_theme_color_override("font_color", Color("f5e8bd"))
	overlay.add_child(choice_title)
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
		button.add_theme_font_size_override("font_size", 21)
		button.pressed.connect(choose_index.bind(i))
		overlay.add_child(button)
		choice_buttons.append(button)
	overlay.hide()
