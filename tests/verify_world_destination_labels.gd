extends SceneTree
## World labels only; exercise mounted sections and the independent HUD.
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _run() -> void:
	for entry in [["hybrid_region", "성소"], ["jungle_pass", "관문"], ["deep_wetland_run", "안쪽 성소"]]:
		await inspect(entry[0], entry[1])
	print("World destination labels: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func inspect(region: String, place: String) -> void:
	var scene = load("res://game/%s.tscn" % region).instantiate()
	var stem := "user://world_destination_%s_%d" % [region, Time.get_ticks_usec()]
	scene.profile_save_prefix = stem
	scene.growth_save_prefix = stem + "_growth"
	var profile := RunProfile.new()
	profile.save_prefix = stem
	check(profile.settle("temple-access", "SUCCESS", 0, RunProfile.TEMPLE_REGION), region + " isolated access fixture")
	check(profile.settle("jungle-access", "SUCCESS", 0, RunProfile.JUNGLE_REGION), region + " isolated wetland access fixture")
	root.add_child(scene)
	current_scene = scene
	# No frame or tick before this assertion: subclasses must start with their own name.
	var section = scene.temple_section
	check(section.destination_label.text == place, region + " concise initial build before first tick")
	check(section.destination_label.visible == (scene.player.position.distance_to(section.destination_point) < 650.0), region + " initial proximity gate")
	scene.set_physics_process(false)
	scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
	scene._set_paused(false)
	await process_frame
	var hud = scene.get_node("RunFlowHudPresenter")
	var outside: Vector2 = section.boss_area.position - Vector2(80, -section.boss_area.size.y * 0.5)
	# Wetland label is beside the southern entrance rather than the western edge.
	if region == "deep_wetland_run": outside = Vector2(section.destination_point.x, section.boss_area.end.y + 30)
	check(outside.distance_to(section.destination_point) < 650.0 and not section.boss_area.has_point(outside), region + " near outside fixture")
	scene.teleport(outside)
	scene.run_time = 0.0
	section.tick(0.0)
	assert_label(scene, hud, place, true, "보스까지 04:00", "before ready")
	scene.teleport(section.destination_point + Vector2(-900, 0))
	section.tick(0.0)
	assert_label(scene, hud, place, false, "보스까지 04:00", "far away")
	scene.teleport(outside)
	scene.run_time = scene.BOSS_TIME
	section.tick(0.0)
	assert_label(scene, hud, place, true, "보스 준비 중", "spawn warning")
	section.tick(1.3)
	check(section.boss_ready and is_instance_valid(scene.boss), region + " actual boss ready")
	assert_label(scene, hud, place, true, "보스 준비 완료", "ready outside")
	scene.boss.set_physics_process(false)
	scene.teleport(section.boss_area.get_center())
	section.tick(0.0)
	assert_label(scene, hud, place, false, "보스 교전 중", "active")
	check(scene.boss_health_bar.visible and hud.objective.text.contains(scene.boss_name), region + " boss HP and identity remain")
	scene.boss.health -= 7.0
	var boss_hp: float = scene.boss.health
	for crossing in 2:
		scene.teleport(outside)
		section.tick(0.0)
		assert_label(scene, hud, place, true, "보스 준비 완료", "leave %d" % crossing)
		check(scene.boss.health == boss_hp, region + " leaving preserves boss HP")
		scene.teleport(section.boss_area.get_center())
		section.tick(0.0)
		assert_label(scene, hud, place, false, "보스 교전 중", "reenter %d" % crossing)
		check(scene.boss.health == boss_hp and scene.boss_health_bar.visible, region + " reentry preserves boss HP display")
	scene.player.health = 0.0
	check(section.handle_death(), region + " real retry offered")
	assert_label(scene, hud, place, false, "보스 재도전 대기", "retry pending")
	check(section.retry_overlay.visible and section.retry_overlay.get_node("Retry").text.length() > 0, region + " retry guidance intact")
	section.retry_boss()
	assert_label(scene, hud, place, false, "보스 교전 중", "retry before tick")
	check(section.retry_used and scene.boss_health_bar.visible, region + " retry resumes HP display")
	scene.teleport(outside)
	section.tick(0.0)
	if region != "deep_wetland_run":
		section.enter_garden()
		check(section.in_garden and not section.destination_label.is_visible_in_tree(), region + " actual hidden transition before tick")
		section.tick(0.0)
		assert_label(scene, hud, place, false, "보스 준비 완료", "hidden field")
		section.leave_garden()
		check(not section.in_garden, region + " actual hidden return")
	else:
		# Wetland has no hidden field; test inherited presentation gate without inventing one.
		section.in_garden = true
		section.tick(0.0)
		assert_label(scene, hud, place, false, "보스 준비 완료", "synthetic hidden gate")
		section.in_garden = false
	scene.teleport(outside)
	section.tick(0.0)
	assert_label(scene, hud, place, true, "보스 준비 완료", "return outside")
	# World-label suppression must not swallow independent error/unlock/reward notices.
	var before: Dictionary = scene.profile._snapshot()
	section.garden_message = "각성 저장 실패 · 지급하지 않았습니다. E로 재시도"
	hud.refresh()
	hud._process(8.0)
	check(hud.notice.visible and hud.notice.text == section.garden_message, region + " persistent save retry guidance")
	section.garden_message = ""
	scene.growth.unlock_notice = "이동 베기 영구 습득 · Space"
	hud.refresh()
	check(hud.notice.visible and hud.notice.text.contains(scene.growth.unlock_notice), region + " unlock guidance")
	section.garden_message = "정원 각성 저장 완료 · 여우불 장신구 마탄 +20%p / 연쇄 +1\n야영지에서 여우불 장신구를 구매·장착하면 적용됩니다."
	hud.refresh()
	check(hud.notice.visible and hud.notice.text.contains(section.garden_message), region + " full reward purchase/equipment guidance")
	check(scene.profile._snapshot() == before, region + " presentation leaves profile unchanged")
	paused = false
	scene.queue_free()
	await process_frame
	for prefix in [stem, stem + "_growth"]:
		for suffix in ["_a.json", "_b.json"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(prefix + suffix))

func assert_label(scene, hud, place: String, shown: bool, clock: String, state: String) -> void:
	scene._update_run_hud()
	hud.refresh()
	var label: Label3D = scene.temple_section.destination_label
	check(label.text == place and not label.text.contains("\n"), place + " " + state + " only place name")
	check(label.is_visible_in_tree() == shown, place + " " + state + " world label visibility")
	check(hud.boss_clock.visible and hud.boss_clock.text == clock, place + " " + state + " independent clock/status")
