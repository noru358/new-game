extends SceneTree
## Real AudioServer gain, persistence and scene/input ownership checks.
## TEST_SETTINGS_CAPTURE_DIR adds GL screenshots; headless skips display assertion.
const Preferences = preload("res://game/play_settings.gd")
const SettingsPanel = preload("res://game/play_settings_panel.gd")
var checks := 0
var failures := 0
var capture_dir := ""
var initial_db := 0.0
var initial_mute := false
var initial_mode := Window.MODE_WINDOWED

func _initialize() -> void:
	call_deferred("_restart_probe" if "--settings-restart-probe" in OS.get_cmdline_user_args() else "_run")

func _restart_probe() -> void:
	var preferences = Preferences.new()
	preferences.config_path = "user://verify_play_settings.cfg"
	preferences.setup(root)
	var bus := AudioServer.get_bus_index("Master")
	var okay: bool = is_equal_approx(preferences.volume_percent, 37) and preferences.muted and is_equal_approx(AudioServer.get_bus_volume_db(bus), linear_to_db(0.37)) and AudioServer.is_bus_mute(bus)
	print("Settings fresh-process restore: ", okay)
	quit(0 if okay else 1)
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)

func _run() -> void:
	var original_slots := _normal_slots()
	var bus := AudioServer.get_bus_index("Master")
	initial_db = AudioServer.get_bus_volume_db(bus)
	initial_mute = AudioServer.is_bus_mute(bus)
	initial_mode = root.mode
	capture_dir = OS.get_environment("TEST_SETTINGS_CAPTURE_DIR")
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	await _preferences()
	for dimensions in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.mode = Window.MODE_WINDOWED
		root.size = dimensions
		root.content_scale_size = Vector2i(1280, 720)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		await _camp(dimensions)
		await _region("temple", dimensions)
		await _region("jungle", dimensions)
	await _unpaused_guard()
	check(_normal_slots() == original_slots, "all regular profile/unlock/settings files preserve bytes or absence")
	# Scene setup owns the existing input map, never the settings helper.
	var input_after := _input_events()
	var preferences = Preferences.new()
	preferences.config_path = "user://verify_play_settings.cfg"
	preferences.setup(root)
	check(_input_events() == input_after, "loading settings never remaps or erases game actions")
	AudioServer.set_bus_volume_db(bus, initial_db)
	AudioServer.set_bus_mute(bus, initial_mute)
	root.mode = initial_mode
	print("Play settings: %d checks, %d failures (%s)" % [checks, failures, DisplayServer.get_name()])
	quit(1 if failures else 0)

func _preferences() -> void:
	var path := "user://verify_play_settings.cfg"
	DirAccess.remove_absolute(path)
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, -3.25)
	AudioServer.set_bus_mute(bus, true)
	var preferences = Preferences.new()
	preferences.config_path = path
	var original_mode := root.mode
	preferences.setup(root)
	check(is_equal_approx(AudioServer.get_bus_volume_db(bus), -3.25) and AudioServer.is_bus_mute(bus), "absent file preserves exact engine gain and mute")
	check(root.mode == original_mode, "absent file preserves window mode")
	preferences.set_muted(false)
	preferences.set_volume(50)
	check(is_equal_approx(AudioServer.get_bus_volume_db(bus), linear_to_db(0.5)), "50 percent is half linear Master amplitude")
	check(not AudioServer.is_bus_mute(bus), "unmuted half volume reaches Master")
	preferences.set_volume(0)
	check(AudioServer.is_bus_mute(bus) and is_finite(AudioServer.get_bus_volume_db(bus)), "zero volume is silent without infinite gain")
	preferences.set_volume(100)
	check(is_zero_approx(AudioServer.get_bus_volume_db(bus)) and not AudioServer.is_bus_mute(bus), "100 percent restores unity gain")
	preferences.set_muted(true)
	preferences.set_volume(37)
	check(AudioServer.is_bus_mute(bus), "moving volume while muted preserves mute")
	check(preferences.save_preferences() == OK, "separate ConfigFile writes successfully")
	var restart_output: Array = []
	var restart_code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/verify_play_settings.gd", "--", "--settings-restart-probe"], restart_output, true)
	check(restart_code == 0 and "Settings fresh-process restore: true" in str(restart_output), "new engine process reads and applies saved ConfigFile")
	AudioServer.set_bus_volume_db(bus, 0)
	AudioServer.set_bus_mute(bus, false)
	var restarted = Preferences.new()
	restarted.config_path = path
	restarted.setup(root)
	check(is_equal_approx(restarted.volume_percent, 37) and restarted.muted, "new helper restores saved gain and mute")
	check(is_equal_approx(AudioServer.get_bus_volume_db(bus), linear_to_db(0.37)) and AudioServer.is_bus_mute(bus), "restored settings apply to actual Master")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(960, 540)
	await create_timer(0.25).timeout
	print("Window baseline mode ", root.mode)
	var windowed_size := root.size
	var windowed_position := root.position
	restarted.set_fullscreen(true)
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless": check(root.mode == Window.MODE_FULLSCREEN, "actual display switches to fullscreen")
	check(restarted.save_preferences() == OK, "fullscreen preference saves")
	var config := ConfigFile.new()
	check(config.load(path) == OK and config.get_value("display", "mode") == "fullscreen", "display mode persists in dedicated config")
	restarted.set_fullscreen(false)
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		check(root.mode == Window.MODE_WINDOWED, "actual display returns to windowed")
		print("Window geometry expected ", windowed_size, " @ ", windowed_position, "; actual ", root.size, " @ ", root.position)
		check(root.size == windowed_size and root.position == windowed_position, "windowed geometry is restored after fullscreen")
	var safe_mode := root.mode
	for invalid in [-1.0, 101.0, "loud", INF, true, Vector2.ONE]:
		config = ConfigFile.new()
		config.set_value("settings", "version", 1)
		config.set_value("audio", "master_volume", invalid)
		config.set_value("audio", "muted", "yes")
		config.set_value("display", "mode", 999)
		config.save(path)
		AudioServer.set_bus_volume_db(bus, -4.75)
		AudioServer.set_bus_mute(bus, false)
		var invalid_settings = Preferences.new()
		invalid_settings.config_path = path
		invalid_settings.setup(root)
		check(is_equal_approx(AudioServer.get_bus_volume_db(bus), -4.75) and not AudioServer.is_bus_mute(bus), "invalid config values preserve safe runtime defaults: " + str(invalid))
		check(root.mode == safe_mode, "invalid display never changes window mode")
	for content in ["broken[=file", "[settings]\nversion=999\n[audio]\nmaster_volume=2\nmuted=true\n"]:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(content)
		file.close()
		preferences.setup(root)
		check(is_equal_approx(AudioServer.get_bus_volume_db(bus), -4.75), "corrupt or unsupported config preserves current gain")
	preferences.config_path = "user://verify_settings_absent_%d/settings.cfg" % Time.get_ticks_usec()
	check(preferences.save_preferences() != OK, "write failure is reported")
	DirAccess.remove_absolute(path)
	AudioServer.set_bus_volume_db(bus, initial_db)
	AudioServer.set_bus_mute(bus, initial_mute)

func _mounted_panel(scene) -> CanvasLayer:
	# Production verification must catch a missing scene mount, not replace it.
	var existing = scene.get("settings_panel")
	check(existing != null, "real scene mounts the settings panel")
	check(scene.get("settings_button") is Button, "real scene exposes a settings entry")
	if existing != null:
		existing.preferences.config_path = "user://verify_play_settings_panel.cfg"
		return existing
	return null

func _camp(dimensions: Vector2i) -> void:
	var scene = load("res://game/travel_camp.tscn").instantiate()
	var stem := "user://verify_settings_camp_%d" % dimensions.x
	scene.profile_save_prefix = stem
	scene.growth_save_prefix = stem + "_growth"
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var panel := _mounted_panel(scene)
	var before := scene.player_visual.position as Vector3
	if scene.get("settings_button") != null:
		scene.settings_button.grab_focus()
		await _key(KEY_ESCAPE)
	else: panel.open()
	check(panel.is_open() and paused, "camp Esc opens settings and freezes walking")
	await _key(KEY_E)
	await _key(KEY_G)
	check(not scene.preparation.visible and scene.player_visual.position == before, "camp settings consume station/game hotkeys")
	await _layout_and_capture(panel, "camp-%d" % dimensions.x)
	panel.display_choice.show_popup()
	await process_frame
	check(panel.display_choice.get_popup().visible, "display picker opens")
	await _key(KEY_ESCAPE)
	check(panel.is_open() and not panel.display_choice.get_popup().visible and paused, "first Escape closes display picker without leaving settings")
	panel.volume_slider.value = 42
	panel.mute_button.button_pressed = true
	check(is_equal_approx(panel.preferences.volume_percent, 42) and panel.preferences.muted, "panel controls update actual preferences")
	await _key(KEY_ESCAPE)
	check(not panel.is_open() and not paused, "camp Esc closes settings and restores running state")
	if scene.get("settings_button") != null:
		check(root.gui_get_focus_owner() == scene.settings_button, "camp close restores opener focus")
		await _key(KEY_ESCAPE)
		panel.back_button.pressed.emit()
		check(not paused, "camp repeated open and Back restore running state")
	# Existing station Esc closes preparation instead of opening settings.
	scene.preparation.show()
	await _key(KEY_ESCAPE)
	check(not scene.preparation.visible and not panel.is_open(), "camp station Escape keeps existing close behavior")
	await _release_scene(scene)

func _region(region: String, dimensions: Vector2i) -> void:
	var scene = load("res://game/jungle_pass.tscn" if region == "jungle" else "res://game/hybrid_region.tscn").instantiate()
	var stem := "user://verify_settings_%s_%d" % [region, dimensions.x]
	scene.profile_save_prefix = stem
	scene.growth_save_prefix = stem + "_growth"
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene.set_physics_process(false)
	scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
	scene._set_paused(false)
	var panel := _mounted_panel(scene)
	await _key(KEY_ESCAPE)
	check(scene.paused and scene.pause_menu.visible, region + " Esc opens existing pause menu")
	if scene.get("settings_button") != null:
		scene.settings_button.grab_focus()
		scene.settings_button.pressed.emit()
	else: panel.open()
	var overview: bool = scene.overview
	await _key(KEY_G)
	await _key(KEY_R)
	await _key(KEY_1)
	check(panel.is_open() and not scene.retreat_overlay.visible and not scene.run_ended and scene.overview == overview, region + " settings block gameplay hotkeys")
	await _layout_and_capture(panel, "%s-%d" % [region, dimensions.x])
	await _key(KEY_ESCAPE)
	check(not panel.is_open() and scene.paused and paused and scene.pause_menu.visible, region + " settings Esc returns to paused menu")
	if scene.get("settings_button") != null: check(root.gui_get_focus_owner() == scene.settings_button, region + " settings restore pause opener focus")
	await _key(KEY_ESCAPE)
	check(not scene.paused and not paused, region + " second Esc resumes existing combat")
	# Freeze simulation while allowing the real player input handler to receive keys.
	scene.player.process_mode = Node.PROCESS_MODE_ALWAYS
	scene.player.set_physics_process(false)
	scene.player.attack_blocked_until_release = false
	var slash_before: bool = scene.player.moving_slash_enabled
	scene.player.moving_slash_enabled = true
	await _key(KEY_J)
	check(scene.player.queued_attack, region + " attack input reaches player after settings close")
	await _key(KEY_SHIFT)
	check(scene.player.dash_requested, region + " dash input reaches player after settings close")
	await _key(KEY_SPACE)
	check(scene.player.moving_slash_requested, region + " moving-slash input reaches player after settings close")
	scene.player.queued_attack = false
	scene.player.dash_requested = false
	scene.player.moving_slash_requested = false
	scene.player.moving_slash_enabled = slash_before
	scene.player.process_mode = Node.PROCESS_MODE_INHERIT
	await _key(KEY_TAB)
	check(scene.overview != overview, region + " map hotkey works after close")
	await _key(KEY_TAB)
	await _key(KEY_G)
	check(scene.retreat_overlay.visible and paused, region + " retreat hotkey works after close")
	await _key(KEY_ESCAPE)
	check(not scene.retreat_overlay.visible and not paused, region + " retreat cancel retains original running state")
	# Defensive coverage: another modal already owns the paused tree.
	scene.growth.choosing = true
	paused = true
	panel.open()
	panel.close()
	check(paused and scene.growth.choosing, region + " settings never resume an underlying level-up")
	scene.growth.choosing = false
	scene.temple_section.retry_pending = true
	panel.open()
	panel.close()
	check(paused and scene.temple_section.retry_pending, region + " settings never resume an underlying boss retry")
	scene.temple_section.retry_pending = false
	check(is_equal_approx(scene.player.attack_audio.volume_db, -7.0) and is_equal_approx(scene.player.impact_audio.volume_db, -8.0), region + " authored player relative dB levels unchanged")
	check(scene.player.attack_audio.bus == "Master" and scene.player.impact_audio.bus == "Master", region + " existing player audio actually routes through Master")
	check(scene.wisp.shot_audio.bus == "Master" and is_equal_approx(scene.wisp.shot_audio.volume_db, -11.0), region + " companion audio retains its relative level through Master")
	await _release_scene(scene)

func _unpaused_guard() -> void:
	var owner_node := Node.new()
	root.add_child(owner_node)
	var panel = SettingsPanel.new()
	panel.setup(owner_node, "user://verify_play_settings_panel.cfg")
	paused = false
	panel.can_resume = func(): return false
	panel.open()
	panel.close()
	check(paused, "a newly active modal guard prevents unpausing after direct open")
	panel.preferences.config_path = "user://verify_settings_panel_absent_%d/settings.cfg" % Time.get_ticks_usec()
	panel.open()
	panel.volume_slider.value = 27
	check(panel.save_notice.text.contains("설정을 저장하지 못했습니다"), "settings write failure remains visible in panel")
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))), 0.27), "failed persistence still applies the immediate gain")
	panel.close()
	await _release_scene(owner_node)

func _layout_and_capture(panel: CanvasLayer, tag: String) -> void:
	await process_frame
	await process_frame
	var bounds: Rect2 = panel.backdrop.get_global_rect()
	check(bounds.encloses(panel.panel.get_global_rect()), tag + " panel fits viewport")
	var prior := Rect2()
	for control: Control in [panel.volume_slider, panel.mute_button, panel.display_choice, panel.save_notice, panel.back_button]:
		check(panel.panel.get_global_rect().encloses(control.get_global_rect()), tag + " control fits panel: " + control.name)
		if prior.has_area(): check(not prior.intersects(control.get_global_rect()), tag + " controls do not overlap")
		prior = control.get_global_rect()
	for index in 4:
		await _key(KEY_TAB)
		check(root.gui_get_focus_owner() in [panel.volume_slider, panel.mute_button, panel.display_choice, panel.back_button], tag + " Tab stays inside settings")
	if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(capture_dir.path_join(tag + ".png")) == OK, tag + " actual GL capture saved")

func _key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func _release_scene(scene: Node) -> void:
	paused = false
	scene.queue_free()
	await process_frame
	await process_frame

func _normal_slots() -> Dictionary:
	var records := {}
	for stem in ["user://loop_conquest_profile", "user://loop_conquest_1d_unlocks"]:
		for suffix in ["_a.json", "_b.json"]:
			var path: String = stem + suffix
			records[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
	records[Preferences.DEFAULT_PATH] = FileAccess.get_sha256(Preferences.DEFAULT_PATH) if FileAccess.file_exists(Preferences.DEFAULT_PATH) else "absent"
	return records

func _input_events() -> Dictionary:
	var result := {}
	for action in InputMap.get_actions():
		result[action] = []
		for event in InputMap.action_get_events(action): result[action].append(event.as_text())
	return result
