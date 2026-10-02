extends Node
## Presentation-only: section owns destination states, player owns survival,
## growth owns XP. Hidden original labels remain available for diagnostics.
const INK := Color("f1f3e8")
const MUTED := Color("b9cbc7")
var arena: Node3D
var health: Label
var mobility: Label
var objective: Label
var boss_clock: Label
var progress: Label
var notice: Label
var help: Label
var boss_title: Label
var survival_surface: ColorRect
var objective_surface: ColorRect
var boss_clock_surface: ColorRect
var notice_surface: ColorRect
var passive_controls: Array[Control] = []
var seen_notices: Dictionary = {}
var transient_notice := ""
var notice_seconds := 0.0

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
	# Keep the clock legible above paused card and retry backdrops, outside their controls.
	var clock_canvas := CanvasLayer.new()
	clock_canvas.layer = 36
	add_child(clock_canvas)
	survival_surface = _surface(base, "Survival", Rect2(20, 556, 376, 132))
	boss_clock_surface = _surface(clock_canvas, "BossClock", Rect2(20, 20, 280, 46))
	objective_surface = _surface(base, "Destination", Rect2(20, 78, 480, 46))
	notice_surface = _surface(base, "EventNotice", Rect2(420, 568, 572, 95))
	health = _label(base, "Health", Rect2(34, 566, 346, 31), 24)
	mobility = _label(base, "Mobility", Rect2(34, 620, 346, 60), 20)
	boss_clock = _label(clock_canvas, "BossTimeRemaining", Rect2(34, 28, 252, 30), 21)
	objective = _label(base, "DestinationState", Rect2(34, 86, 452, 30), 21)
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

func _process(delta: float) -> void:
	if not is_instance_valid(arena): return
	if not get_tree().paused: notice_seconds = maxf(0, notice_seconds - delta)
	refresh()

func refresh() -> void:
	var player = arena.player
	health.text = "HP %d / %d" % [ceili(player.health), ceili(player.max_health)]
	var slash := "미습득" if not player.moving_slash_enabled else "진행 중" if player.moving_slash_time > 0 else "%.1f초" % player.moving_slash_cooldown if player.moving_slash_cooldown > 0 else "준비"
	mobility.text = "대시 %d / %d\n이동 베기 · %s" % [player.dash_charges, player.dash_max_charges, slash]
	progress.text = "LV %d · XP %d / %d" % [arena.growth.level, arena.growth.xp, arena.growth.next_xp()]
	objective.text = destination_text(arena)
	objective.visible = not objective.text.is_empty()
	objective_surface.visible = objective.visible
	boss_clock.text = boss_clock_text(arena)
	var active: bool = arena.temple_section != null and arena.temple_section.boss_active
	objective_surface.position = Vector2(400, 120) if active else Vector2(20, 78)
	objective_surface.size.x = 480
	objective.position = objective_surface.position + Vector2(14, 8)
	if not arena.growth.unlock_notice.is_empty(): _publish("unlock:" + arena.growth.unlock_notice, arena.growth.unlock_notice)
	if arena.profile != null and arena.profile.recovered_backup: _publish("backup", "이전 정상 기록을 복구했습니다.")
	if arena.profile != null and arena.profile.last_launch_supply_used: _publish("supply", "회복 부적 발동 · HP +30")
	var failure := ""
	if arena.temple_section != null:
		var message: String = arena.temple_section.garden_message
		if message.contains("실패"): failure = message
		elif message.contains("저장 완료"): _publish("reward:" + message, message)
	notice.text = failure if not failure.is_empty() else transient_notice if notice_seconds > 0 else ""
	notice.visible = not notice.text.is_empty()
	notice_surface.visible = notice.visible
	notice_surface.size.y = maxf(40, notice.get_minimum_size().y + 12)
	notice_surface.position.y = 656 - notice_surface.size.y
	notice.position.y = notice_surface.position.y + 6
	notice.size.y = notice_surface.size.y - 12
	objective_surface.size.y = maxf(46, objective.get_minimum_size().y + 16)
	objective.size.y = objective_surface.size.y - 16
	help.hide()
	boss_title.hide() # The single objective names the active boss above its HP.
	# Preserve existing visibility gates during death/result/map; never unpause.
	var ended: bool = arena.run_ended
	for item in [boss_clock, boss_clock_surface, survival_surface, health, mobility, progress, arena.player_health_bar, arena.growth.xp_bar]: item.visible = not ended
	if ended:
		objective.hide()
		objective_surface.hide()
		notice.hide()
		notice_surface.hide()
		boss_title.hide()

func _publish(key: String, value: String) -> void:
	if seen_notices.has(key): return
	seen_notices[key] = true
	transient_notice += "\n" + value if notice_seconds > 0 else value
	notice_seconds = 6.0

static func boss_clock_text(scene: Node3D) -> String:
	var section: Node = scene.temple_section
	if section != null:
		if section.retry_pending: return "보스 재도전 대기"
		if section.boss_active: return "보스 교전 중"
		if section.boss_ready: return "보스 준비 완료"
	var remaining := maxi(0, ceili(scene.BOSS_TIME - scene.run_time))
	if remaining == 0: return "보스 준비 중"
	return "보스까지 %02d:%02d" % [remaining / 60, remaining % 60]

static func destination_text(scene: Node3D) -> String:
	var section: Node = scene.temple_section
	if section == null: return ""
	if section.in_garden:
		return String(section.section_hud.text).split("\n")[0]
	if section.boss_active and is_instance_valid(scene.boss):
		return "%s · %d단계" % [scene.boss_name, scene.boss.phase]
	var jungle: bool = scene.region_id == RunProfile.JUNGLE_REGION
	if section.boss_ready: return "관문 안쪽으로" if jungle else "동쪽 성소로"
	return "" # The boss clock stays visible independently of destination text.

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
