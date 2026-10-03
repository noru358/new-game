extends SceneTree
## Real player input/physics at normal speed; combat/time pressure is frozen.
## This verifies transition contracts, not a natural run or human place acceptance.
var failures := 0
var checks := 0
var reports := []
var scene

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)
func _release() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(action)
func _press(direction: Vector2) -> void:
	_release()
	var input := direction.rotated(-scene.player.input_rotation)
	if input.x < -0.1: Input.action_press("move_left", -input.x)
	if input.x > 0.1: Input.action_press("move_right", input.x)
	if input.y < -0.1: Input.action_press("move_up", -input.y)
	if input.y > 0.1: Input.action_press("move_down", input.y)
func _step() -> void:
	await physics_frame
	scene.temple_section.tick(1.0 / 60.0)
func _walk_threshold(inside: bool) -> int:
	var section = scene.temple_section
	var trigger: Rect2 = section.layout.ENTRY_TRIGGER if inside else section.layout.EXIT_TRIGGER
	var target := trigger.get_center()
	for frame in 300:
		_press(scene.player.position.direction_to(target))
		await _step()
		if section.in_garden == inside:
			_release()
			return frame + 1
	_release()
	check(false, "normal-speed threshold approach timed out")
	return 300

func _run() -> void:
	for name in ["hybrid_region", "jungle_pass", "temple_circuit_run", "jungle_south_circuit"]:
		scene = load("res://game/" + name + ".tscn").instantiate()
		scene.profile_save_prefix = "user://hidden_flow_" + name + str(Time.get_ticks_usec())
		scene.growth_save_prefix = scene.profile_save_prefix + "_growth"
		if name == "jungle_pass":
			var profile := RunProfile.new()
			profile.save_prefix = scene.profile_save_prefix
			check(profile.settle("fixture-jungle-access", "SUCCESS", 0), "isolated legacy jungle access")
		root.add_child(scene)
		await process_frame
		scene.set_physics_process(false)
		scene.wisp.set_physics_process(false)
		var section = scene.temple_section
		var layout = section.layout
		check(scene.BOSS_TIME == 240.0, "boss preparation contract preserved")
		check(section.discovery_marker().is_empty(), "undiscovered marker remains private")
		check(not section.exit_label.is_visible_in_tree() and not section.hidden_visual_root.visible, "hidden label/art absent on main field")
		check(section.main_entry_root.visible, "environment clue stays on main field")
		for point in [layout.ENTRY_TRIGGER.get_center(), layout.RETURN_POINT, layout.FIELD_ENTRY, layout.EXIT_TRIGGER.get_center()]:
			check(scene.navigation.is_open(point, 30.0), "threshold anchors clear radius30")
		check(scene.navigation.find_path(layout.FIELD_ENTRY, layout.EXIT_TRIGGER.get_center()).size() > 1, "arrival connects back to the same threshold")
		check(scene.navigation.find_path(layout.FIELD_ENTRY, layout.ALTAR).size() > 1, "arrival connects to reward through authored field")
		scene.run_time = 123.0
		scene.run_currency = 17
		scene.player.health = 63.0
		section.retry_used = true
		var build: Dictionary = scene.growth.card_ranks.duplicate(true)
		var run_id: String = scene.run_id
		scene.teleport(layout.RETURN_POINT)
		var cycles := []
		for cycle in 3:
			var entry_frames := await _walk_threshold(true)
			check(scene.player.position == layout.FIELD_ENTRY, "actual entry arrives at active layout anchor")
			check(scene.player.facing.is_equal_approx(layout.EXIT_TRIGGER.get_center().direction_to(layout.FIELD_ENTRY)), "arrival faces into this field")
			check(section.hidden_visual_root.visible and not section.main_entry_root.visible, "field art ownership switches immediately")
			check(section.exit_label.is_visible_in_tree(), "nearby exit is readable after arrival")
			check(not section.destination_label.visible, "main destination does not persist inside")
			check(scene.display_bounds() == layout.FIELD_BOUNDS and scene.player.arena_bounds == layout.FIELD_BOUNDS, "map/player bounds agree inside")
			check(section.discovery_marker().point == layout.ALTAR, "discovered inside marker follows actual altar")
			check(scene.camera.position.is_equal_approx(scene.terrain.world_point(layout.FIELD_ENTRY, 35) + scene.camera_offset) and scene.camera.size == scene.combat_camera_size, "camera snaps to arrival without changing combat size")
			for frame in 60: await _step()
			check(section.in_garden, "neutral arrival never bounces after cooldown")
			var exit_frames := await _walk_threshold(false)
			check(scene.player.position == layout.RETURN_POINT, "exit returns to the same active main threshold")
			check(scene.player.facing.is_equal_approx(layout.ENTRY_TRIGGER.get_center().direction_to(layout.RETURN_POINT)), "return faces away from threshold")
			check(not section.exit_label.is_visible_in_tree() and not section.hidden_visual_root.visible and section.main_entry_root.visible, "all hidden art/labels disappear on return")
			check(scene.display_bounds() == layout.MAIN_BOUNDS and scene.player.arena_bounds == layout.MAIN_BOUNDS, "map/player bounds agree on return")
			check(section.discovery_marker().point == layout.ENTRY_TRIGGER.get_center(), "discovered main marker follows actual entrance")
			check(scene.overview_camera_size == section.main_overview_size and not scene.overview, "main overview size restored; normal view retained")
			for frame in 60: await _step()
			check(not section.in_garden, "neutral return never reenters")
			check(scene.player.health == 63.0 and scene.run_id == run_id and scene.run_time == 123.0 and scene.run_currency == 17 and scene.growth.card_ranks == build and section.retry_used, "HP/build/currency/clock/retry survive repeated traversal")
			cycles.append({"entry_frames":entry_frames,"exit_frames":exit_frames})
		# Reverse before the0.8s window ends, without an idle frame between inputs.
		await _walk_threshold(true)
		var quick_frames := await _walk_threshold(false)
		check(not section.in_garden and quick_frames < 90, "new direction permits quick deliberate return without an extra inward step")
		for frame in 60: await _step()
		if name in ["temple_circuit_run", "jungle_south_circuit"]:
			var variants: Array = [layout.RETURN_POINT, layout.ENTRY_TRIGGER.get_center() + Vector2(180,0), layout.ENTRY_TRIGGER.get_center()+Vector2(0,180)] if name == "temple_circuit_run" else [layout.RETURN_POINT, layout.ENTRY_TRIGGER.get_center()+Vector2(-180,0), layout.ENTRY_TRIGGER.get_center()+Vector2(-180,100)]
			for origin in variants:
				section.portal_latch = preload("res://game/hidden_threshold_latch.gd").new()
				section.portal_cooldown = 0.0
				scene.teleport(origin)
				check(scene.navigation.is_open(origin,30), "held-input fixture starts on legal ground")
				_press(origin.direction_to(layout.ENTRY_TRIGGER.get_center()))
				var transitions := 0
				for frame in 180:
					var was_inside: bool = section.in_garden
					await _step()
					if was_inside != section.in_garden: transitions += 1
				check(transitions == 1 and section.in_garden, "held approach never triggers opposite portal")
				_release()
				for frame in 60: await _step()
				check(section.in_garden, "release alone never causes return")
				if name == "temple_circuit_run" and origin == layout.ENTRY_TRIGGER.get_center()+Vector2(180,0):
					check(layout.EXIT_TRIGGER.has_point(scene.player.position), "reproduced held west input actually reaches exit trigger")
					_press(Vector2.LEFT)
					await _step()
					check(not section.in_garden, "release then same direction re-input permits deliberate return")
					_release()
				else:
					# Immediate changed input may return before walking farther inside.
					await _walk_threshold(false)
					check(not section.in_garden, "new exit-direction input permits deliberate return")
		section.enter_garden()
		scene.teleport(layout.ALTAR)
		section.tick(0)
		check(not section.exit_label.visible, "exit label hidden at remote altar")
		section.leave_garden()
		paused = true
		section.enter_garden()
		check(not section.in_garden, "modal pause blocks traversal")
		paused = false
		scene.growth.choosing = true
		paused = true
		section.enter_garden()
		check(not section.in_garden, "card choice pause blocks traversal")
		scene.growth.choosing = false
		paused = false
		section.retry_pending = true
		section.enter_garden()
		check(not section.in_garden, "retry choice blocks traversal")
		section.retry_pending = false
		reports.append({"scene":name,"cycles":cycles,"scope":"normal-speed player input/physics, no dash, frozen run pressure","checks":checks,"failures":failures})
		_release()
		scene.queue_free()
		await process_frame
	print("HIDDEN_FLOW ", JSON.stringify({"checks":checks,"failures":failures,"scenes":reports}))
	quit(1 if failures else 0)
