extends SceneTree

const PREFIX := "user://verify_audit_feedback"
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _run() -> void:
	_cleanup()
	var scene = load("res://game/hybrid_region.tscn").instantiate()
	scene.profile_save_prefix = PREFIX + "_profile"
	scene.growth_save_prefix = PREFIX + "_unlocks"
	root.add_child(scene)
	await physics_frame
	scene.player.set_physics_process(false)
	scene.player.health = 30.0
	scene.player.hurt_immunity = 0.0
	scene.player.receive_hit(10.0, scene.player.position + Vector2.LEFT)
	scene._update_hud()
	scene._process(0.0)
	_check(scene.player_health_bar.value == 20.0 and scene.player_health_warning.visible, "HP bar and low-health warning reflect received damage")
	var body: Sprite3D = scene.actors[scene.player].get_node("Body")
	scene.player.hit_flash = 0.20
	scene._process(0.0)
	_check(body.modulate != Color.WHITE, "hurt flash changes the visible hybrid player")
	scene.player.hit_flash = 0.0
	scene.player.hurt_immunity = 0.50
	scene._process(0.0)
	_check(body.modulate.a < 1.0, "remaining hurt immunity is visible")
	scene.growth.apply_card("U_EDGE")
	scene._update_hud()
	_check(scene.build_summary_label.text.contains("마력 날") and scene.build_summary_label.text.contains("1회"), "summary counts chosen cards without the initial dash rank")
	scene._set_paused(true)
	_check(scene.pause_menu.visible and scene.build_details_label.text.contains("마력 날") and paused, "pause shows the full selected build")
	scene._request_retreat()
	scene._cancel_retreat()
	_check(scene.paused and scene.pause_menu.visible and not scene.retreat_overlay.visible, "cancel from pause returns to pause")
	scene._set_paused(false)
	scene.run_currency = 8
	scene.player.health = 0.0
	scene._finish_run("DEFEAT")
	_check(not scene.hud.text.contains("R로 다시"), "live-run death does not advertise the sandbox restart shortcut")
	var banked: int = scene.profile.currency
	_check(scene.run_ended and not scene.result_overlay.visible and scene.profile.last_lost == 4, "ending settles safely before its visual delay")
	scene._set_paused(false)
	_check(paused, "ending cannot resume combat through pause controls")
	scene._process(0.81)
	scene._finish_run("SUCCESS")
	_check(scene.result_overlay.visible and scene.profile.currency == banked and scene.end_result == "DEFEAT", "result appears after delay without a second settlement")
	scene.queue_free()
	paused = false
	await process_frame
	for suffix in ["_a.json", "_b.json"]:
		var file := FileAccess.open(PREFIX + "_profile" + suffix, FileAccess.WRITE)
		file.store_string("broken")
		file.close()
	var hub = load("res://game/hub.tscn").instantiate()
	hub.profile_save_prefix = PREFIX + "_profile"
	hub.growth_save_prefix = PREFIX + "_unlocks"
	root.add_child(hub)
	await process_frame
	_check(hub.profile.load_error and hub.save_folder_button.visible and hub.start_button.disabled, "corrupt profile exposes recovery help without overwriting or allowing play")
	hub.queue_free()
	await process_frame
	_cleanup()
	if failures == 0: print("Audit feedback verification passed: hurt, build, retreat, ending, save recovery help")
	quit(1 if failures else 0)


func _cleanup() -> void:
	for prefix in [PREFIX + "_profile", PREFIX + "_unlocks"]:
		for suffix in ["_a.json", "_b.json"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(prefix + suffix))
