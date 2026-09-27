extends Control

const ProfileScript = preload("res://game/run_profile.gd")
const REGION_SCENE := "res://game/hybrid_region.tscn"

var profile: RunProfile
var profile_save_prefix := "user://loop_conquest_profile"
var rng := RandomNumberGenerator.new()
var currency_label: Label
var progress_label: Label
var status_label: Label
var start_button: Button
var weapon_button: Button
var accessory_button: Button
var growth_buttons: Dictionary = {}
var reset_button: Button
var supply_buy_button: Button
var supply_toggle_button: Button
var info_label: Label


func _ready() -> void:
	get_window().title = "Loop Conquest — 여행 준비"
	rng.randomize()
	profile = ProfileScript.new()
	profile.save_prefix = profile_save_prefix
	profile.load_state()
	_build_ui()
	_refresh()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("091b23"))
	var ridge := PackedVector2Array([Vector2(0, 450), Vector2(125, 330), Vector2(250, 410), Vector2(420, 255), Vector2(610, 410), Vector2(780, 290), Vector2(980, 420), Vector2(1110, 330), Vector2(1280, 470), Vector2(1280, 720), Vector2(0, 720)])
	draw_colored_polygon(ridge, Color("12333a"))
	draw_rect(Rect2(0, 582, 1280, 138), Color("0b232a"))
	for i in 7:
		var x := 90.0 + 183.0 * i
		draw_rect(Rect2(x, 105, 22, 225), Color("18363b"))
		draw_rect(Rect2(x - 12, 99, 46, 9), Color("2b5957"))
		if i < 6: draw_line(Vector2(x + 20, 140), Vector2(x + 183, 140), Color("2b5957"), 8.0)


func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.05, 0.06, 0.35)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)
	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 13)
	margin.add_child(root_box)
	var heading := HBoxContainer.new()
	root_box.add_child(heading)
	var title := _label("여행 준비", 34, Color("f6e7bf"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	currency_label = _label("", 27, Color("f7cd83"))
	currency_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	currency_label.custom_minimum_size.x = 190
	currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	heading.add_child(currency_label)
	var subtitle := _label("다음 여정을 위한 장비와 준비를 고릅니다. 장소와 이야기의 형태는 아직 열어둡니다.", 17, Color("bad1cc"))
	root_box.add_child(subtitle)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 15)
	root_box.add_child(columns)
	var left := _panel(columns, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_label("방문할 지역", 23, Color("f6e7bf")))
	left.add_child(_label("청록 폐사원", 25, Color("98ded3")))
	left.add_child(_label("5분 전투 후 문지기와 싸웁니다.\n성공하면 획득 재화를 전부 정산합니다.\n사망·귀환 시에는 일부를 잃습니다.", 16))
	progress_label = _label("", 17, Color("efca8d"))
	left.add_child(progress_label)
	left.add_spacer(false)
	left.add_child(_label("다음 지역은 첫 지역과 준비 흐름을 검증한 뒤 추가합니다.", 15, Color("8db2ae")))
	start_button = _button(left, "청록 폐사원 출정", _depart)
	start_button.custom_minimum_size.y = 54
	var middle := _panel(columns, 1)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(_label("장비 · 다음 전투 방식", 23, Color("f6e7bf")))
	middle.add_child(_label("주공격 1칸 · 장신구 1칸", 15, Color("a9c7c3")))
	weapon_button = _button(middle, "", func(): _gear_action("W_FLOW"))
	accessory_button = _button(middle, "", func(): _gear_action("A_EMBER"))
	middle.add_child(_label("구매 시 세부 옵션 하나가 무작위로 붙고, 구매 전 역할은 고정입니다.", 14, Color("9cbbb5")))
	middle.add_child(HSeparator.new())
	middle.add_child(_label("작은 영구 성장", 21, Color("f6e7bf")))
	for id in ["POWER", "VITALITY", "MOBILITY"]:
		growth_buttons[id] = _button(middle, "", _buy_growth.bind(id))
	reset_button = _button(middle, "성장 초기화 · 쓴 재화 전액 반환", _reset_growth)
	var right := _panel(columns, 2)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(_label("출정 물자", 23, Color("f6e7bf")))
	right.add_child(_label("회복 부적 · HP가 35% 이하일 때 자동으로 30 회복. 출정할 때 1개 소모합니다.", 16))
	supply_buy_button = _button(right, "", _buy_supply)
	supply_toggle_button = _button(right, "", _toggle_supply)
	right.add_child(HSeparator.new())
	right.add_child(_label("현재 선택", 21, Color("f6e7bf")))
	info_label = _label("", 16, Color("bed9d1"))
	right.add_child(info_label)
	right.add_spacer(false)
	status_label = _label("", 15, Color("f6c58e"))
	right.add_child(status_label)


func _panel(parent: HBoxContainer, index: int) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = [310, 425, 400][index]
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.13, 0.16, 0.94)
	style.border_color = Color("35605f")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(19)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	return box


func _label(value: String, font_size: int, color: Color = Color("d6e7dc")) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(parent: VBoxContainer, value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 42
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _refresh() -> void:
	currency_label.text = "재화  %d" % profile.currency
	progress_label.text = "첫 지역 완료 · 다음 장비 선택 개방" if profile.temple_owned else "첫 지역 완료 기록 없음"
	var weapon_owned := profile.owned_gear.has("W_FLOW")
	weapon_button.text = "흐름의 마력장 · %s\nQ 명중 뒤 다음 평타 +25%%\nQ 거리 +20%% · 재사용 -10%%\n%s" % ["기본으로 변경" if profile.equipped_weapon == "W_FLOW" else "장착" if weapon_owned else "구매 35", _affix_text(profile.owned_gear.get("W_FLOW", "")) if weapon_owned else "첫 지역 완료 후 개방 · 옵션 무작위"]
	weapon_button.disabled = profile.load_error or (not weapon_owned and (not profile.temple_owned or profile.currency < 35))
	var accessory_owned := profile.owned_gear.has("A_EMBER")
	accessory_button.text = "여우불 장신구 · %s\n여우불 피해 계수 +0.15\n%s" % ["해제" if profile.equipped_accessory == "A_EMBER" else "장착" if accessory_owned else "구매 24", _affix_text(profile.owned_gear.get("A_EMBER", "")) if accessory_owned else "세부 옵션 무작위"]
	accessory_button.disabled = profile.load_error or (not accessory_owned and profile.currency < 24)
	var growth_names := {"POWER": "평타 피해 +5%p", "VITALITY": "최대 HP +10", "MOBILITY": "대시 충전 -4%p"}
	for id in growth_buttons:
		var rank := int(profile.growth_ranks[id])
		var cost := int(RunProfile.GROWTH_COST[rank]) if rank < 2 else 0
		var button: Button = growth_buttons[id]
		button.text = "%s  %d/2   %s" % [growth_names[id], rank, "최대" if rank == 2 else "구매 %d" % cost]
		button.disabled = profile.load_error or rank == 2 or profile.currency < cost
	reset_button.disabled = profile.load_error or profile.growth_ranks.values().all(func(value: Variant) -> bool: return int(value) == 0)
	supply_buy_button.text = "회복 부적 구매 12  ·  보유 %d/3" % profile.supply_count
	supply_buy_button.disabled = profile.load_error or profile.currency < 12 or profile.supply_count >= 3
	supply_toggle_button.text = "다음 출정에 사용: %s" % ("예" if profile.supply_selected and profile.supply_count > 0 else "아니요")
	supply_toggle_button.disabled = profile.load_error or profile.supply_count <= 0
	info_label.text = "주공격: %s\n장신구: %s\n영구 성장: 평타 %d · HP %d · 대시 %d\n회복 부적: %s" % [
		"흐름의 마력장" if profile.equipped_weapon == "W_FLOW" else "기본 마력장",
		"여우불 장신구" if profile.equipped_accessory == "A_EMBER" else "없음",
		profile.growth_ranks.POWER, profile.growth_ranks.VITALITY, profile.growth_ranks.MOBILITY,
		"출정 시 소모" if profile.supply_selected and profile.supply_count > 0 else "사용 안 함"
	]
	start_button.disabled = profile.load_error
	if profile.load_error: status_label.text = "저장 기록을 읽을 수 없습니다. 기존 기록은 덮어쓰지 않았습니다."
	elif profile.recovered_backup: status_label.text = "이전 정상 기록을 복구했습니다. 최근 구매·정산을 확인하세요."
	else: status_label.text = "구매·장착·성장은 즉시 저장됩니다.\n가격과 효과는 시험값입니다."


func _affix_text(affix: String) -> String:
	match affix:
		"KEEN": return "무작위 옵션: Q 피해 +4%"
		"SWIFT": return "무작위 옵션: Q 재사용 -4%p"
		"BRIGHT": return "무작위 옵션: 여우불 피해 계수 +0.05"
		"STEADY": return "무작위 옵션: 최대 HP +5"
	return ""


func _gear_action(id: String) -> void:
	var success := false
	if id == "W_FLOW" and profile.equipped_weapon == "W_FLOW": success = profile.equip("W_START")
	elif id == "A_EMBER" and profile.equipped_accessory == "A_EMBER": success = profile.equip("")
	elif profile.owned_gear.has(id): success = profile.equip(id)
	elif id == "W_FLOW" and profile.temple_owned: success = profile.buy_gear(id, "KEEN" if rng.randi_range(0, 1) == 0 else "SWIFT")
	elif id == "A_EMBER": success = profile.buy_gear(id, "BRIGHT" if rng.randi_range(0, 1) == 0 else "STEADY")
	if success: _refresh()
	else: status_label.text = "구매 또는 저장에 실패했습니다."


func _buy_growth(id: String) -> void:
	if profile.buy_growth(id): _refresh()
	else: status_label.text = "성장 구매에 실패했습니다."


func _reset_growth() -> void:
	if profile.reset_growth(): _refresh()
	else: status_label.text = "성장 초기화 저장에 실패했습니다."


func _buy_supply() -> void:
	if profile.buy_supply(): _refresh()
	else: status_label.text = "물자 구매에 실패했습니다."


func _toggle_supply() -> void:
	if profile.select_supply(not profile.supply_selected): _refresh()
	else: status_label.text = "물자 선택 저장에 실패했습니다."


func _depart() -> void:
	if profile.load_error: return
	get_tree().change_scene_to_file(REGION_SCENE)
