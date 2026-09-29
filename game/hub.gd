extends Control

const ProfileScript = preload("res://game/run_profile.gd")
const REGION_SCENE := "res://game/hybrid_region.tscn"
const JUNGLE_SCENE := "res://game/jungle_pass.tscn"

var profile: RunProfile
var profile_save_prefix := "user://loop_conquest_profile"
var growth_save_prefix := "user://loop_conquest_1d_unlocks"
var unlocks := UnlockProgress.new()
var currency_label: Label
var progress_label: Label
var status_label: Label
var save_folder_button: Button
var start_button: Button
var temple_region_button: Button
var jungle_region_button: Button
var base_weapon_button: Button
var weapon_button: Button
var echo_weapon_button: Button
var accessory_button: Button
var gear_action_button: Button
var mod_buttons: Dictionary = {}
var mod_clear_button: Button
var mod_info_label: Label
var mod_preview_label: Label
var mod_behavior_label: Label
var mod_numeric_label: Label
var growth_buttons: Dictionary = {}
var reset_button: Button
var supply_buy_button: Button
var supply_toggle_button: Button
var info_label: Label
var tabs: TabContainer
var gear_list_scroll: ScrollContainer
var gear_detail_scroll: ScrollContainer
var embedded_in_camp := false
var selected_region_id := RunProfile.TEMPLE_REGION
var selected_gear_id := "W_FLOW"
var previewed_mod_id := ""


func _ready() -> void:
	get_window().title = "Loop Conquest — 여행 준비"
	profile = ProfileScript.new()
	profile.save_prefix = profile_save_prefix
	profile.load_state()
	selected_gear_id = profile.equipped_weapon
	unlocks.save_prefix = growth_save_prefix
	unlocks.load_progress()
	_build_ui()
	_refresh()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.08, 0.10, 0.93) if embedded_in_camp else Color("091b23"))


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
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(tabs)
	var region := _tab_page("출정")
	region.add_child(_label("지역 선택", 22, Color("f6e7bf")))
	var region_choices := HBoxContainer.new()
	region_choices.add_theme_constant_override("separation", 12)
	region.add_child(region_choices)
	temple_region_button = _button(region_choices, "", _select_region.bind(RunProfile.TEMPLE_REGION))
	jungle_region_button = _button(region_choices, "", _select_region.bind(RunProfile.JUNGLE_REGION))
	temple_region_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	jungle_region_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_label = _label("", 17, Color("efca8d"))
	region.add_child(progress_label)
	info_label = _label("", 18, Color("bed9d1"))
	region.add_child(info_label)
	var supplies := HBoxContainer.new()
	supplies.add_theme_constant_override("separation", 12)
	region.add_child(supplies)
	supply_buy_button = _button(supplies, "", _buy_supply)
	supply_toggle_button = _button(supplies, "", _toggle_supply)
	supply_buy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	supply_toggle_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_button = _button(root_box, "청록 폐사원 출정", _depart)
	start_button.custom_minimum_size.y = 54
	tabs.tab_changed.connect(func(index: int): start_button.visible = index == 0)
	var gear_columns := HBoxContainer.new()
	gear_columns.name = "장비"
	gear_columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gear_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gear_columns.add_theme_constant_override("separation", 12)
	tabs.add_child(gear_columns)
	gear_list_scroll = ScrollContainer.new()
	gear_list_scroll.custom_minimum_size.x = 530
	gear_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gear_columns.add_child(gear_list_scroll)
	var gear_choices := _scroll_panel_box(gear_list_scroll)
	gear_choices.add_theme_constant_override("separation", 10)
	gear_choices.add_child(_label("주공격", 22, Color("f6e7bf")))
	base_weapon_button = _button(gear_choices, "", func(): _select_gear("W_START"))
	weapon_button = _button(gear_choices, "", func(): _select_gear("W_FLOW"))
	echo_weapon_button = _button(gear_choices, "", func(): _select_gear("W_ECHO"))
	gear_choices.add_child(_label("장신구", 22, Color("f6e7bf")))
	accessory_button = _button(gear_choices, "", func(): _select_gear("A_EMBER"))
	gear_action_button = _button(gear_choices, "", _gear_action)
	var gear_detail_column := VBoxContainer.new()
	gear_detail_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gear_detail_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gear_detail_column.add_theme_constant_override("separation", 6)
	gear_columns.add_child(gear_detail_column)
	var detail_heading := HBoxContainer.new()
	detail_heading.add_theme_constant_override("separation", 6)
	gear_detail_column.add_child(detail_heading)
	mod_info_label = _label("", 15, Color("c5ded6"))
	mod_info_label.custom_minimum_size.y = 46
	mod_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_heading.add_child(mod_info_label)
	mod_clear_button = _button(detail_heading, "옵션 해제", func(): _slot_mod(""))
	mod_clear_button.custom_minimum_size = Vector2(92, 34)
	mod_clear_button.add_theme_font_size_override("font_size", 14)
	gear_detail_scroll = ScrollContainer.new()
	gear_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gear_detail_column.add_child(gear_detail_scroll)
	var mods := _scroll_panel_box(gear_detail_scroll, true)
	mod_behavior_label = _label("행동 변화", 18, Color("f6e7bf"))
	mods.add_child(mod_behavior_label)
	var behavior_options := VBoxContainer.new()
	mods.add_child(behavior_options)
	mod_numeric_label = _label("수치 조정", 18, Color("f6e7bf"))
	mods.add_child(mod_numeric_label)
	var numeric_options := VBoxContainer.new()
	mods.add_child(numeric_options)
	for gear_id in RunProfile.GEAR_AFFIXES:
		for mod_id in RunProfile.GEAR_AFFIXES[gear_id]:
			mod_buttons[mod_id] = _button(behavior_options if RunProfile.affix_kind(mod_id) == "behavior" else numeric_options, "", _select_mod.bind(mod_id))
			var option_button: Button = mod_buttons[mod_id]
			option_button.custom_minimum_size.y = 38
			option_button.add_theme_font_size_override("font_size", 15)
			_apply_button_styles(option_button, 7)
			option_button.mouse_entered.connect(_preview_mod.bind(mod_id))
			option_button.focus_entered.connect(_preview_mod.bind(mod_id))
	mod_preview_label = _label("", 15, Color("d6e7dc"))
	mod_preview_label.custom_minimum_size.y = 44
	gear_detail_column.add_child(mod_preview_label)
	var growth := _tab_page("성장")
	for group in [
		{"title": "공격", "ids": ["POWER", "WISP", "SLASH", "FINISH"]},
		{"title": "방어", "ids": ["VITALITY", "GUARD"]},
		{"title": "기동·편의", "ids": ["MOBILITY", "SPEED"]},
	]:
		growth.add_child(_label(group.title, 22, Color("f6e7bf")))
		for id in group.ids:
			growth_buttons[id] = _button(growth, "", _buy_growth.bind(id))
	reset_button = _button(growth, "성장 초기화 · 쓴 재화 전액 반환", _reset_growth)
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
	return _scroll_panel_box(scrolling)


func _scroll_panel_box(scrolling: ScrollContainer, compact: bool = false) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.13, 0.16, 0.94)
	style.border_color = Color("35605f")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10 if compact else 19)
	panel.add_theme_stylebox_override("panel", style)
	scrolling.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5 if compact else 12)
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


func _button(parent: Container, value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = 42
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_disabled_color", Color("a6b8af"))
	_apply_button_styles(button, 12)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _apply_button_styles(button: Button, inset: int) -> void:
	button.add_theme_stylebox_override("normal", _button_style(false, inset))
	button.add_theme_stylebox_override("hover", _button_style(true, inset))
	button.add_theme_stylebox_override("pressed", _button_style(true, inset, true))
	button.add_theme_stylebox_override("hover_pressed", _button_style(true, inset, true))
	var locked_style := StyleBoxFlat.new()
	locked_style.bg_color = Color("193439")
	locked_style.border_color = Color("345457")
	locked_style.set_border_width_all(2)
	locked_style.set_corner_radius_all(5)
	locked_style.set_content_margin_all(inset)
	button.add_theme_stylebox_override("disabled", locked_style)
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color.TRANSPARENT
	focus_style.border_color = Color("e4bc79")
	focus_style.set_border_width_all(2)
	focus_style.set_corner_radius_all(5)
	focus_style.set_content_margin_all(inset)
	button.add_theme_stylebox_override("focus", focus_style)


func _button_style(highlighted: bool, inset: int = 12, pressed: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1d4042") if highlighted else Color("102b31")
	style.border_color = Color("fff0b6") if pressed else Color("e4bc79") if highlighted else Color("32545a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(inset)
	return style


func _refresh() -> void:
	currency_label.text = "재화 %d" % profile.currency
	temple_region_button.text = "청록 폐사원  ·  %s%s\n문지기" % ["완료" if profile.temple_owned else "도전 가능", "  ✓" if selected_region_id == RunProfile.TEMPLE_REGION else ""]
	jungle_region_button.text = "정글 절벽 관문  ·  %s%s\n수호자" % ["완료" if profile.jungle_owned else "도전 가능" if profile.temple_owned else "잠김", "  ✓" if selected_region_id == RunProfile.JUNGLE_REGION else ""]
	jungle_region_button.disabled = profile.load_error or not profile.region_available(RunProfile.JUNGLE_REGION)
	var region_name := "정글 절벽 관문" if selected_region_id == RunProfile.JUNGLE_REGION else "청록 폐사원"
	var unlocked := profile.jungle_owned if selected_region_id == RunProfile.JUNGLE_REGION else profile.temple_owned
	progress_label.text = "첫 성공 → 장비 개방" if not unlocked else "재도전 성공 → 새 지역 옵션 1개"
	info_label.text = "주공격  %s  ·  %s\n장신구  %s  ·  %s" % [
		RunProfile.gear_name(profile.equipped_weapon),
		_mod_summary(profile.equipped_weapon),
		"여우불 장신구" if profile.equipped_accessory == "A_EMBER" else "없음",
		_mod_summary("A_EMBER") if profile.equipped_accessory == "A_EMBER" else "없음"
	]
	supply_buy_button.text = "회복 부적 구매 12  ·  %d/3" % profile.supply_count
	supply_buy_button.disabled = profile.load_error or profile.currency < 12 or profile.supply_count >= 3
	supply_toggle_button.text = "이번 출정에 사용  %s" % ("켜짐" if profile.supply_selected and profile.supply_count > 0 else "꺼짐")
	supply_toggle_button.disabled = profile.load_error or profile.supply_count <= 0
	start_button.text = "%s 출정" % region_name
	start_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_button.disabled = profile.load_error or not profile.region_available(selected_region_id)
	temple_region_button.add_theme_stylebox_override("normal", _button_style(selected_region_id == RunProfile.TEMPLE_REGION))
	jungle_region_button.add_theme_stylebox_override("normal", _button_style(selected_region_id == RunProfile.JUNGLE_REGION))
	base_weapon_button.text = "기본 마력장  %s\n4타 전방 충격" % ("· 장착 중" if profile.equipped_weapon == "W_START" else "")
	weapon_button.text = "흐름의 마력장  %s\n이동 베기 적중 → 다음 평타 강화" % _gear_state("W_FLOW")
	echo_weapon_button.text = "집결의 마력장  %s\n3타 집결 지점에서 4타 폭발" % _gear_state("W_ECHO")
	accessory_button.text = "여우불 장신구  %s\n여우불 피해 강화" % _gear_state("A_EMBER")
	for entry in [["W_START", base_weapon_button], ["W_FLOW", weapon_button], ["W_ECHO", echo_weapon_button], ["A_EMBER", accessory_button]]:
		(entry[1] as Button).add_theme_stylebox_override("normal", _button_style(selected_gear_id == entry[0]))
	var selected_owned := selected_gear_id == "W_START" or profile.owned_gear.has(selected_gear_id)
	if selected_gear_id == "W_START":
		gear_action_button.text = "기본 마력장 장착"
	elif not selected_owned:
		gear_action_button.text = "선택 장비 구매  %d" % int(RunProfile.GEAR_COST[selected_gear_id])
	elif (selected_gear_id == profile.equipped_weapon or selected_gear_id == profile.equipped_accessory):
		gear_action_button.text = "장신구 해제" if selected_gear_id == "A_EMBER" else "주공격 해제 · 기본 장비로"
	else:
		gear_action_button.text = "선택 장비 장착"
	gear_action_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	gear_action_button.disabled = profile.load_error or (selected_gear_id == "W_START" and profile.equipped_weapon == "W_START") or (not selected_owned and (profile.currency < int(RunProfile.GEAR_COST[selected_gear_id]) or selected_gear_id == "W_FLOW" and not profile.temple_owned or selected_gear_id == "W_ECHO" and not profile.jungle_owned))
	if selected_gear_id != "W_START" and not RunProfile.GEAR_AFFIXES[selected_gear_id].has(previewed_mod_id):
		previewed_mod_id = RunProfile.GEAR_AFFIXES[selected_gear_id][0]
	mod_info_label.text = "기본 마력장\n교체 옵션 없음" if selected_gear_id == "W_START" else "%s\n장착: %s" % [RunProfile.gear_name(selected_gear_id), RunProfile.affix_title(profile.mod_for(selected_gear_id)) if not profile.mod_for(selected_gear_id).is_empty() else "없음"]
	mod_clear_button.visible = selected_gear_id != "W_START"
	mod_clear_button.disabled = profile.load_error or profile.mod_for(selected_gear_id).is_empty()
	var has_behavior := false
	var has_numeric := false
	for mod_id in mod_buttons:
		var button: Button = mod_buttons[mod_id]
		button.visible = selected_gear_id != "W_START" and RunProfile.GEAR_AFFIXES[selected_gear_id].has(mod_id)
		if button.visible and RunProfile.affix_kind(mod_id) == "behavior": has_behavior = true
		elif button.visible: has_numeric = true
		var mod_state := "장착 중" if profile.mod_for(selected_gear_id) == mod_id else "보유" if profile.owned_mods.has(mod_id) else "미획득"
		button.text = "%s  %s  ·  %s" % ["●" if mod_state == "장착 중" else "○", RunProfile.affix_title(mod_id), mod_state]
		button.tooltip_text = RunProfile.affix_description(mod_id)
		button.disabled = profile.load_error
		button.modulate = Color.WHITE if profile.owned_mods.has(mod_id) else Color(0.68, 0.75, 0.72)
	mod_behavior_label.visible = has_behavior
	mod_numeric_label.visible = has_numeric
	_update_mod_preview()
	var growth_names := {"POWER": "평타 피해", "WISP": "여우불 발사 간격", "SLASH": "이동 베기 재사용", "FINISH": "3·4타 사거리", "VITALITY": "최대 HP", "GUARD": "받는 피해", "MOBILITY": "대시 충전 시간", "SPEED": "기본 이동속도"}
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
	status_label.text = "저장 기록과 정상 백업을 읽을 수 없습니다. 기존 파일은 보존했습니다. 저장 폴더에서 백업을 확인하세요." if profile.load_error else "이전 정상 기록을 복구했습니다." if profile.recovered_backup else ""
	if save_folder_button == null:
		save_folder_button = _button(status_label.get_parent(), "저장 폴더 열기", func(): OS.shell_open(ProjectSettings.globalize_path(profile_save_prefix).get_base_dir()))
	save_folder_button.visible = profile.load_error


func _gear_state(id: String) -> String:
	if id == profile.equipped_weapon or id == profile.equipped_accessory: return "· 장착 중"
	if profile.owned_gear.has(id): return "· 보유"
	if id == "W_FLOW" and not profile.temple_owned or id == "W_ECHO" and not profile.jungle_owned: return "· 잠김"
	return "· 구매 %d" % int(RunProfile.GEAR_COST[id])


func _mod_summary(id: String) -> String:
	var mod_id := profile.mod_for(id)
	return RunProfile.affix_description(mod_id) if not mod_id.is_empty() else "없음"


func _growth_value(id: String, rank: int) -> String:
	match id:
		"POWER": return "%d%%" % (100 + rank * 5)
		"WISP": return "%.2f초" % (WispCompanion.BASE_ATTACK_INTERVAL * (1.0 - rank * 0.04))
		"VITALITY": return "%d" % (100 + rank * 10)
		"GUARD": return "%d%%" % (100 - rank * 5)
		"MOBILITY": return "%d%%" % (100 - rank * 4)
		"SPEED": return "%d%%" % (100 + rank * 4)
		"SLASH": return "%d%%" % (100 - rank * 3)
		"FINISH": return "%d%%" % (100 + rank * 5)
	return ""


func _select_gear(id: String) -> void:
	selected_gear_id = id
	previewed_mod_id = profile.mod_for(id) if id != "W_START" and not profile.mod_for(id).is_empty() else RunProfile.GEAR_AFFIXES[id][0] if id != "W_START" else ""
	_refresh()
	gear_detail_scroll.scroll_vertical = 0


func _preview_mod(mod_id: String) -> void:
	if selected_gear_id == "W_START" or not RunProfile.GEAR_AFFIXES[selected_gear_id].has(mod_id): return
	previewed_mod_id = mod_id
	_update_mod_preview()


func _select_mod(mod_id: String) -> void:
	_preview_mod(mod_id)
	if (selected_gear_id == "W_START" or not profile.owned_gear.has(selected_gear_id)
			or not profile.owned_mods.has(mod_id) or profile.mod_for(selected_gear_id) == mod_id):
		return
	_slot_mod(mod_id)


func _update_mod_preview() -> void:
	mod_preview_label.text = "옵션을 장착할 수 없습니다." if selected_gear_id == "W_START" else RunProfile.affix_description(previewed_mod_id)
	for mod_id in mod_buttons:
		var button: Button = mod_buttons[mod_id]
		button.add_theme_stylebox_override("normal", _button_style(mod_id == previewed_mod_id, 7))


func _gear_action() -> void:
	var id := selected_gear_id
	var success := false
	if id == "W_START": success = profile.equip(id)
	elif id.begins_with("W_") and profile.equipped_weapon == id: success = profile.equip("W_START")
	elif id == "A_EMBER" and profile.equipped_accessory == "A_EMBER": success = profile.equip("")
	elif profile.owned_gear.has(id): success = profile.equip(id)
	elif id == "W_FLOW" and profile.temple_owned or id == "W_ECHO" and profile.jungle_owned or id == "A_EMBER":
		success = profile.buy_gear(id)
	if success: _refresh()
	else: status_label.text = "구매 또는 저장에 실패했습니다."


func _slot_mod(mod_id: String) -> void:
	if profile.slot_mod(selected_gear_id, mod_id):
		if not mod_id.is_empty(): previewed_mod_id = mod_id
		_refresh()
	else: status_label.text = "옵션 장착을 저장하지 못했습니다."


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
