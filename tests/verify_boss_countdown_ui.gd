extends SceneTree
## Actual mounted HUD and modal inputs; all save slots are unique fixtures.
var checks := 0
var failures := 0
var capture_dir := OS.get_environment("BOSS_COUNTDOWN_CAPTURE_DIR")

func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func run():
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for region in ["temple", "jungle"]:
		for size in [Vector2i(960, 540), Vector2i(1280, 720)]: await inspect(region, size)
	check(checks > 200, "every clock fixture executed")
	print("Boss countdown UI: %d checks, %d failures, %s" % [checks, failures, DisplayServer.get_name()])
	quit(1 if failures else 0)

func inspect(region: String, size: Vector2i):
	root.size = size
	var scene = load("res://game/jungle_pass.tscn" if region == "jungle" else "res://game/hybrid_region.tscn").instantiate()
	var stem := "user://boss_clock_%s_%d_%d" % [region, size.x, Time.get_ticks_usec()]
	scene.profile_save_prefix = stem
	scene.growth_save_prefix = stem + "_growth"
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene.set_physics_process(false)
	scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
	scene._set_paused(false)
	var hud = scene.get_node_or_null("RunFlowHudPresenter")
	check(hud != null, "real scene mounts countdown presenter")
	if hud == null: scene.queue_free(); await process_frame; return
	var profile_before: Dictionary = scene.profile._snapshot()
	var section = scene.temple_section
	check(section != null, "region section mounts actual countdown state")
	if section == null: scene.queue_free(); await process_frame; return
	check(scene.BOSS_TIME == 240.0, "current four-minute preparation contract")
	for entry in [[0.0,"04:00"],[45.0,"03:15"],[179.2,"01:01"],[239.0,"00:01"],[239.99,"00:01"]]:
		scene.run_time = entry[0]
		hud.refresh()
		check(hud.boss_clock.text == "보스까지 " + entry[1], "ceil remaining seconds without early zero")
		layout(scene, hud)
	check(scene.profile._snapshot() == profile_before, "clock refresh never mutates profile")
	# Destination changes cannot replace the independent countdown.
	scene.run_time = 239.0
	section.in_garden = true
	section._update_hud()
	hud.refresh()
	check(not hud.objective.text.is_empty() and hud.boss_clock.text == "보스까지 00:01", "side-area objective retains clock")
	section.in_garden = false
	scene.run_time = 120.0
	hud.refresh()
	await key(KEY_ESCAPE)
	check(paused and scene.pause_menu.visible, "Escape opens actual pause")
	var paused_clock: float = scene.run_time
	scene._physics_process(2.0)
	await create_timer(0.05, true).timeout
	hud.refresh()
	check(scene.run_time == paused_clock and hud.boss_clock.text == "보스까지 02:00", "pause does not spend remaining play time")
	check(hud.boss_clock.visible, "clock persists during pause")
	await key(KEY_ESCAPE)
	check(not paused and not scene.pause_menu.visible, "Escape resumes actual pause")
	scene.growth.gain_xp(scene.growth.next_xp())
	check(scene.growth.choosing and paused, "actual card choice freezes game")
	var card_clock: float = scene.run_time
	scene._physics_process(2.0)
	await create_timer(0.05, true).timeout
	hud.refresh()
	check(scene.run_time == card_clock and hud.boss_clock.text == "보스까지 02:00", "card choice does not spend remaining play time")
	check(hud.boss_clock.get_parent().layer > scene.growth.overlay.get_parent().layer, "clock stays above card backdrop")
	await key(KEY_1)
	check(not scene.growth.choosing and not paused, "card input resumes without changing clock")
	# Real section tick owns the 240-second warning and eventual readiness.
	scene.teleport(scene.player.global_position)
	scene.run_time = 239.0
	section._update_hud()
	hud.refresh()
	await capture("%s-%d-before-ready" % [region, size.x])
	scene._physics_process(1.0)
	hud.refresh()
	check(scene.run_time == 240.0 and scene.boss_announced and not section.boss_ready, "real clock reaches existing warning threshold")
	check(hud.boss_clock.text == "보스 준비 중", "warning state never shows negative countdown")
	section.tick(1.21)
	scene._update_run_hud()
	hud.refresh()
	check(section.boss_ready and hud.boss_clock.text == "보스 준비 완료", "actual spawned boss replaces countdown with ready state")
	check(hud.objective.text.contains("성소") or hud.objective.text.contains("관문"), "ready destination remains separate")
	layout(scene, hud)
	await capture("%s-%d-after-ready" % [region, size.x])
	scene.teleport(section.boss_point + Vector2(150, 150))
	section.tick(0.01)
	scene._update_run_hud()
	hud.refresh()
	check(section.boss_active and scene.boss_health_bar.visible, "real boundary starts boss encounter")
	check(hud.boss_clock.text == "보스 교전 중" and hud.objective.text.contains(scene.boss_name), "clock status survives boss identity change")
	layout(scene, hud)
	# Resize this live encounter, rather than only instantiate at each resolution.
	root.size = Vector2i(1280,720) if size.x == 960 else Vector2i(960,540)
	await process_frame
	layout(scene, hud)
	root.size = size
	await process_frame
	scene.player.health = 0
	scene._physics_process(0.01)
	hud.refresh()
	check(section.retry_pending and paused and hud.boss_clock.text == "보스 재도전 대기", "first boss death keeps retry status")
	check(hud.boss_clock.get_parent().layer > section.retry_overlay.get_parent().layer, "clock stays above retry backdrop")
	var retry_clock: float = scene.run_time
	await key(KEY_ENTER)
	scene._update_run_hud()
	hud.refresh()
	check(section.retry_used and not section.retry_pending and not paused, "actual retry button resumes boss encounter")
	check(scene.run_time == retry_clock and hud.boss_clock.text == "보스 교전 중", "retry retains original run clock")
	layout(scene, hud)
	scene.player.health = 0
	scene._physics_process(0.01)
	hud.refresh()
	check(scene.run_ended and scene.end_result == "DEFEAT", "second boss death follows existing result path")
	check(not hud.boss_clock.visible and not hud.boss_clock_surface.visible, "ended run hides countdown with ordinary HUD")
	scene._show_result()
	hud.refresh()
	check(scene.result_overlay.visible and not hud.boss_clock.visible, "countdown does not cover result actions")
	paused = false
	scene.queue_free()
	await process_frame
	for prefix in [stem, stem + "_growth"]:
		for suffix in ["_a.json", "_b.json"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(prefix + suffix))

func layout(scene, hud):
	var bounds := Rect2(0, 0, 1280, 720)
	check(hud.boss_clock.visible and hud.boss_clock_surface.visible, "clock always visible before run end")
	check(bounds.encloses(hud.boss_clock.get_global_rect()), "clock fits scaled 960/1280 canvas")
	check(hud.boss_clock.get_line_count() <= hud.boss_clock.get_visible_line_count(), "clock text fully readable")
	check(not hud.boss_clock.get_global_rect().intersects(scene.minimap.get_global_rect()), "clock clears minimap")
	check(not hud.boss_clock.get_global_rect().intersects(scene.boss_health_bar.get_global_rect()), "clock clears boss HP")
	if hud.objective.visible: check(not hud.boss_clock_surface.get_global_rect().intersects(hud.objective_surface.get_global_rect()), "clock and destination separated")
	for control in [hud.boss_clock, hud.boss_clock_surface]:
		check(control.mouse_filter == Control.MOUSE_FILTER_IGNORE and control.focus_mode == Control.FOCUS_NONE, "clock cannot intercept modal inputs")

func key(code: Key):
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame

func capture(label: String):
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(capture_dir.path_join(label + ".png")) == OK, "saved actual readiness render")
