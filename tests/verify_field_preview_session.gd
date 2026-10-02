extends SceneTree
const Session = preload("res://game/field_preview_session.gd")
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", note)
func _clear_scene() -> void:
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
	for i in 3: await process_frame
func _add(path: String) -> Node:
	var scene = load(path).instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 4: await physics_frame
	return scene
func _follow_button(button: Button, expected_path: String) -> Node:
	button.pressed.emit()
	for i in 20:
		await physics_frame
		if current_scene != null and current_scene.scene_file_path == expected_path:
			for j in 4: await physics_frame
			return current_scene
	check(false, "wired scene transition to " + expected_path)
	return current_scene
func _run() -> void:
	check(not Session.active(self), "ordinary launch not overridden")
	check(Session.region_scene(self,false)=="res://game/hybrid_region.tscn", "ordinary temple retained")
	var prefix := "user://qa_shared_field_%d" % Time.get_ticks_usec()
	Session.activate(self,prefix+"_profile",prefix+"_unlocks")
	var camp = await _add("res://game/travel_camp.tscn")
	check(camp.preparation.profile.save_prefix == prefix+"_profile", "camp reads shared isolated profile")
	check(not camp.preparation.profile.temple_owned and not camp.preparation.profile.jungle_owned, "new shared journey has no synthetic clear")
	check(camp.preparation.jungle_region_button.disabled, "jungle is genuinely locked before temple")
	for button in camp.preparation.find_children("*", "Button", true, false):
		check(not "시험용 해금" in button.text, "development bypass absent in shared campaign")
	var run = await _follow_button(camp.preparation.start_button, Session.region_scene(self,false))
	check(run.profile.save_prefix == prefix+"_profile", "candidate run shares camp economy")
	check(run.growth.unlocks.save_prefix == prefix+"_unlocks", "candidate unlock progression shares camp")
	run.run_currency = 100
	run._finish_run("SUCCESS") # State-contract fixture, not a claimed player win.
	var expected: int = run.profile.currency
	check(run.profile.temple_owned, "temple settlement unlocks jungle")
	for i in 120:
		if run.result_overlay.visible: break
		await physics_frame
	check(run.result_overlay.visible, "result transition finishes before return")
	camp = await _follow_button(run.replay_button,"res://game/travel_camp.tscn")
	var hub = camp.preparation
	check(hub.profile.currency == expected, "earned settlement visible back in camp")
	check(not hub.jungle_region_button.disabled, "earned jungle access visible")
	hub._select_gear("W_FLOW")
	hub._gear_action()
	check(hub.profile.owned_gear.has("W_FLOW"), "purchase recorded")
	check(hub.profile.equipped_weapon != "W_FLOW", "purchase does not auto-equip")
	hub._gear_action()
	check(hub.profile.equipped_weapon == "W_FLOW", "explicit equip recorded")
	hub._buy_growth("VITALITY")
	var balance: int = hub.profile.currency
	hub._select_region(RunProfile.JUNGLE_REGION)
	run = await _follow_button(hub.start_button,Session.region_scene(self,true))
	check(run.profile.currency == balance, "jungle does not inject synthetic first-clear money")
	check(run.profile.equipped_weapon == "W_FLOW", "next map uses camp equipment")
	check(run.player.max_health == 110, "next map uses purchased health growth")
	check(run.growth.unlocks.lifetime_levelups == 0, "jungle does not inject six lifetime levelups")
	await _clear_scene()
	root.remove_meta(Session.KEY)
	check(Session.region_scene(self,true)=="res://game/jungle_pass.tscn", "ordinary launch restored after test session")
	var folder := DirAccess.open("user://")
	for file in folder.get_files():
		if file.begins_with(prefix.trim_prefix("user://")): folder.remove(file)
	print("Shared field session: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
