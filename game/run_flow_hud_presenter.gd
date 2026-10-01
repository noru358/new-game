extends Node
## Presentation-only: section owns destination states, player owns survival,
## growth owns XP. Hidden original labels remain available for diagnostics.
const INK := Color("f1f3e8")
const MUTED := Color("b9cbc7")
var arena: Node3D
var health: Label
var mobility: Label
var objective: Label
var progress: Label
var notice: Label
var help: Label
var boss_title: Label
var survival_surface: ColorRect
var objective_surface: ColorRect
var notice_surface: ColorRect
var passive_controls: Array[Control] = []

func setup(scene: Node3D) -> void:
	arena = scene
	name = "RunFlowHudPresenter"
	process_mode = Node.PROCESS_MODE_ALWAYS
	scene.add_child(self)
	var legacy: Node = scene.get_node_or_null("RunHudPresenter")
	if legacy != null:
		legacy.set_process(false)
		for key in ["run_panel", "objective_panel", "progress_panel", "build_panel", "help_panel"]:
			var item: Variant = legacy.get(key)
			if item is Control: item.hide()
	var base: CanvasLayer = scene.hud.get_parent()
	base.get_node("StatusPanel").hide()
	base.get_node("ControlsHint").hide()
	for label in [scene.hud, scene.growth.hud, scene.moving_slash_status, scene.build_summary_label, scene.run_hud]: label.hide()
	if scene.temple_section != null: scene.temple_section.section_hud.hide()
	survival_surface = _surface(base, "Survival", Rect2(20, 556, 376, 132))
	objective_surface = _surface(base, "Destination", Rect2(20, 20, 650, 104))
	notice_surface = _surface(base, "EventNotice", Rect2(420, 568, 572, 95))
	health = _label(base, "Health", Rect2(34, 566, 346, 31), 24)
	mobility = _label(base, "Mobility", Rect2(34, 620, 346, 60), 20)
	objective = _label(base, "DestinationState", Rect2(34, 28, 622, 88), 21)
	progress = _label(base, "GrowthProgress", Rect2(420, 666, 572, 27), 19, MUTED)
	notice = _label(base, "EventText", Rect2(434, 574, 544, 86), 19)
	help = _label(base, "ContextHelp", Rect2(1020, 594, 240, 96), 18, MUTED)
	boss_title = _label(base, "BossIdentity", Rect2(430, 136, 420, 28), 21)
	boss_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_bar(scene.player_health_bar, Rect2(34, 601, 346, 10), Color("ed887b"))
	_style_bar(scene.growth.xp_bar, Rect2(20, 702, 1240, 5), Color("e8c67e"))
	_style_bar(scene.boss_health_bar, Rect2(400, 170, 480, 10), Color("e49d6e"))
	scene.player_health_warning.position = Vector2(270, 570)
	scene.player_health_warning.size = Vector2(110, 28)
	scene.player_health_warning.add_theme_font_size_override("font_size", 18)
	_passive(scene.player_health_warning)
	scene.minimap.position = Vector2(1022, 16)
	_passive(scene.minimap)
	refresh()

func _process(_delta: float) -> void:
	if is_instance_valid(arena): refresh()

func refresh() -> void:
	var player = arena.player
	health.text = "HP %d / %d" % [ceili(player.health), ceili(player.max_health)]
	mobility.text = "Shift 대시 %d / %d\n%s" % [player.dash_charges, player.dash_max_charges, arena.moving_slash_status.text.replace("누적 첫 레벨업 때 영구 습득", "첫 레벨업 때 습득")]
	progress.text = "LV %d · XP %d / %d · 이번 런 화폐 %d" % [arena.growth.level, arena.growth.xp, arena.growth.next_xp(), arena.run_currency]
	objective.text = destination_text(arena)
	var lines: Array[String] = []
	var cue: String = arena._encounter_cue()
	if not cue.is_empty() and not arena.run_ended: lines.append(cue)
	if arena.boss_announced and not arena.boss_spawned: lines.append(arena.boss_name + " 등장 예고")
	if is_instance_valid(arena.boss) and arena.boss.health > 0 and arena.temple_section != null and arena.temple_section.boss_active:
		var combat: String = arena.boss.combat_cue()
		if not combat.is_empty(): lines.append(combat)
	if not arena.growth.unlock_notice.is_empty(): lines.append(arena.growth.unlock_notice)
	if arena.profile != null and arena.profile.recovered_backup: lines.append("이전 정상 기록을 복구했습니다.")
	if arena.run_hud.text.contains("회복 부적 발동"): lines.append("회복 부적 발동 · HP +30")
	notice.text = "\n".join(lines)
	notice.visible = not lines.is_empty()
	notice_surface.visible = notice.visible
	notice_surface.size.y = maxf(40, notice.get_minimum_size().y + 12)
	notice_surface.position.y = 656 - notice_surface.size.y
	notice.position.y = notice_surface.position.y + 6
	notice.size.y = notice_surface.size.y - 12
	objective_surface.size.y = maxf(46, objective.get_minimum_size().y + 16)
	objective.size.y = objective_surface.size.y - 16
	var initial: bool = arena.growth.unlocks.lifetime_levelups == 0 and arena.run_time < 20
	help.text = "WASD 이동\nJ / 클릭 평타\nTab 지도 · Esc 상세" if initial else "Tab 지도\nEsc 카드 · 장비 · 조작"
	boss_title.visible = arena.boss_health_bar.visible
	boss_title.text = "%s · %d단계" % [arena.boss_name, arena.boss.phase] if is_instance_valid(arena.boss) else ""
	# Preserve existing visibility gates during death/result/map; never unpause.
	var ended: bool = arena.run_ended
	for item in [survival_surface, objective_surface, health, mobility, objective, progress, help, arena.player_health_bar, arena.growth.xp_bar]: item.visible = not ended
	if ended:
		notice.hide()
		notice_surface.hide()
		boss_title.hide()

static func destination_text(scene: Node3D) -> String:
	var section: Node = scene.temple_section
	if section == null: return scene._run_hud_text()
	# The existing section is the one authority for exploration/ready/engaged.
	# Keep its full failure and retry instructions, never publish hidden places.
	var text: String = section.section_hud.text
	if not section.in_garden and not section.boss_ready:
		var remaining := maxi(0, ceili(scene.BOSS_TIME - scene.run_time))
		text = "%s · 보스까지 %02d:%02d\n%s" % [scene.scene_hud_title, remaining / 60, remaining % 60, text]
	return text

func _surface(canvas: CanvasLayer, title: String, rect: Rect2) -> ColorRect:
	var control := ColorRect.new()
	control.name = title
	control.position = rect.position
	control.size = rect.size
	control.color = Color(0.025, 0.07, 0.08, 0.88)
	canvas.add_child(control)
	canvas.move_child(control, 0)
	_passive(control)
	return control

func _label(canvas: CanvasLayer, title: String, rect: Rect2, pixels: int, tint: Color = INK) -> Label:
	var control := Label.new()
	control.name = title
	control.position = rect.position
	control.size = rect.size
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control.add_theme_font_size_override("font_size", pixels)
	control.add_theme_color_override("font_color", tint)
	control.add_theme_color_override("font_shadow_color", Color(0.015,0.03,0.04,0.95))
	control.add_theme_constant_override("shadow_offset_x", 1)
	control.add_theme_constant_override("shadow_offset_y", 1)
	canvas.add_child(control)
	_passive(control)
	return control

func _style_bar(bar: ProgressBar, rect: Rect2, tint: Color) -> void:
	bar.position = rect.position
	bar.size = rect.size
	var fill := StyleBoxFlat.new()
	fill.bg_color = tint
	var track := StyleBoxFlat.new()
	track.bg_color = Color("314447")
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", track)
	_passive(bar)

func _passive(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.focus_mode = Control.FOCUS_NONE
	passive_controls.append(control)
