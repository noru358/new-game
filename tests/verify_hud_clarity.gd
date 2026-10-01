extends SceneTree
## Frozen UI fixtures and real input dispatch; not balance or human acceptance.
## HUD_CLARITY_CAPTURE_DIR enables actual GL captures at both window sizes.

const Presenter = preload("res://game/run_hud_presenter.gd")
var failures := 0
var checks := 0
var capture_dir := ""

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _run() -> void:
	var normal_slots := _normal_slots()
	capture_dir = OS.get_environment("HUD_CLARITY_CAPTURE_DIR")
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	for region in ["temple", "jungle"]:
		for dimensions in [Vector2i(1280, 720), Vector2i(960, 540)]:
			root.size = dimensions
			root.content_scale_size = Vector2i(1280, 720)
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
			var scene = load("res://game/jungle_pass.tscn" if region == "jungle" else "res://game/hybrid_region.tscn").instantiate()
			var stem := "user://verify_hud_clarity_%s_%d" % [region, dimensions.x]
			_erase_fixture(stem)
			scene.profile_save_prefix = stem
			scene.growth_save_prefix = stem + "_growth"
			root.add_child(scene)
			current_scene = scene
			await process_frame
			scene.set_physics_process(false)
			scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
			scene._set_paused(false)
			scene._update_hud()
			scene._update_run_hud()
			scene.temple_section._update_hud()
			var tag := "%s-%dx%d" % [region, dimensions.x, dimensions.y]
			await _capture(tag + "-start-before")
			var state_before := _state(scene)
			# On the isolated v38 base these are the same three mount operations
			# supplied separately for the scene-file owner to integrate.
			var presenter: Node = scene.get_node_or_null("RunHudPresenter")
			if presenter == null:
				var canvas: CanvasLayer = scene.hud.get_parent()
				(canvas.get_child(0) as ColorRect).name = "StatusPanel"
				for child in canvas.get_children():
					if child is Label and child.text == "Tab 지도   ·   Esc 카드 / 장비 / 각성 / 조작": child.name = "ControlsHint"
				presenter = Presenter.new()
				presenter.setup(scene)
			await process_frame
			await process_frame
			check(_state(scene) == state_before, tag + " mounting changes no gameplay/progression state")
			_assert_layout(scene, presenter, tag)
			await _capture(tag + "-start-after")
			# Dense late-run fixture: low HP, two recent long cards, and boss cue.
			scene.player.health = 20
			scene.player.dash_charges = 0
			scene.player.moving_slash_enabled = true
			scene.player.moving_slash_cooldown = 0.7
			scene.growth.selected_card_ranks = {"S_WISP_SWEEP": 2, "U_SLASH_CADENCE": 2}
			scene.growth.card_ranks["S_WISP_SWEEP"] = 2
			scene.growth.card_ranks["U_SLASH_CADENCE"] = 2
			scene.growth.level = 9
			scene.growth.xp = 12
			scene.run_time = 305
			scene.run_currency = 183
			scene._spawn_now(scene.temple_section.boss_point, TrainingEnemy.Role.BEAST, true)
			scene.boss.phase = 2
			scene.boss.recovery_time = 0.6
			scene.temple_section.boss_ready = true
			scene.temple_section.boss_entered = true
			scene.temple_section.boss_active = true
			scene.teleport(scene.temple_section.boss_point + Vector2(180, 180))
			scene._update_hud()
			scene._update_run_hud()
			scene.growth._update_hud()
			scene.temple_section._update_hud()
			await process_frame
			await process_frame
			_assert_layout(scene, presenter, tag + " dense")
			check(scene.player_health_warning.visible and scene.boss_health_bar.visible, tag + " low-health and active boss are visible")
			await _capture(tag + "-combat-after")
			await _key(KEY_TAB)
			check(scene.overview, tag + " Tab opens full map")
			await _capture(tag + "-map-after")
			await _key(KEY_TAB)
			check(not scene.overview, tag + " repeated Tab returns to combat")
			await _key(KEY_ESCAPE)
			check(paused and scene.pause_menu.visible, tag + " Esc opens pause")
			var frozen_time: float = scene.run_time
			await create_timer(0.1, true).timeout
			check(scene.run_time == frozen_time, tag + " pause time remains frozen")
			var pages := scene.build_details_label.get_parent().get_parent() as TabContainer
			pages.current_tab = 1
			await process_frame
			check(scene.pause_equipment_label.is_visible_in_tree() and scene.pause_equipment_label.text.contains("영구 각성"), tag + " gear/awakening page remains available")
			await _capture(tag + "-equipment-after")
			await _key(KEY_ESCAPE)
			check(not paused and not scene.pause_menu.visible, tag + " Esc resumes")
			await _key(KEY_G)
			check(paused and scene.retreat_overlay.visible, tag + " G opens confirmation")
			await _key(KEY_ESCAPE)
			check(not paused and not scene.retreat_overlay.visible, tag + " Esc cancels retreat")
			scene.growth.gain_xp(scene.growth.next_xp())
			check(paused and scene.growth.choosing and scene.growth.overlay.visible, tag + " card choice remains modal")
			await _capture(tag + "-choice-after")
			var spent: int = scene.growth.points_spent
			await _key(KEY_1)
			check(scene.growth.points_spent == spent + 1 and not scene.growth.choosing and not paused, tag + " number choice applies once and resumes")
			await _key(KEY_ESCAPE)
			await _key(KEY_ESCAPE)
			check(not paused and not scene.pause_menu.visible, tag + " repeat pause cycle closes cleanly")
			scene.queue_free()
			paused = false
			await process_frame
			await process_frame
			_erase_fixture(stem)
	check(_normal_slots() == normal_slots, "regular profile/unlock slots preserve bytes or absence")
	print("HUD clarity: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _state(scene) -> String:
	return JSON.stringify([scene.player.health, scene.player.max_health, scene.player.dash_charges, scene.player.moving_slash_cooldown, scene.run_time, scene.run_currency, scene.growth.xp, scene.growth.card_ranks, scene.profile._snapshot(), scene.growth.unlocks.lifetime_levelups])

func _assert_layout(scene, presenter, context: String) -> void:
	var viewport := Rect2(0, 0, 1280, 720)
	for item in presenter.passive_controls:
		check(item.mouse_filter == Control.MOUSE_FILTER_IGNORE and item.focus_mode == Control.FOCUS_NONE, context + " HUD cannot intercept clicks/focus: " + item.name)
		if item.visible: check(viewport.encloses(item.get_global_rect()), context + " control stays inside scaled canvas: " + item.name)
	for label in [scene.hud, scene.growth.hud, scene.build_summary_label, scene.moving_slash_status, scene.run_hud, scene.temple_section.section_hud, presenter.controls_hint]:
		check(label.get_line_count() <= label.get_visible_line_count(), context + " all lines visible: " + label.name)
	check(scene.player_health_bar.size.y <= 12 and scene.growth.xp_bar.size.y <= 9, context + " bars use explicit slim track heights")
	check(not scene.hud.get_global_rect().intersects(scene.player_health_bar.get_global_rect()), context + " health number and meter do not overlap")
	check(not scene.growth.hud.get_global_rect().intersects(scene.growth.xp_bar.get_global_rect()), context + " XP number and meter do not overlap")
	check(not scene.build_summary_label.get_global_rect().intersects(presenter.controls_hint.get_global_rect()), context + " card summary and help do not overlap")
	check(presenter.run_panel.size.x < 584, context + " timer surface does not keep its old empty full width")
	var bottom_area: float = 0
	for panel in [presenter.progress_panel, presenter.build_panel, presenter.help_panel]: bottom_area += panel.size.x * panel.size.y
	check(bottom_area < 1248 * 100 * 0.75, context + " compact bottom surfaces free at least a quarter of the old strip")
	check(not presenter.progress_panel.get_global_rect().intersects(presenter.build_panel.get_global_rect()) and not presenter.build_panel.get_global_rect().intersects(presenter.help_panel.get_global_rect()), context + " compact information groups remain separate")
	for pair in [[presenter.progress_panel, scene.growth.hud], [presenter.progress_panel, scene.growth.xp_bar], [presenter.progress_panel, scene.moving_slash_status], [presenter.build_panel, scene.build_summary_label], [presenter.help_panel, presenter.controls_hint], [presenter.run_panel, scene.run_hud]]:
		check(pair[0].get_global_rect().encloses(pair[1].get_global_rect()), context + " compact surface retains its complete readout")
	check(presenter.objective_panel.get_global_rect().encloses(scene.temple_section.section_hud.get_global_rect()), context + " objective text has a complete contrast surface")

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	Input.parse_input_event(event)
	await process_frame

func _capture(label: String) -> void:
	if capture_dir.is_empty(): return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(not image.is_empty(), "actual GL image for " + label)
	if not image.is_empty(): check(image.save_png(capture_dir.path_join(label + ".png")) == OK, "capture " + label)

func _erase_fixture(stem: String) -> void:
	for prefix in [stem, stem + "_growth"]:
		for suffix in ["_a.json", "_b.json"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(prefix + suffix))

func _normal_slots() -> Dictionary:
	var records := {}
	for stem in ["user://loop_conquest_profile", "user://loop_conquest_1d_unlocks"]:
		for suffix in ["_a.json", "_b.json"]:
			var path: String = stem + suffix
			records[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
	return records
