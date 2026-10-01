extends Node
## Reuses the hub's controls and callbacks. Reads the profile; never saves it.
const Profile = preload("res://game/run_profile.gd")
const Awakening = preload("res://game/awakening_catalog.gd")
const INK := Color("f1f3e8")
const MUTED := Color("b9cbc7")
const GOLD := Color("eed399")
var hub: Control
var destination: Label
var weapon: Label
var accessory: Label
var growth: Label
var gate_reason: Label
var gear_link: Button
var growth_link: Button
var columns: HBoxContainer

static func preparation_data(profile: RunProfile, region_id: String, lifetime: int) -> Dictionary:
	var jungle := region_id == Profile.JUNGLE_REGION
	var completed: bool = profile.jungle_owned if jungle else profile.temple_owned
	var available := profile.region_available(region_id)
	var place := "숲길 · 석교 폐허 · 강변 우회로" if jungle else "수변 마당 · 높은 중정 · 성소"
	var target := "5분 이후 관문 안쪽에서 수호자와 교전" if jungle else "5분 이후 동쪽 성소에서 문지기와 교전"
	var gear_id: String = Profile.REGION_GEAR[region_id]
	var reward := "첫 성공 → %s 구매 개방 (%d 화폐)" % [Profile.gear_name(gear_id), Profile.GEAR_COST[gear_id]] if not completed else "재성공 → 미보유 지역 옵션 1개 (남아 있을 때)"
	var invested := 0
	for rank in profile.growth_ranks.values(): invested += int(rank)
	var branch := " · 평타·이동 베기 +10%p" if profile.attack_branch == "DIRECT" else " · 여우불 +10%p" if profile.attack_branch == "COMPANION" else ""
	return {
		"destination": "%s\n%s\n%s\n%s" % [place, "정복 완료 · 재출정 가능" if completed else "도전 가능" if available else "잠김 · 청록 폐사원 첫 성공 필요", target, reward],
		"weapon": _gear_line(profile, profile.equipped_weapon, lifetime),
		"accessory": "장신구 · 미장착\n기본 여우불 동행 유지" if profile.equipped_accessory.is_empty() else _gear_line(profile, profile.equipped_accessory, lifetime),
		"growth": "영구 성장 · %d등급 투자%s" % [invested, branch],
		"gate": "저장 기록을 읽지 못했습니다. 출정할 수 없습니다." if profile.load_error else "청록 폐사원 첫 성공 후 출정할 수 있습니다." if not available else "구매는 소유 · 장착은 이번 출정에 적용",
	}

static func _gear_line(profile: RunProfile, id: String, lifetime: int) -> String:
	var effect := "근거리 마력 타격 · 습득한 콤보로 공격"
	if id == "W_FLOW": effect = "베기 적중 → 다음 평타 +25% · 적중 후 베기 대기 환급"
	elif id == "W_ECHO": effect = "3타 집결 → 같은 지점에 4타 폭발"
	elif id == "A_EMBER": effect = "여우불 마탄 피해 +35% · 연쇄 +1" if profile.awakenings.has("EMBER_GARDEN") else "여우불 마탄 피해 +15%"
	var result := "%s · 장착 중\n%s" % [Profile.gear_name(id), effect]
	var mod := profile.mod_for(id)
	if not mod.is_empty(): result += " · " + Profile.affix_title(mod)
	for key in Awakening.ENTRIES:
		if Awakening.ENTRIES[key].gear == id and profile.awakenings.has(key):
			result += " · 각성 " + ("적용" if Awakening.status(profile, key, lifetime).begins_with("적용 중") else "조건 미충족")
	return result

func setup(scene: Control) -> void:
	hub = scene
	name = "DeparturePreparationPresenter"
	scene.add_child(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var original: VBoxContainer = scene.temple_region_button.get_parent().get_parent()
	# Existing scroll page survives, including its keyboard and tab contracts.
	columns = HBoxContainer.new()
	columns.name = "DestinationAndBuild"
	columns.add_theme_constant_override("separation", 28)
	original.add_child(columns)
	original.move_child(columns, 0)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.95
	left.add_theme_constant_override("separation", 6)
	columns.add_child(left)
	left.add_child(_label("목적지", 22, GOLD))
	scene.temple_region_button.get_parent().reparent(left)
	for control in [scene.temple_region_button, scene.jungle_region_button]:
		control.add_theme_font_size_override("font_size", 17)
		control.custom_minimum_size.y = 52
	destination = _label("", 17)
	left.add_child(destination)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	columns.add_child(right)
	right.add_child(_label("이번 출정의 빌드", 22, GOLD))
	weapon = _label("", 17)
	accessory = _label("", 17)
	growth = _label("", 17, MUTED)
	for control in [weapon, accessory, growth]: right.add_child(control)
	var links := HBoxContainer.new()
	links.add_theme_constant_override("separation", 6)
	right.add_child(links)
	gear_link = scene._button(links, "장비 구매·장착", func(): scene.open_section(1))
	growth_link = scene._button(links, "성장 정비", func(): scene.open_section(2))
	for control in [gear_link, growth_link]:
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		control.autowrap_mode = TextServer.AUTOWRAP_OFF
		scene._apply_button_styles(control, 6)
		control.add_theme_font_size_override("font_size", 17)
		control.custom_minimum_size.y = 32
	# Hide only the legacy duplicates; the owner still updates their real values.
	scene.progress_label.hide()
	scene.info_label.hide()
	for child in original.get_children():
		if child is Label and child.text == "지역 선택": child.hide()
	var supplies: HBoxContainer = scene.supply_buy_button.get_parent()
	supplies.reparent(right)
	for control in [scene.supply_buy_button, scene.supply_toggle_button]:
		control.add_theme_font_size_override("font_size", 15)
		control.custom_minimum_size.y = 32
	scene.canal_trial_button.reparent(left)
	scene.canal_trial_button.text = "수로도시 개발 시험 열기 · 저장·보상 없음"
	scene.canal_trial_button.custom_minimum_size.y = 30
	scene.canal_trial_button.add_theme_font_size_override("font_size", 14)
	var quiet := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "disabled"]: scene.canal_trial_button.add_theme_stylebox_override(state, quiet)
	scene.canal_trial_button.add_theme_color_override("font_color", MUTED)
	gate_reason = _label("", 16, MUTED)
	var footer: VBoxContainer = scene.start_button.get_parent()
	footer.add_theme_constant_override("separation", 8)
	var margins: MarginContainer = footer.get_parent()
	margins.add_theme_constant_override("margin_top", 12)
	margins.add_theme_constant_override("margin_bottom", 12)
	footer.add_child(gate_reason)
	footer.move_child(gate_reason, scene.start_button.get_index())
	var strong: StyleBoxFlat = scene._button_style(true)
	strong.bg_color = Color("d8bd81")
	strong.border_color = Color("f4e3b5")
	scene.start_button.add_theme_stylebox_override("normal", strong)
	scene.start_button.add_theme_color_override("font_color", Color("182a2b"))
	scene.start_button.add_theme_font_size_override("font_size", 24)
	refresh()

func _process(_delta: float) -> void:
	# Refresh presentation even when the existing owner changes via another tab.
	if is_instance_valid(hub) and hub.visible: refresh()

func refresh() -> void:
	var data := preparation_data(hub.profile, hub.selected_region_id, hub.unlocks.lifetime_levelups)
	destination.text = data.destination
	hub.temple_region_button.text = "폐사원 · %s%s" % ["완료" if hub.profile.temple_owned else "도전 가능", " ✓" if hub.selected_region_id == Profile.TEMPLE_REGION else ""]
	hub.jungle_region_button.text = "정글 · %s%s" % ["완료" if hub.profile.jungle_owned else "도전 가능" if hub.profile.temple_owned else "잠김", " ✓" if hub.selected_region_id == Profile.JUNGLE_REGION else ""]
	weapon.tooltip_text = hub.gear_effects_label.get_parsed_text() if hub.selected_gear_id == hub.profile.equipped_weapon else "장비 탭에서 정확한 효과·옵션·각성 조건 확인"
	weapon.text = data.weapon
	accessory.text = data.accessory
	growth.text = data.growth
	gate_reason.text = data.gate
	gate_reason.visible = hub.tabs.current_tab == 0
	gate_reason.add_theme_color_override("font_color", Color("ffafa0") if hub.profile.load_error or not hub.profile.region_available(hub.selected_region_id) else MUTED)

func _label(value: String, pixels: int, tint: Color = INK) -> Label:
	var control := Label.new()
	control.text = value
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.add_theme_font_size_override("font_size", pixels)
	control.add_theme_color_override("font_color", tint)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return control
