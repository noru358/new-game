extends Control

const ProfileScript = preload("res://game/run_profile.gd")
const AwakeningCatalog = preload("res://game/awakening_catalog.gd")
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
var canal_trial_button: Button
var start_button: Button
var temple_region_button: Button
var jungle_region_button: Button
var wetland_region_button: Button
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
var attack_branch_buttons: Dictionary = {}
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
var discovery_cards: HBoxContainer
var gear_detail_column: VBoxContainer
var gear_effects_label: RichTextLabel
var growth_tabs: TabContainer


func _ready() -> void:
	preload("res://game/field_preview_session.gd").configure(self)
	get_window().title = "Loop Conquest — 여행 준비"
	profile = ProfileScript.new()
	profile.save_prefix = profile_save_prefix
	profile.load_state()
	selected_gear_id = profile.equipped_weapon
	unlocks.save_prefix = growth_save_prefix
	unlocks.load_progress()
	_build_ui()
	preload("res://game/departure_preparation_presenter.gd").new().setup(self)
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
	wetland_region_button = _button(region_choices, "", _select_region.bind(RunProfile.WETLAND_REGION))
	wetland_region_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	canal_trial_button = _button(region, "개발 시험 · 수로도시 장소 경험 (저장·보상 없음)", _depart_canal_trial)
	canal_trial_button.custom_minimum_size.y = 34
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
	gear_list_scroll.custom_minimum_size.x = 300
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
	gear_detail_column = VBoxContainer.new()
	gear_detail_column.name = "효과·각성과 교체 옵션"
	gear_detail_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gear_detail_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gear_detail_column.add_theme_constant_override("separation", 6)
	gear_columns.add_child(gear_detail_column)
	gear_effects_label = RichTextLabel.new()
	gear_effects_label.bbcode_enabled = true
	gear_effects_label.fit_content = true
	gear_effects_label.scroll_active = false
	gear_effects_label.add_theme_font_size_override("normal_font_size", 16)
	gear_detail_column.add_child(gear_effects_label)
	var detail_heading := HBoxContainer.new()
	detail_heading.add_theme_constant_override("separation", 6)
	gear_detail_column.add_child(detail_heading)
	mod_info_label = _label("교체 옵션", 19, Color("f5d99c"))
	mod_info_label.custom_minimum_size.y = 30
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
			option_button.custom_minimum_size.y = 28
			option_button.add_theme_font_size_override("font_size", 14)
			_apply_button_styles(option_button, 4)
			option_button.mouse_entered.connect(_preview_mod.bind(mod_id))
			option_button.focus_entered.connect(_preview_mod.bind(mod_id))
	mod_preview_label = _label("", 15, Color("d6e7dc"))
	mod_preview_label.custom_minimum_size.y = 34
	gear_detail_column.add_child(mod_preview_label)
	var growth := VBoxContainer.new()
	growth.name = "성장"
	tabs.add_child(growth)
	growth_tabs = TabContainer.new()
	growth_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	growth.add_child(growth_tabs)
	var attack_growth: VBoxContainer
	for group in [
		{"title": "공격", "ids": ["POWER", "WISP", "SLASH", "FINISH", "SLASH_POWER"]},
		{"title": "방어", "ids": ["VITALITY", "GUARD", "RECOVERY"]},
		{"title": "기동·편의", "ids": ["MOBILITY", "SPEED"]},
	]:
		var group_page := _tab_page(group.title, growth_tabs)
		if group.title == "공격": attack_growth = group_page
		group_page.add_child(_label(group.title + " 성장 · 구매 전후 비교", 22, Color("f6e7bf")))
		for id in group.ids:
			growth_buttons[id] = _button(group_page, "", _buy_growth.bind(id))
			growth_buttons[id].add_theme_font_size_override("font_size", 17)
			growth_buttons[id].custom_minimum_size.y = 42
			_apply_button_styles(growth_buttons[id], 7)
	attack_growth.add_child(_label("공격 상위 · 두 방향 중 하나 / 공격 성장 합계 4등급 필요", 18, Color("f6e7bf")))
	for id in RunProfile.ATTACK_BRANCHES:
		attack_branch_buttons[id] = _button(attack_growth, "", _buy_attack_branch.bind(id))
		attack_branch_buttons[id].add_theme_font_size_override("font_size", 17)
		attack_branch_buttons[id].custom_minimum_size.y = 62 if id == "COMPANION" else 42
		_apply_button_styles(attack_branch_buttons[id], 7)
	reset_button = _button(growth, "성장 초기화 · 쓴 재화 전액 반환", _reset_growth)
	var discoveries := _tab_page("발견·각성")
	discoveries.add_child(_label("발견한 장소와 각성", 24, Color("f6e7bf")))
	discovery_cards = HBoxContainer.new()
	discovery_cards.add_theme_constant_override("separation", 12)
	discoveries.add_child(discovery_cards)
	status_label = _label("", 15, Color("f6c58e"))
	root_box.add_child(status_label)
	if embedded_in_camp:
		var close_button := _button(root_box, "야영지로 돌아가기  [Esc]", hide)
		close_button.custom_minimum_size.y = 38


func _tab_page(name: String, target: TabContainer = null) -> VBoxContainer:
	var scrolling := ScrollContainer.new()
	scrolling.name = name
	scrolling.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scrolling.size_flags_vertical = Control.SIZE_EXPAND_FILL
	(target if target != null else tabs).add_child(scrolling)
	return _scroll_panel_box(scrolling, target != null)


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
	_refresh_discovery_cards()
	currency_label.text = "재화 %d" % profile.currency
	temple_region_button.text = "청록 폐사원  ·  %s%s\n문지기" % ["완료" if profile.temple_owned else "도전 가능", "  ✓" if selected_region_id == RunProfile.TEMPLE_REGION else ""]
	jungle_region_button.text = "정글 절벽 관문  ·  %s%s\n수호자" % ["완료" if profile.jungle_owned else "도전 가능" if profile.temple_owned else "잠김", "  ✓" if selected_region_id == RunProfile.JUNGLE_REGION else ""]
	jungle_region_button.disabled = profile.load_error or not profile.region_available(RunProfile.JUNGLE_REGION)
	wetland_region_button.text = "깊은 사원 습지"
	wetland_region_button.disabled = profile.load_error or not profile.region_available(RunProfile.WETLAND_REGION)
	var region_name := "깊은 사원 습지" if selected_region_id == RunProfile.WETLAND_REGION else "정글 절벽 관문" if selected_region_id == RunProfile.JUNGLE_REGION else "청록 폐사원"
	var unlocked := profile.wetland_owned if selected_region_id == RunProfile.WETLAND_REGION else profile.jungle_owned if selected_region_id == RunProfile.JUNGLE_REGION else profile.temple_owned
	progress_label.text = ("첫 성공 → 습지 정복" if selected_region_id == RunProfile.WETLAND_REGION else "첫 성공 → 장비 개방") if not unlocked else "재도전 성공 → 미보유 옵션 1개"
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
	wetland_region_button.add_theme_stylebox_override("normal", _button_style(selected_region_id == RunProfile.WETLAND_REGION))
	base_weapon_button.text = "기본 마력장\n%s" % ("장착 중" if profile.equipped_weapon == "W_START" else "보유")
	weapon_button.text = "흐름의 마력장\n%s" % _gear_state("W_FLOW")
	echo_weapon_button.text = "집결의 마력장\n%s" % _gear_state("W_ECHO")
	accessory_button.text = "여우불 장신구\n%s" % _gear_state("A_EMBER")
	_refresh_gear_effects()
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
	mod_info_label.text = "교체 옵션 없음" if selected_gear_id == "W_START" else "교체 옵션"
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
		button.text = "%s  %s · %s  ·  %s" % ["●" if mod_state == "장착 중" else "○", "행동" if RunProfile.affix_kind(mod_id) == "behavior" else "수치", RunProfile.affix_title(mod_id), mod_state]
		button.tooltip_text = RunProfile.affix_description(mod_id) + "\n획득: " + RunProfile.affix_source(mod_id)
		button.disabled = profile.load_error
		button.modulate = Color.WHITE if profile.owned_mods.has(mod_id) else Color(0.68, 0.75, 0.72)
	mod_behavior_label.visible = false
	mod_numeric_label.visible = false
	_update_mod_preview()
	var growth_names := PermanentGrowthCatalog.NAMES
	for id in growth_buttons:
		var rank := int(profile.growth_ranks[id])
		var cost := int(RunProfile.GROWTH_COST[rank]) if rank < PermanentGrowthCatalog.MAX_RANK else 0
		var button: Button = growth_buttons[id]
		var before := _growth_value(id, rank)
		var after := _growth_value(id, rank + 1)
		var available := profile.growth_available(id, unlocks.lifetime_levelups)
		var locked_text := "누적 레벨업 1회 뒤 개방" if id in ["SLASH", "SLASH_POWER"] else "누적 레벨업 3회 뒤 개방"
		button.text = "%s  %d/%d  %s" % [growth_names[id], rank, PermanentGrowthCatalog.MAX_RANK, locked_text if not available else "최대 · " + before if rank == PermanentGrowthCatalog.MAX_RANK else before + " → " + after + " · 구매 %d" % cost]
		button.disabled = profile.load_error or not available or rank == PermanentGrowthCatalog.MAX_RANK or profile.currency < cost
	for id in attack_branch_buttons:
		var branch_button: Button = attack_branch_buttons[id]
		var effect := "직접 공격 · 평타/이동 베기 피해 +10%" if id == "DIRECT" else "동행 공격 · 여우불 피해 +10%"
		branch_button.text = effect + (" · 선택됨" if profile.attack_branch == id else " · 초기화 후 변경" if not profile.attack_branch.is_empty() else " · 구매 60" if profile.attack_branch_available() else " · 공격 성장 합계 4 필요")
		if id == "COMPANION": branch_button.text += "\n평타 명중 대상에 2초간 사격 집중"
		branch_button.disabled = profile.load_error or not profile.attack_branch.is_empty() or not profile.attack_branch_available() or profile.currency < RunProfile.ATTACK_BRANCH_COST
	reset_button.disabled = profile.load_error or profile.growth_ranks.values().all(func(value: Variant) -> bool: return int(value) == 0)
	status_label.text = profile.save_block_reason() if profile.load_error else "이전 정상 기록을 복구했습니다." if profile.recovered_backup else ""
	if save_folder_button == null:
		save_folder_button = _button(status_label.get_parent(), "저장 폴더 열기", func(): OS.shell_open(ProjectSettings.globalize_path(profile_save_prefix).get_base_dir()))
	save_folder_button.visible = profile.load_error


func _refresh_discovery_cards() -> void:
	for child in discovery_cards.get_children():
		discovery_cards.remove_child(child)
		child.queue_free()
	var known := 0
	for id in AwakeningCatalog.ENTRIES:
		if not profile.discovered_places.has(AwakeningCatalog.ENTRIES[id].place): continue
		known += 1
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := StyleBoxFlat.new()
		style.bg_color = Color("102b31")
		style.border_color = Color("4d7770")
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		style.set_content_margin_all(14)
		card.add_theme_stylebox_override("panel", style)
		discovery_cards.add_child(card)
		var details := RichTextLabel.new()
		details.bbcode_enabled = true
		details.fit_content = true
		details.scroll_active = false
		details.custom_minimum_size = Vector2(390, 145)
		details.add_theme_font_size_override("normal_font_size", 20)
		details.text = AwakeningCatalog.record(profile, id, unlocks.lifetime_levelups)
		card.add_child(details)
	if known == 0:
		var empty := _label("아직 발견한 장소가 없습니다.", 20)
		discovery_cards.add_child(empty)


func _refresh_gear_effects() -> void:
	var effects := {"W_START": "근거리 마력 타격 · 4타 전방 충격", "W_FLOW": "이동 베기 적중 → 다음 적중 평타 +25% · 빗나가면 유지 · 베기 대기 -0.22초(공격당 1회)", "W_ECHO": "3타 집결 → 같은 지점에 4타 폭발", "A_EMBER": "여우불 마탄 피해 +15%"}
	gear_effects_label.text = "[font_size=23][color=#f5d99c]%s[/color][/font_size]  %s\n%s" % [RunProfile.gear_name(selected_gear_id), _gear_state(selected_gear_id), effects[selected_gear_id]]
	var option: String = profile.mod_for(selected_gear_id)
	for id in AwakeningCatalog.ENTRIES:
		if AwakeningCatalog.ENTRIES[id].gear == selected_gear_id and profile.awakenings.has(id):
			gear_effects_label.text += "\n[color=#8ee4df]각성 · %s[/color] · %s" % [AwakeningCatalog.ENTRIES[id].title, AwakeningCatalog.next_step(profile, id, unlocks.lifetime_levelups)]
	gear_effects_label.text += "\n현재 옵션 · " + (RunProfile.affix_title(option) if not option.is_empty() else "없음")


func _gear_state(id: String) -> String:
	if id == profile.equipped_weapon or id == profile.equipped_accessory: return "· 장착 중"
	if id == "W_START": return "· 보유"
	if profile.owned_gear.has(id): return "· 보유"
	if id == "W_FLOW" and not profile.temple_owned or id == "W_ECHO" and not profile.jungle_owned: return "· 잠김"
	return "· 구매 %d" % int(RunProfile.GEAR_COST[id])


func _mod_summary(id: String) -> String:
	var mod_id := profile.mod_for(id)
	return RunProfile.affix_description(mod_id) if not mod_id.is_empty() else "없음"


func _growth_value(id: String, rank: int) -> String:
	return PermanentGrowthCatalog.display_value(id, rank)


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
	if selected_gear_id != "W_START":
		var state := "장착 가능" if profile.owned_gear.has(selected_gear_id) and profile.owned_mods.has(previewed_mod_id) else "장비 구매 필요" if profile.owned_mods.has(previewed_mod_id) else "미획득"
		mod_preview_label.text += "\n" + RunProfile.affix_source(previewed_mod_id) + " · " + state
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


func _buy_attack_branch(id: String) -> void:
	if profile.buy_attack_branch(id): _refresh()
	else: status_label.text = "상위 성장 구매를 저장하지 못했습니다. 기존 기록을 유지합니다."


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
	get_tree().change_scene_to_file(preload("res://game/field_preview_session.gd").scene_for_region(get_tree(), selected_region_id))


func _depart_canal_trial() -> void:
	# No region selection, profile mutation or supply consumption.
	get_tree().paused = false
	get_tree().change_scene_to_file("res://game/canal_city_trial.tscn")
