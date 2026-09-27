extends Control

const ProfileScript = preload("res://game/run_profile.gd")
const REGION_SCENE := "res://game/hybrid_region.tscn"
const JUNGLE_SCENE := "res://game/jungle_pass.tscn"

var profile: RunProfile
var profile_save_prefix := "user://loop_conquest_profile"
var growth_save_prefix := "user://loop_conquest_1d_unlocks"
var unlocks := UnlockProgress.new()
var rng := RandomNumberGenerator.new()
var currency_label: Label
var progress_label: Label
var status_label: Label
var start_button: Button
var temple_region_button: Button
var jungle_region_button: Button
var weapon_button: Button
var echo_weapon_button: Button
var accessory_button: Button
var growth_buttons: Dictionary = {}
var reset_button: Button
var supply_buy_button: Button
var supply_toggle_button: Button
var info_label: Label
var comparison_label: Label
var offer_label: Label
var offer_apply_button: Button
var offer_keep_button: Button
var summary_start_button: Button
var tabs: TabContainer
var embedded_in_camp := false
var selected_region_id := RunProfile.TEMPLE_REGION


func _ready() -> void:
	get_window().title = "Loop Conquest — 여행 준비"
	rng.randomize()
	profile = ProfileScript.new()
	profile.save_prefix = profile_save_prefix
	profile.load_state()
	unlocks.save_prefix = growth_save_prefix
	unlocks.load_progress()
	_build_ui()
	_refresh()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.08, 0.10, 0.93) if embedded_in_camp else Color("091b23"))
	if embedded_in_camp: return
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
	shade.color = Color(0.01, 0.05, 0.06, 0.25)
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
	var subtitle := _label("지역을 고르고, 전투 방식을 비교한 뒤 출정합니다.", 17, Color("bad1cc"))
	root_box.add_child(subtitle)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(tabs)
	var region := _tab_page("지역 선택")
	region.add_child(_label("방문할 지역", 24, Color("f6e7bf")))
	region.add_child(_label("각 지역은 5분 전투 뒤 보스를 쓰러뜨리면 성공합니다.", 17))
	temple_region_button = _button(region, "", _select_region.bind(RunProfile.TEMPLE_REGION))
	jungle_region_button = _button(region, "", _select_region.bind(RunProfile.JUNGLE_REGION))
	progress_label = _label("", 17, Color("efca8d"))
	region.add_child(progress_label)
	region.add_spacer(false)
	region.add_child(_label("지역을 다시 방문해 다른 장비와 카드 조합을 시험할 수 있습니다.", 16, Color("8db2ae")))
	start_button = _button(region, "청록 폐사원 출정", _depart)
	start_button.custom_minimum_size.y = 54
	var gear := _tab_page("장비 · 성장")
	var gear_columns := HBoxContainer.new()
	gear_columns.add_theme_constant_override("separation", 20)
	gear.add_child(gear_columns)
	var gear_choices := VBoxContainer.new()
	gear_choices.custom_minimum_size.x = 575
	gear_choices.add_theme_constant_override("separation", 10)
	gear_columns.add_child(gear_choices)
	gear_choices.add_child(_label("주공격 1칸 · 장신구 1칸", 20, Color("f6e7bf")))
	weapon_button = _button(gear_choices, "", func(): _gear_action("W_FLOW"))
	echo_weapon_button = _button(gear_choices, "", func(): _gear_action("W_ECHO"))
	accessory_button = _button(gear_choices, "", func(): _gear_action("A_EMBER"))
	gear_choices.add_child(_label("역할은 고정, 구매 시 세부 옵션 하나가 무작위로 붙습니다.", 15, Color("9cbbb5")))
	gear_choices.add_child(HSeparator.new())
	gear_choices.add_child(_label("작은 영구 성장", 21, Color("f6e7bf")))
	for id in RunProfile.GROWTH_IDS:
		growth_buttons[id] = _button(gear_choices, "", _buy_growth.bind(id))
	reset_button = _button(gear_choices, "성장 초기화 · 쓴 재화 전액 반환", _reset_growth)
	var comparison := VBoxContainer.new()
	comparison.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gear_columns.add_child(comparison)
	comparison.add_child(_label("현재 장착과 선택 효과", 21, Color("f6e7bf")))
	comparison_label = _label("", 17, Color("c5ded6"))
	comparison.add_child(comparison_label)
	var summary := _tab_page("출정 요약")
	summary.add_child(_label("출정 물자", 23, Color("f6e7bf")))
	summary.add_child(_label("회복 부적 · HP가 35% 이하일 때 자동으로 30 회복. 출정할 때 1개 소모합니다.", 17))
	supply_buy_button = _button(summary, "", _buy_supply)
	supply_toggle_button = _button(summary, "", _toggle_supply)
	summary.add_child(HSeparator.new())
	summary.add_child(_label("현재 선택", 21, Color("f6e7bf")))
	info_label = _label("", 16, Color("bed9d1"))
	summary.add_child(info_label)
	summary.add_child(HSeparator.new())
	offer_label = _label("", 17, Color("f0d393"))
	summary.add_child(offer_label)
	offer_apply_button = _button(summary, "새 옵션 적용", func(): _choose_offer(true))
	offer_keep_button = _button(summary, "기존 옵션 유지 · 제안 거절", func(): _choose_offer(false))
	summary.add_spacer(false)
	summary_start_button = _button(summary, "선택한 지역으로 출정", _depart)
	summary_start_button.custom_minimum_size.y = 54
	status_label = _label("", 15, Color("f6c58e"))
	root_box.add_child(status_label)
	if embedded_in_camp:
		var close_button := _button(root_box, "야영지로 돌아가기  [Esc]", hide)
		close_button.custom_minimum_size.y = 38


func _tab_page(name: String) -> VBoxContainer:
	var scrolling := ScrollContainer.new()
	scrolling.name = name
	scrolling.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scrolling.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(scrolling)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.13, 0.16, 0.94)
	style.border_color = Color("35605f")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(19)
	panel.add_theme_stylebox_override("panel", style)
	scrolling.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	return box


func open_section(index: int) -> void:
	tabs.current_tab = clampi(index, 0, tabs.get_tab_count() - 1)
	_refresh()


func _select_region(id: String) -> void:
	if not profile.region_available(id): return
	selected_region_id = id
	_refresh()


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
	button.add_theme_color_override("font_disabled_color", Color("a6b8af"))
	var locked_style := StyleBoxFlat.new()
	locked_style.bg_color = Color("193439")
	locked_style.border_color = Color("345457")
	locked_style.set_border_width_all(1)
	locked_style.set_content_margin_all(5)
	button.add_theme_stylebox_override("disabled", locked_style)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _refresh() -> void:
	currency_label.text = "재화  %d" % profile.currency
	temple_region_button.text = "청록 폐사원 · %s%s\n수변·회랑 · 문지기 · 첫 완료 시 Q 장비 개방" % ["완료" if profile.temple_owned else "도전 가능", " · 선택 중" if selected_region_id == RunProfile.TEMPLE_REGION else ""]
	jungle_region_button.text = "정글 절벽 관문 · %s%s\n능선 우회로·높은 관문 · 횡쓸기/강풍 수호자" % ["완료" if profile.jungle_owned else "도전 가능" if profile.temple_owned else "첫 지역 완료 후 개방", " · 선택 중" if selected_region_id == RunProfile.JUNGLE_REGION else ""]
	jungle_region_button.disabled = profile.load_error or not profile.region_available(RunProfile.JUNGLE_REGION)
	progress_label.text = "완료: 청록 폐사원 %s · 정글 절벽 관문 %s\n재도전 성공 시 해당 지역 주공격 장비의 세부 옵션을 제안합니다." % ["✓" if profile.temple_owned else "—", "✓" if profile.jungle_owned else "—"]
	start_button.text = "%s 출정" % ("정글 절벽 관문" if selected_region_id == RunProfile.JUNGLE_REGION else "청록 폐사원")
	var weapon_owned := profile.owned_gear.has("W_FLOW")
	weapon_button.text = "흐름의 마력장 · %s\nQ 명중→다음 평타 +25%% · 적중 시 Q 0.22초 환급\nQ 거리 +20%% · 재사용 -10%%\n%s" % ["기본으로 변경" if profile.equipped_weapon == "W_FLOW" else "장착" if weapon_owned else "구매 35", _affix_text(profile.owned_gear.get("W_FLOW", "")) if weapon_owned else "첫 지역 완료 후 개방 · 옵션 무작위"]
	weapon_button.disabled = profile.load_error or (not weapon_owned and (not profile.temple_owned or profile.currency < 35))
	var echo_owned := profile.owned_gear.has("W_ECHO")
	echo_weapon_button.text = "집결의 마력장 · %s\n3타 집결 지점에서 4타가 원형으로 폭발 · 반경 155\n%s" % ["기본으로 변경" if profile.equipped_weapon == "W_ECHO" else "장착" if echo_owned else "구매 45", _affix_text(profile.owned_gear.get("W_ECHO", "")) if echo_owned else "정글 절벽 관문 완료 후 개방 · 옵션 무작위"]
	echo_weapon_button.disabled = profile.load_error or (not echo_owned and (not profile.jungle_owned or profile.currency < 45))
	var accessory_owned := profile.owned_gear.has("A_EMBER")
	accessory_button.text = "여우불 장신구 · %s\n여우불 피해 계수 +0.15\n%s" % ["해제" if profile.equipped_accessory == "A_EMBER" else "장착" if accessory_owned else "구매 24", _affix_text(profile.owned_gear.get("A_EMBER", "")) if accessory_owned else "세부 옵션 무작위"]
	accessory_button.disabled = profile.load_error or (not accessory_owned and profile.currency < 24)
	var growth_names := {"POWER": "평타 피해", "VITALITY": "최대 HP", "MOBILITY": "대시 충전 시간", "SLASH": "Q 재사용 시간", "FINISH": "3·4타 사거리"}
	for id in growth_buttons:
		var rank := int(profile.growth_ranks[id])
		var cost := int(RunProfile.GROWTH_COST[rank]) if rank < 2 else 0
		var button: Button = growth_buttons[id]
		var before := _growth_value(id, rank)
		var after := _growth_value(id, rank + 1)
		var available := profile.growth_available(id, unlocks.lifetime_levelups)
		var locked_text := "누적 레벨업 1회 뒤 개방" if id == "SLASH" else "누적 레벨업 3회 뒤 개방"
		button.text = "%s  %d/2  %s" % [growth_names[id], rank, locked_text if not available else "최대 · " + before if rank == 2 else before + " → " + after + " · 구매 %d" % cost]
		button.disabled = profile.load_error or not available or rank == 2 or profile.currency < cost
	reset_button.disabled = profile.load_error or profile.growth_ranks.values().all(func(value: Variant) -> bool: return int(value) == 0)
	supply_buy_button.text = "회복 부적 구매 12  ·  보유 %d/3" % profile.supply_count
	supply_buy_button.disabled = profile.load_error or profile.currency < 12 or profile.supply_count >= 3
	supply_toggle_button.text = "다음 출정에 사용: %s" % ("예" if profile.supply_selected and profile.supply_count > 0 else "아니요")
	supply_toggle_button.disabled = profile.load_error or profile.supply_count <= 0
	info_label.text = "선택 지역: %s\n주공격: %s\n장신구: %s\n영구 성장: 평타 %d · HP %d · 대시 %d · Q %d · 3/4타 %d\n회복 부적: %s" % [
		"정글 절벽 관문" if selected_region_id == RunProfile.JUNGLE_REGION else "청록 폐사원",
		RunProfile.gear_name(profile.equipped_weapon),
		"여우불 장신구" if profile.equipped_accessory == "A_EMBER" else "없음",
		profile.growth_ranks.POWER, profile.growth_ranks.VITALITY, profile.growth_ranks.MOBILITY, profile.growth_ranks.SLASH, profile.growth_ranks.FINISH,
		"출정 시 소모" if profile.supply_selected and profile.supply_count > 0 else "사용 안 함"
	]
	comparison_label.text = "현재: %s\n기본 평타 피해 %d%% · Q 재사용 %d%%\n3·4타 사거리 %d%%\n\n기본 마력장\n4타 전방 충격 · 거리 120 · 각도 125°\n\n흐름의 마력장\nQ 이동 거리 120%% · 재사용 -10%%\nQ 적중 뒤 다음 평타 +25%%\n그 평타가 적중하면 Q 0.22초 환급\n\n집결의 마력장\n3타가 모은 위치에서 4타 원형 폭발\n기본 반경 155 · 모든 방향\n\n장신구: %s · 피해 계수 +%.2f" % [
		RunProfile.gear_name(profile.equipped_weapon),
		100 + int(profile.growth_ranks.POWER) * 5,
		100 - int(profile.growth_ranks.SLASH) * 3 - (10 if profile.equipped_weapon == "W_FLOW" else 0) - (4 if profile.equipped_weapon == "W_FLOW" and profile.owned_gear.get("W_FLOW") == "SWIFT" else 0),
		100 + int(profile.growth_ranks.FINISH) * 5,
		"여우불 장신구" if profile.equipped_accessory == "A_EMBER" else "없음",
		0.20 if profile.equipped_accessory == "A_EMBER" and profile.owned_gear.get("A_EMBER") == "BRIGHT" else 0.15 if profile.equipped_accessory == "A_EMBER" else 0.0,
	]
	var offer_gear_id: String = RunProfile.REGION_GEAR[selected_region_id]
	var offer: Dictionary = profile.pending_affix_offers.get(offer_gear_id, {})
	offer_label.visible = not offer.is_empty()
	offer_apply_button.visible = not offer.is_empty()
	offer_keep_button.visible = not offer.is_empty()
	if not offer.is_empty():
		var gear_id: String = offer.gear_id
		var old_text := RunProfile.affix_description(profile.owned_gear.get(gear_id, "")) if profile.owned_gear.has(gear_id) else "장비 미구매"
		offer_label.text = "선택 지역 재도전 옵션 · %s\n현재: %s\n제안: %s%s" % [RunProfile.gear_name(gear_id), old_text, RunProfile.affix_description(offer.affix), "\n장비를 구매한 뒤 적용할 수 있습니다. 제안은 저장됩니다." if not profile.owned_gear.has(gear_id) else ""]
		offer_apply_button.disabled = profile.load_error or not profile.owned_gear.has(gear_id)
	start_button.disabled = profile.load_error or not profile.region_available(selected_region_id)
	summary_start_button.disabled = start_button.disabled
	if profile.load_error: status_label.text = "저장 기록을 읽을 수 없습니다. 기존 기록은 덮어쓰지 않았습니다."
	elif profile.recovered_backup: status_label.text = "이전 정상 기록을 복구했습니다. 최근 구매·정산을 확인하세요."
	else: status_label.text = "장비 옵션 제안 %d개 · 해당 지역 선택 후 출정 요약에서 결정하세요." % profile.pending_affix_offers.size() if not profile.pending_affix_offers.is_empty() else "구매·장착·성장은 즉시 저장됩니다. 가격과 효과는 시험값입니다."


func _affix_text(affix: String) -> String:
	return "세부 옵션: " + RunProfile.affix_description(affix) if not affix.is_empty() else ""


func _growth_value(id: String, rank: int) -> String:
	match id:
		"POWER": return "%d%%" % (100 + rank * 5)
		"VITALITY": return "%d" % (100 + rank * 10)
		"MOBILITY": return "%d%%" % (100 - rank * 4)
		"SLASH": return "%d%%" % (100 - rank * 3)
		"FINISH": return "%d%%" % (100 + rank * 5)
	return ""


func _gear_action(id: String) -> void:
	var success := false
	if id.begins_with("W_") and profile.equipped_weapon == id: success = profile.equip("W_START")
	elif id == "A_EMBER" and profile.equipped_accessory == "A_EMBER": success = profile.equip("")
	elif profile.owned_gear.has(id): success = profile.equip(id)
	elif id == "W_FLOW" and profile.temple_owned or id == "W_ECHO" and profile.jungle_owned or id == "A_EMBER":
		var affixes: Array = RunProfile.GEAR_AFFIXES[id].duplicate()
		if profile.pending_affix_offers.has(id):
			affixes.erase(profile.pending_affix_offers[id].get("affix", ""))
		success = profile.buy_gear(id, affixes[rng.randi_range(0, affixes.size() - 1)])
	if success: _refresh()
	else: status_label.text = "구매 또는 저장에 실패했습니다."


func _choose_offer(accept: bool) -> void:
	if profile.choose_affix_offer(accept, RunProfile.REGION_GEAR[selected_region_id]): _refresh()
	else: status_label.text = "옵션 선택을 저장하지 못했습니다."


func _buy_growth(id: String) -> void:
	if profile.buy_growth(id, unlocks.lifetime_levelups): _refresh()
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
	if profile.load_error or not profile.region_available(selected_region_id): return
	get_tree().change_scene_to_file(JUNGLE_SCENE if selected_region_id == RunProfile.JUNGLE_REGION else REGION_SCENE)
