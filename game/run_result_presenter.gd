extends Node
## Result presentation only. HybridRegion remains the owner of settlement,
## end timing, visibility, button gating, retries, and return-to-camp input.

const Profile = preload("res://game/run_profile.gd")
const INK := Color("f1f3e8")
const MUTED := Color("b9cbc7")
const REWARD := Color("eed399")
const WARNING := Color("ffafa0")

var heading: Label
var run_details: Label
var award_caption: Label
var award_value: Label
var bank_total: Label
var breakdown: Label
var outcome_heading: Label
var outcome_details: Label
var next_action: Label
var labels: Array[Label] = []


static func present(scene: Node3D) -> void:
	var presenter = scene.get_node_or_null("RunResultPresenter")
	if presenter == null:
		presenter = load("res://game/run_result_presenter.gd").new()
		presenter._setup(scene)
	presenter._refresh(scene)


static func result_data(scene: Node3D) -> Dictionary:
	var profile: RunProfile = scene.profile
	var data := {
		"heading": scene.boss_name + " 격파 · 성공" if scene.end_result == "SUCCESS" else "여행 종료 · 사망" if scene.end_result == "DEFEAT" else "여행 종료 · 귀환",
		"run_details": "%s  ·  %02d:%02d  ·  처치 %d" % [scene.scene_hud_title, floori(scene.run_time / 60.0), floori(fmod(scene.run_time, 60.0)), scene.kills],
		"pending": scene.settlement_pending,
	}
	if scene.settlement_pending:
		data.merge({
			"award_caption": "저장 완료를 확인하지 못했습니다",
			"award_value": "정산 저장 대기",
			"bank_total": "현재 보유 화폐\n%d" % profile.currency,
			"breakdown": "이번 런 획득 %d  ·  정산 미확정" % scene.run_currency,
			"outcome_heading": "저장 재시도가 필요합니다",
			"outcome_details": "정산 저장에 실패했습니다. 저장을 재시도하세요.\n종료하면 미저장 화폐가 사라집니다.",
			"next_action": "저장 재시도가 완료되면 야영지로 돌아갈 수 있습니다.",
		})
		return data
	var bonus: int = profile.last_award - (scene.run_currency - profile.last_lost)
	data.merge({
		"award_caption": "이번 런 화폐 정산 · 저장 완료",
		"award_value": "+%d" % profile.last_award,
		"bank_total": "보유 화폐\n%d" % profile.currency,
		"breakdown": "획득 %d  −  손실 %d%s" % [scene.run_currency, profile.last_lost, "  +  보너스 %d" % bonus if bonus > 0 else ""],
		"outcome_heading": "다음 여행을 준비하세요",
		"outcome_details": "이번 런의 카드는 종료됩니다.\n영구 장비·성장·각성 기록은 유지됩니다.",
		"next_action": "다음 · 야영지에서 장비·성장을 정비한 뒤 다시 출정하세요.",
	})
	if scene.end_result == "SUCCESS" and profile.last_first_clear:
		var gear := String(Profile.REGION_GEAR.get(scene.region_id, ""))
		var available: Array[String] = []
		if not gear.is_empty():
			available.append("%s · 구매 가능 (%d 화폐)" % [Profile.gear_name(gear), int(Profile.GEAR_COST[gear])])
			data.next_action = "다음 · 야영지 장비에서 %s 구매 → 장착" % Profile.gear_name(gear)
		# Read earned next-region access; presentation never grants a clear.
		# Availability is read from the profile, never granted by this presenter.
		if scene.region_id == Profile.TEMPLE_REGION and profile.region_available(Profile.JUNGLE_REGION):
			available.append("정글 절벽 관문 · 출정 가능")
		if scene.region_id == Profile.JUNGLE_REGION and profile.region_available(Profile.WETLAND_REGION):
			available.append("깊은 사원 습지 · 출정 가능")
		if scene.region_id == Profile.WETLAND_REGION:
			available.append("습지 정복 기록 저장 · 재도전에서 미보유 장비 옵션 획득")
		data.outcome_heading = "깊은 사원 습지 첫 정복" if scene.region_id == Profile.WETLAND_REGION else "첫 정복 · 새로 열린 선택"
		data.outcome_details = "\n".join(available)
	elif not profile.last_mod_award.is_empty():
		var gear := Profile.gear_for_affix(profile.last_mod_award)
		data.outcome_heading = "%s · 새 옵션 획득" % Profile.gear_name(gear)
		data.outcome_details = Profile.affix_description(profile.last_mod_award) + "\n야영지에서 선택해야 장비에 적용됩니다."
		var equipped: bool = profile.equipped_weapon == gear or profile.equipped_accessory == gear
		data.next_action = "다음 · 야영지 장비에서 새 옵션 선택" if equipped else "다음 · 야영지에서 %s %s 후 새 옵션 선택" % [Profile.gear_name(gear), "장착" if profile.owned_gear.has(gear) else "구매·장착"]
	return data


func _setup(scene: Node3D) -> void:
	name = "RunResultPresenter"
	process_mode = Node.PROCESS_MODE_ALWAYS
	scene.add_child(self)
	scene.result_text.hide() # Retain its authoritative legacy summary for diagnostics.
	scene.result_overlay.color = Color(0.02, 0.045, 0.055, 0.98)
	heading = _label(scene, "Outcome", Rect2(220, 52, 840, 45), 32)
	run_details = _label(scene, "RunDetails", Rect2(220, 103, 840, 30), 19, MUTED)
	award_caption = _label(scene, "AwardCaption", Rect2(220, 153, 550, 30), 20, MUTED)
	award_value = _label(scene, "AwardValue", Rect2(220, 186, 550, 67), 50, REWARD)
	bank_total = _label(scene, "BankTotal", Rect2(800, 172, 260, 80), 25)
	bank_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	breakdown = _label(scene, "AwardBreakdown", Rect2(220, 260, 840, 32), 20, MUTED)
	var rule := ColorRect.new()
	rule.position = Vector2(220, 310)
	rule.size = Vector2(840, 1)
	rule.color = Color("425652")
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene.result_overlay.add_child(rule)
	outcome_heading = _label(scene, "AvailabilityHeading", Rect2(220, 338, 840, 36), 24)
	outcome_details = _label(scene, "AvailabilityDetails", Rect2(220, 384, 840, 68), 21, MUTED)
	next_action = _label(scene, "NextAction", Rect2(220, 472, 840, 52), 21, REWARD)
	scene.replay_button.position = Vector2(220, 592)
	scene.replay_button.size = Vector2(540, 58)
	scene.retry_button.position = Vector2(220, 532)
	scene.retry_button.size = Vector2(540, 50)
	var quit_button: Button = scene.result_overlay.get_node("ResultQuit")
	quit_button.position = Vector2(780, 592)
	quit_button.size = Vector2(280, 58)
	for button in [scene.replay_button, scene.retry_button, quit_button]:
		button.add_theme_font_size_override("font_size", 20)


func _refresh(scene: Node3D) -> void:
	var data := result_data(scene)
	heading.text = data.heading
	run_details.text = data.run_details
	award_caption.text = data.award_caption
	award_value.text = data.award_value
	award_value.add_theme_font_size_override("font_size", 38 if data.pending else 50)
	award_value.add_theme_color_override("font_color", WARNING if data.pending else REWARD)
	bank_total.text = data.bank_total
	breakdown.text = data.breakdown
	outcome_heading.text = data.outcome_heading
	outcome_heading.add_theme_color_override("font_color", WARNING if data.pending else INK)
	outcome_details.text = data.outcome_details
	next_action.text = data.next_action


func _label(scene: Node3D, title: String, bounds: Rect2, font_size: int, color: Color = INK) -> Label:
	var label := Label.new()
	label.name = title
	label.position = bounds.position
	label.size = bounds.size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.focus_mode = Control.FOCUS_NONE
	scene.result_overlay.add_child(label)
	labels.append(label)
	return label
