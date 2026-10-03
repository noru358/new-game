extends "res://tests/capture_hidden_flow.gd"
## Final combined candidate only: same 24 bounded views, replacing the away
## view with the legal reward approach. Synthetic guardian damage is explicit.
var collecting_reward := false

func _expected_capture_count() -> int:
	var base := super._expected_capture_count()
	if exit_only or only_region == "temple": return base
	return base + 5 * (1 if only_width != 0 else 2)

func _step() -> void:
	await super._step()
	if collecting_reward and region == "temple":
		for actor in scene.actors.keys():
			if is_instance_valid(actor) and actor is TrainingEnemy and not actor is GateBoss and scene.temple_section.field_area.has_point(actor.position) and actor.health > 0:
				actor.take_hit(10000.0, Vector2.RIGHT, false)
		while scene.growth.choosing: scene.growth.choose_index(0)

func _capture(state: String, size: Vector2i) -> void:
	if state != "hidden-away":
		await super._capture(state, size)
		if state == "hidden-overview" and region == "jungle":
			scene.overview = false
			scene.camera.size = scene.combat_camera_size
			var rear := [Vector2(8950,440),Vector2(8530,740),Vector2(7630,740),Vector2(6790,1100),Vector2(6500,1920)]
			for index in rear.size():
				await _walk(rear[index])
				await super._capture("rear-return-%d" % (index+12), size)
		return
	var section = scene.temple_section
	var approach: Vector2 = section.layout.ALTAR + Vector2(60, 60)
	check(scene.navigation.is_open(approach, scene.ACTOR_CLEARANCE), region + " reward approach on legal ground")
	_capture_stage("reward-approach", "normal-walk-start")
	collecting_reward = true
	if region == "temple":
		# Every real guardian warning requires the player within760 and outside140.
		# Visit legal nearby ground and let the authored1s warning finish.
		for guard_point in section.layout.GUARDS:
			var guard_approach := Vector2.INF
			for offset in [Vector2(180,0),Vector2(-180,0),Vector2(0,180),Vector2(0,-180)]:
				if scene.navigation.is_open(guard_point + offset, scene.ACTOR_CLEARANCE):
					guard_approach = guard_point + offset
					break
			check(guard_approach != Vector2.INF, "legal approach to real guardian warning")
			if guard_approach == Vector2.INF: break
			await _walk(guard_approach)
			for frame in 90: await _step()
	await _walk(approach)
	collecting_reward = false
	_capture_stage("reward-approach", "normal-walk-end")
	_release()
	check(scene.player.position.distance_to(section.layout.ALTAR) < 105.0, region + " normal movement reaches reward radius")
	if region == "temple":
		check(section.guardians_defeated == 3 and section.guardian_reservations == 0, "real guardian spawns and defeated signals; synthetic damage")
	check(section.claim_garden_reward() and section.garden_claimed, region + " actual reward at legal approach")
	check(not section.claim_garden_reward(), region + " reward once per run")
	var saved := RunProfile.new()
	saved.save_prefix = scene.profile_save_prefix
	saved.load_state()
	var awakening := "EMBER_GARDEN" if region == "temple" else "ECHO_GROTTO"
	check(saved.awakenings.has(awakening) and saved.discovered_places.has(section._hidden_place_id()), region + " discovery and awakening persisted")
	scene._close_awakening_receipt()
	await super._capture("reward-approach", size)
	captures.back()["reward"] = {"claimed": section.garden_claimed, "distance": scene.player.position.distance_to(section.layout.ALTAR), "guardians": section.guardians_defeated, "scope": "normal movement and real reward/save; synthetic guardian damage, frozen pressure; no natural-play claim"}
