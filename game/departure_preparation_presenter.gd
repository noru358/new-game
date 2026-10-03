extends Node
## First page answers only where to go and what is equipped.
## Reparents existing optional controls; every purchase/save stays with Hub.
const Profile = preload("res://game/run_profile.gd")
const INK := Color("f1f3e8")
const MUTED := Color("b9cbc7")
var hub: Control
var weapon: Label
var accessory: Label
var supply_summary: Label
var gate_reason: Label
var summary: VBoxContainer
var purchase_explanation: Label

func setup(scene: Control) -> void:
	hub = scene
	name = "DeparturePreparationPresenter"
	process_mode = Node.PROCESS_MODE_ALWAYS
	scene.add_child(self)
	var departure: VBoxContainer = scene.temple_region_button.get_parent().get_parent()
	for button in [scene.temple_region_button, scene.jungle_region_button, scene.wetland_region_button]:
		button.custom_minimum_size.y = 76
		button.add_theme_font_size_override("font_size", 22)
	scene.info_label.hide()
	# Optional preparation belongs to the existing equipment page.
	var equipment: VBoxContainer = scene.gear_list_scroll.get_child(0).get_child(0)
	purchase_explanation = _label("구매는 보유 · 출정에 적용하려면 별도 장착", 16, MUTED)
	equipment.add_child(purchase_explanation)
	equipment.move_child(purchase_explanation, scene.gear_action_button.get_index())
	equipment.add_child(_label("회복 부적", 20))
	var supplies: HBoxContainer = scene.supply_buy_button.get_parent()
	supplies.reparent(equipment)
	for button in [scene.supply_buy_button, scene.supply_toggle_button]:
		button.add_theme_font_size_override("font_size", 16)
	# Retain reward information and the developer entry off the first page.
	var extra: VBoxContainer = scene.discovery_cards.get_parent()
	extra.add_child(_label("선택 지역의 출정 정보", 20))
	scene.progress_label.reparent(extra)
	scene.canal_trial_button.reparent(extra)
	scene.canal_trial_button.text = "수로도시 개발 시험 · 저장·보상 없음"
	scene.canal_trial_button.custom_minimum_size.y = 34
	scene.canal_trial_button.add_theme_font_size_override("font_size", 16)
	for trial in [
		{"title": "사원 4분 진행 시험 · 별도 기록", "scene": "res://game/temple_circuit_run.tscn"},
		{"title": "정글 남쪽 순환 시험 · 시험용 해금·별도 기록", "scene": "res://game/jungle_south_circuit.tscn"},
		{"title": "사원 전체 동선 후보 · 저장·보상 없음", "scene": "res://game/temple_circuit_trial.tscn"},
		{"title": "깊은 사원 습지 대표 구간 · 저장·보상 없음", "scene": "res://game/deep_wetland_trial.tscn"},
	]:
		if preload("res://game/field_preview_session.gd").active(scene.get_tree()) and trial.scene in ["res://game/temple_circuit_run.tscn", "res://game/jungle_south_circuit.tscn"]:
			continue # Shared campaign uses the ordinary departure buttons and real unlock gate.
		if preload("res://game/field_preview_session.gd").active(scene.get_tree()) and trial.scene == "res://game/deep_wetland_trial.tscn":
			trial = {"title": "깊은 사원 습지 전체 동선 · 저장·보상 없음", "scene": "res://game/deep_wetland_field.tscn"}
		var button := Button.new()
		button.text = trial.title
		button.custom_minimum_size.y = 34
		button.add_theme_font_size_override("font_size", 16)
		var path: String = trial.scene
		button.pressed.connect(func():
			scene.get_tree().paused = false
			scene.get_tree().change_scene_to_file(path))
		extra.add_child(button)
	summary = VBoxContainer.new()
	summary.name = "EquippedSummary"
	summary.add_theme_constant_override("separation", 10)
	departure.add_child(summary)
	summary.add_child(_label("현재 장착", 22, MUTED))
	weapon = _label("", 22)
	accessory = _label("", 22)
	supply_summary = _label("", 18, MUTED)
	for label in [weapon, accessory, supply_summary]: summary.add_child(label)
	gate_reason = _label("", 18, Color("ffafa0"))
	var footer: VBoxContainer = scene.start_button.get_parent()
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
	if is_instance_valid(hub) and hub.visible: refresh()

func refresh() -> void:
	var first_page: bool = hub.tabs.current_tab == 0
	hub.currency_label.visible = not first_page
	hub.temple_region_button.text = "청록 폐사원%s" % (" · 선택" if hub.selected_region_id == Profile.TEMPLE_REGION else "")
	hub.jungle_region_button.text = "정글 절벽 관문%s" % (" · 잠김" if not hub.profile.region_available(Profile.JUNGLE_REGION) else " · 선택" if hub.selected_region_id == Profile.JUNGLE_REGION else "")
	weapon.text = "주공격 · " + Profile.gear_name(hub.profile.equipped_weapon)
	accessory.text = "장신구 · " + (Profile.gear_name(hub.profile.equipped_accessory) if not hub.profile.equipped_accessory.is_empty() else "미장착")
	supply_summary.visible = hub.profile.supply_selected and hub.profile.supply_count > 0
	supply_summary.text = "회복 부적 사용"
	# The hub already owns the storage-error message/folder entry. Do not repeat it.
	hub.wetland_region_button.text = "깊은 사원 습지%s" % (" · 잠김" if not hub.profile.region_available(Profile.WETLAND_REGION) else " · 선택" if hub.selected_region_id == Profile.WETLAND_REGION else "")
	gate_reason.text = ("정글 절벽 관문 첫 성공 후 출정 가능" if hub.selected_region_id == Profile.WETLAND_REGION else "청록 폐사원 첫 성공 후 출정 가능") if not hub.profile.region_available(hub.selected_region_id) and not hub.profile.load_error else ""
	gate_reason.visible = first_page and not gate_reason.text.is_empty()
	_refresh_equipment_action()

func _refresh_equipment_action() -> void:
	# Read committed state after Hub's purchase/equip callback. Never perform either.
	var id: String = hub.selected_gear_id
	var equipped: bool = id == hub.profile.equipped_weapon or id == hub.profile.equipped_accessory
	var owned: bool = id == "W_START" or hub.profile.owned_gear.has(id)
	if equipped:
		purchase_explanation.text = "장착됨 · 출정 탭에서 시작"
	elif owned:
		purchase_explanation.text = "보유 중 · 아래 장착 버튼으로 적용"
		hub.gear_action_button.text = Profile.gear_name(id) + " 장착"
	else:
		purchase_explanation.text = "구매는 보유 · 구매 뒤 별도 장착"

func _label(value: String, pixels: int, tint: Color = INK) -> Label:
	var control := Label.new()
	control.text = value
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.add_theme_font_size_override("font_size", pixels)
	control.add_theme_color_override("font_color", tint)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return control
