extends "res://tests/capture_hidden_flow.gd"
## Final combined candidate only: same 24 bounded views, replacing the away
## view with the legal reward approach. Synthetic guardian damage is explicit.
var collecting_reward := false

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
		return
	var section = scene.temple_section
	var approach: Vector2 = section.layout.ALTAR + Vector2(60, 60)
	check(scene.navigation.is_open(approach, scene.ACTOR_CLEARANCE), region + " reward approach on legal ground")
	_capture_stage("reward-approach", "normal-walk-start")
	collecting_reward = true
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
