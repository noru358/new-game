extends SceneTree

const Catalog = preload("res://game/awakening_catalog.gd")
const PREFIX := "user://verify_discovery_ui"
var failures := 0

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _run() -> void:
	for stem in [PREFIX, PREFIX + "_growth"]:
		for suffix in ["_a.json", "_b.json"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(stem + suffix))
	var profile := RunProfile.new()
	var empty := Catalog.records(profile, 0)
	check(not empty.contains("계곡") and not empty.contains("정원") and not empty.contains("/2"), "unfound places and total secret count stay hidden")
	profile.discovered_places.append("JUNGLE_GROTTO")
	check(Catalog.records(profile, 0).contains("장소 발견") and not Catalog.records(profile, 0).contains("추가 폭발"), "discovery alone does not expose or award the fixed reward")
	profile.awakenings.append("ECHO_GROTTO")
	check(Catalog.status(profile, "ECHO_GROTTO", 6).contains("첫 정복"), "unowned reward gear explains its unlock prerequisite")
	profile.owned_gear["W_ECHO"] = true
	check(Catalog.status(profile, "ECHO_GROTTO", 6).contains("미착용"), "owned but unequipped awakening is not reported as active")
	profile.equipped_weapon = "W_ECHO"
	check(Catalog.status(profile, "ECHO_GROTTO", 0).contains("4타 습득"), "fourth hit mastery prerequisite is visible")
	check(Catalog.status(profile, "ECHO_GROTTO", 3).begins_with("적용 중"), "equipped and learned awakening is active")
	var scene = load("res://game/jungle_pass.tscn").instantiate()
	scene.profile_save_prefix = PREFIX
	scene.growth_save_prefix = PREFIX + "_growth"
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
	var section = scene.temple_section
	var layout = section.layout
	section.enter_garden()
	section.tick(0.0)
	for route in layout.PATHS:
		for point in route.points:
			check(scene.navigation.is_open(point, 30) and not scene.navigation.find_path(layout.FIELD_ENTRY, point).is_empty(), "all authored routes and return passage have usable clearance: %s" % point)
	check(not scene.navigation.has_clear_path(layout.FIELD_ENTRY, layout.ALTAR), "cliff bends prevent a straight shortcut across the field")
	scene.teleport(layout.SECOND_APPROACH)
	section.tick(0.0)
	check(section.started_waves.has(2) and section.wave_kills == 0, "inner enemies can activate without clearing the first group")
	scene.teleport(layout.ALTAR)
	check(section.claim_garden_reward() and section.wave_kills == 0, "finding inner ruins grants the reward without mandatory combat")
	check(paused and scene.awakening_overlay.visible and scene.awakening_receipt.text.contains("획득 전") and scene.awakening_receipt.text.contains("장비 구매"), "receipt explains comparison and actual inactive state")
	var generation: int = scene.profile.generation
	scene._set_paused(true)
	check(scene.awakening_overlay.visible and not scene.pause_menu.visible, "focus loss does not put pause controls over the reward")
	scene._request_retreat()
	check(not scene.retreat_overlay.visible, "reward receipt cannot open a second modal")
	scene._close_awakening_receipt()
	check(not paused and not section.claim_garden_reward() and scene.profile.generation == generation, "closing receipt resumes without regranting the permanent reward")
	scene._set_paused(true)
	check(scene.pause_equipment_label.text.contains("계곡의 메아리") and scene.pause_equipment_label.text.contains("장비 구매"), "pause screen keeps the acquired but inactive reward visible")
	scene.queue_free()
	paused = false
	await process_frame
	var hub = load("res://game/hub.tscn").instantiate()
	hub.profile_save_prefix = PREFIX
	hub.growth_save_prefix = PREFIX + "_growth"
	root.add_child(hub)
	await process_frame
	check(hub.tabs.get_tab_count() == 4 and hub.discovery_records.text.contains("계곡의 메아리") and not hub.discovery_records.text.contains("정원의 불씨"), "camp records reload known rewards without leaking other secrets")
	hub.queue_free()
	await process_frame
	for stem in [PREFIX, PREFIX + "_growth"]:
		for suffix in ["_a.json", "_b.json"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(stem + suffix))
	print("Discovery UI and optional exploration: %d failures" % failures)
	quit(1 if failures else 0)
