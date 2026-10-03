extends SceneTree
## Synthetic positions/time/access, real section transitions and rendered UI.
## Not natural play, combat pressure, balance, or a first-run timing measurement.
## -- --capture-dir=<fresh absolute directory>
## Isolate userdata under WorldDestinationLabelsV48 (or WetlandV44) before launch.
const SIZES := [Vector2i(960, 540), Vector2i(1280, 720)]
const REGIONS := [["temple", "temple_circuit_run", "성소"], ["jungle", "jungle_south_circuit", "관문"], ["wetland", "deep_wetland_run", "안쪽 성소"]]
var output := ""
var errors: Array[String] = []
var captures: Array[Dictionary] = []
var scene
var started := 0
var finished := false

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)
		printerr("FAIL: ", message)

func _run() -> void:
	# All guards precede constructing any scene/profile or writing evidence.
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			if not output.is_empty():
				printerr("FAIL: specify --capture-dir only once")
				quit(1)
				return
			output = argument.trim_prefix("--capture-dir=")
	if DisplayServer.get_name() == "headless" or (RenderingServer.get_rendering_device() == null and RenderingServer.get_video_adapter_name().is_empty()):
		printerr("FAIL: real renderer required; headless capture is not supported")
		quit(1)
		return
	if output.is_empty() or not output.is_absolute_path() or not ("WorldDestinationLabelsV48" in OS.get_user_data_dir() or "WetlandV44" in OS.get_user_data_dir()):
		printerr("FAIL: fresh absolute output and isolated WorldDestinationLabelsV48/WetlandV44 userdata required")
		quit(1)
		return
	if DirAccess.dir_exists_absolute(output) and not DirAccess.get_files_at(output).is_empty():
		printerr("FAIL: existing evidence is never overwritten")
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		printerr("FAIL: cannot create output directory")
		quit(1)
		return
	started = Time.get_ticks_usec()
	Engine.time_scale = 1.0
	Engine.max_fps = 60
	for size in SIZES:
		root.size = size
		root.content_scale_size = Vector2i(1280, 720)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		for region in REGIONS:
			await inspect(region, size)
			if not errors.is_empty(): break
		if not errors.is_empty(): break
	check(captures.size() == 50, "all 50 expected graphical states captured")
	_finish()

func inspect(region: Array, size: Vector2i) -> void:
	var stem := "user://destination_render_%s_%d_%d" % [region[0], size.x, Time.get_ticks_usec()]
	var profile := RunProfile.new()
	profile.save_prefix = stem
	check(profile.settle("fixture-temple", "SUCCESS", 0, RunProfile.TEMPLE_REGION), "isolated temple access")
	check(profile.settle("fixture-jungle", "SUCCESS", 0, RunProfile.JUNGLE_REGION), "isolated jungle access")
	scene = load("res://game/%s.tscn" % region[1]).instantiate()
	scene.profile_save_prefix = stem
	scene.growth_save_prefix = stem + "_growth"
	root.add_child(scene)
	current_scene = scene
	var section = scene.temple_section
	check(section.destination_label.text == region[2], "%s initial text before tick" % region[0])
	# _ready has initialized the real run. Keep base actor/camera sync alive.
	scene.practice_mode = true
	_freeze_pressure()
	var outside := _near_outside(section)
	if outside == Vector2.INF:
		check(false, "%s no walkable near-outside fixture position" % region[0])
		await _clear()
		return
	var inside: Vector2 = section.boss_point + Vector2(0, 180)
	check(scene.navigation.is_open(inside, scene.ACTOR_CLEARANCE) and section.boss_area.has_point(inside), "%s playable inside fixture" % region[0])
	scene.teleport(outside)
	scene.run_time = 0.0
	section.tick(0.0)
	await _capture(region, size, "near-before-ready", true, "보스까지 04:00")
	scene.run_time = scene.BOSS_TIME
	section.tick(0.0)
	section.tick(1.3)
	check(section.boss_ready and is_instance_valid(scene.boss), "real waiting boss spawned")
	await _capture(region, size, "ready-outside", true, "보스 준비 완료")
	scene.teleport(inside)
	section.tick(0.0)
	await _capture(region, size, "active", false, "보스 교전 중")
	scene.boss.health -= 7.0
	var hp: float = scene.boss.health
	scene.teleport(outside)
	section.tick(0.0)
	check(scene.boss.health == hp, "leave preserves damaged boss HP")
	await _capture(region, size, "leave", true, "보스 준비 완료")
	scene.teleport(inside)
	section.tick(0.0)
	check(scene.boss.health == hp, "reentry preserves damaged boss HP")
	await _capture(region, size, "reenter", false, "보스 교전 중")
	scene.player.health = 0.0
	check(section.handle_death() and section.retry_overlay.visible, "real retry prompt")
	await _capture(region, size, "retry-pending", false, "보스 재도전 대기")
	section.retry_boss()
	check(section.retry_used and not section.retry_pending and scene.player.health == scene.player.max_health, "real retry restores player")
	await _capture(region, size, "retry", false, "보스 교전 중")
	if region[0] != "wetland":
		scene.teleport(outside)
		section.tick(0.0)
		section.enter_garden()
		check(section.in_garden, "real supported hidden transition")
		section.tick(0.0)
		await _capture(region, size, "garden-entry", false, "보스 준비 완료")
		section.leave_garden()
		check(not section.in_garden, "real supported hidden return")
		section.tick(0.0)
		var nearby: bool = scene.player.position.distance_to(section.destination_point) < 650.0
		await _capture(region, size, "garden-return", nearby, "보스 준비 완료")
	await _clear()

func _near_outside(section) -> Vector2:
	# Static sample only; choose navigable ground near this region's actual label.
	for radius in [120.0, 240.0, 360.0]:
		for direction in [Vector2.LEFT, Vector2.DOWN, Vector2.RIGHT, Vector2.UP]:
			var point: Vector2 = section.destination_point + direction * radius
			if not section.boss_area.has_point(point) and scene.player.arena_bounds.has_point(point) and scene.navigation.is_open(point, scene.ACTOR_CLEARANCE): return point
	return Vector2.INF

func _freeze_pressure() -> void:
	scene.wisp.set_physics_process(false)
	for actor in scene.actors:
		if actor != scene.player: actor.set_physics_process(false)

func _capture(region: Array, size: Vector2i, state: String, shown: bool, clock: String) -> void:
	_freeze_pressure()
	var section = scene.temple_section
	var hud = scene.get_node("RunFlowHudPresenter")
	var fixed_time: float = scene.run_time
	# Normal follow settles; process_always allows photographing the real retry modal.
	await create_timer(0.9, true).timeout
	scene._update_hud()
	scene._update_run_hud()
	if is_instance_valid(scene.boss): scene._animate_boss_figure()
	hud.refresh()
	var label: Label3D = section.destination_label
	var name := "%s-%d-%s" % [region[0], size.x, state]
	check(label.text == region[2] and label.is_visible_in_tree() == shown, name + " concise label/visibility")
	check(hud.boss_clock.visible and hud.boss_clock.text == clock, name + " independent clock/status")
	check(scene.run_time == fixed_time, name + " pressure clock frozen")
	if section.boss_active:
		check(scene.boss_health_bar.visible and hud.objective.text.contains(scene.boss_name), name + " intact HP/identity")
	var actor_error: float = scene.actors[scene.player].position.distance_to(scene.terrain.world_point(scene.player.position))
	var camera_error: float = scene.camera.position.distance_to(scene.terrain.world_point(scene.player.position, 35) + scene.camera_offset)
	check(actor_error < 0.03 and camera_error < 0.03, name + " actor/camera follow settled")
	if shown:
		check(not scene.camera.is_position_behind(label.global_position) and root.get_visible_rect().has_point(scene.camera.unproject_position(label.global_position)), name + " label anchor within viewport")
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(not image.is_empty() and image.get_size() == size, name + " actual rendered image dimensions")
	if not errors.is_empty(): return
	var filename := name + ".png"
	check(image.save_png(output.path_join(filename)) == OK, name + " PNG saved")
	captures.append({"file": filename, "region": region[0], "state": state, "width": size.x, "height": size.y, "label": label.text, "world_label_visible": shown, "boss_clock": hud.boss_clock.text, "boss_hp_visible": scene.boss_health_bar.visible, "player_position": [scene.player.position.x, scene.player.position.y], "actor_error": actor_error, "camera_error": camera_error, "render": true})

func _clear() -> void:
	paused = false
	scene.queue_free()
	current_scene = null
	for i in 3: await process_frame
	scene = null

func _process(_delta: float) -> bool:
	if started > 0 and not finished and Time.get_ticks_usec() - started > 180000000:
		check(false, "180-second render fixture watchdog expired")
		_finish()
	return false

func _finish() -> void:
	if finished: return
	finished = true
	var report := {"fixture": "world-destination-labels", "renderer": DisplayServer.get_name(), "adapter": RenderingServer.get_video_adapter_name(), "limitations": "Synthetic access, teleport positions and injected boss-ready time; actual section boundary, retry and supported garden transitions. Practice-mode pressure freeze after readiness, ordinary actor/camera sync. Not natural play or visual acceptance.", "expected_pngs": 50, "captures": captures, "errors": errors}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	if file == null: check(false, "cannot save report")
	else:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("World destination render: %d / 50 PNGs, %d failures" % [captures.size(), errors.size()])
	quit(1 if not errors.is_empty() else 0)
