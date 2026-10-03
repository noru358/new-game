extends SceneTree
## ONE bounded shared-preview journey across three fresh engines.
## Wins, earnings, XP, boss-entry/death and interruption state are explicit fixtures.
## Real entry, candidate scene transitions, growth/commerce, retry, retreat and saves run unchanged.
const Session = preload("res://game/field_preview_session.gd")
const ENTRY := "res://game/field_preview_entry.tscn"
const CAMP := "res://game/travel_camp.tscn"
const MARKER := ".preview-lifecycle-owner.json"
const GROUPS := ["training_enemies", "support_enemies", "enemy_bolts", "enemy_zones", "wisp_projectiles", "wisp_flashes", "wisp_chain_arcs"]
var phase := ""
var output := ""
var checks := 0
var failures := 0
var expected: Dictionary = {}
var levels := 0
var unlock_generation := 0
var departures: Array = []
var settlements: Array = []
var ledger: Array = []
var old_refs: Array[WeakRef] = []

func _initialize() -> void: call_deferred("_run")

func normalized(value):
	return JSON.parse_string(JSON.stringify(value))

func write_json(name: String, data) -> void:
	var file := FileAccess.open(output.path_join(name), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t", true))
		file.close()

func check(ok: bool, note: String) -> void:
	checks += 1
	if ok: return
	failures += 1
	printerr("FAIL: ", note)
	if failures == 1:
		write_json(phase + "-first-divergence.json", {"check": checks, "note": note, "expected": expected, "ledger": ledger, "slot_hashes": slot_hashes()})
	quit(1)

func guard() -> bool:
	output = OS.get_environment("PREVIEW_LIFECYCLE_OUTPUT")
	phase = OS.get_environment("PREVIEW_LIFECYCLE_PHASE")
	var target := OS.get_environment("PREVIEW_LIFECYCLE_USERDATA")
	var token := OS.get_environment("PREVIEW_LIFECYCLE_TOKEN")
	# Guard before loading any game scene or even inspecting user:// records.
	if output.is_empty() or token.is_empty() or not phase in ["A", "B", "C"] or OS.get_user_data_dir() != target:
		printerr("FAIL: exact isolated userdata/phase environment guard")
		return false
	if not target.begins_with(output + "/") or not target.ends_with("/xdg-data/LoopConquest-FieldPreview-v45"):
		printerr("FAIL: userdata is not inside the owned isolated XDG home")
		return false
	for path in [output.path_join(MARKER), target.path_join(MARKER), OS.get_environment("HOME").path_join(MARKER)]:
		var marker = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not marker is Dictionary or marker.get("token") != token or marker.get("userdata") != target or marker.get("project") != ProjectSettings.globalize_path("res://").trim_suffix("/"):
			printerr("FAIL: isolation owner marker mismatch")
			return false
	return true

func snapshot(profile) -> Dictionary:
	var result: Dictionary = profile._snapshot()
	result.generation = profile.generation # _snapshot is the NEXT candidate generation.
	return normalized(result)

func slot_hashes() -> Dictionary:
	var result := {}
	for prefix in [Session.PROFILE, Session.UNLOCKS]:
		for suffix in ["_a.json", "_b.json"]:
			var path: String = prefix + suffix
			result[path.get_file()] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
	return result

func profile_state(profile, note: String) -> void:
	check(profile.save_prefix == Session.PROFILE and not profile.load_error and not profile.unsupported_save_format and not profile.recovered_backup, note + ": exact default profile, valid load")
	var actual := snapshot(profile)
	if actual != normalized(expected): write_json(phase + "-actual-profile.json", actual)
	check(actual == normalized(expected), note + ": ALL durable profile fields and generation match ledger")

func unlock_state(unlocks, note: String) -> void:
	check(unlocks.save_prefix == Session.UNLOCKS, note + ": exact default unlock prefix")
	check(unlocks.lifetime_levelups == levels and unlocks.generation == unlock_generation, note + ": exact lifetime levelups and generation; no six-level seed")
	for id in UnlockProgress.MILESTONES:
		check(unlocks.is_unlocked(id) == (levels >= int(UnlockProgress.MILESTONES[id])), note + ": milestone " + id)

func receipt_reset(profile, note: String) -> void:
	check(profile.last_award == 0 and profile.last_lost == 0 and not profile.last_first_clear and profile.last_mod_award.is_empty(), note + ": last-result UI fields reset on load, not durable")

func commit_model(label: String, changes: Dictionary = {}) -> void:
	expected.generation = int(expected.generation) + 1
	for key in changes: expected[key] = changes[key]
	ledger.append({"action": label, "generation": expected.generation, "currency": expected.currency, "last_run_id": expected.last_run_id, "last_launch_id": expected.last_launch_id, "supply_count": expected.supply_count})

func remember_scene(scene) -> void:
	old_refs.append(weakref(scene))
	if scene.get("simulation") != null:
		old_refs.append(weakref(scene.simulation))
		old_refs.append(weakref(scene.player))
		for group in GROUPS:
			for actor in get_nodes_in_group(group): old_refs.append(weakref(actor))

func cleanup_state(scene = null) -> void:
	for reference in old_refs: check(reference.get_ref() == null, "previous scene/player/simulation/group actor freed")
	old_refs.clear()
	for group in GROUPS:
		for actor in get_nodes_in_group(group):
			check(scene != null and scene.simulation.is_ancestor_of(actor), "group " + group + " scoped to current simulation")

func wait_scene(path: String) -> Node:
	for i in 90:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == path:
			var scene = current_scene
			if scene.get("simulation") != null:
				scene.set_process(false)
				scene.set_physics_process(false)
				scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
			for j in 3: await process_frame
			cleanup_state(scene if scene.get("simulation") != null else null)
			return scene
	check(false, "wired scene transition reached " + path)
	return null

func boot():
	check(ProjectSettings.get_setting("application/run/main_scene") == ENTRY, "disposable package uses real preview entry")
	check(not Session.active(self), "fresh process starts without session metadata")
	check(Session.PROFILE == "user://first_region_shared_v45_profile" and Session.UNLOCKS == "user://first_region_shared_v45_unlocks", "actual default v45 shared namespace")
	var entry = load(ENTRY).instantiate()
	root.add_child(entry)
	current_scene = entry
	old_refs.append(weakref(entry))
	var camp = await wait_scene(CAMP)
	check(Session.active(self), "real entry activates default shared session")
	check(root.get_meta(Session.KEY) == {"profile": Session.PROFILE, "unlocks": Session.UNLOCKS}, "entry does not substitute custom test prefixes")
	check(Session.region_scene(self, false) == "res://game/temple_circuit_run.tscn" and Session.region_scene(self, true) == "res://game/jungle_south_circuit.tscn" and Session.scene_for_region(self, RunProfile.WETLAND_REGION) == "res://game/deep_wetland_run.tscn", "three candidate routes selected")
	return camp

func camp_state(camp) -> void:
	var hub = camp.preparation
	profile_state(hub.profile, "camp")
	unlock_state(hub.unlocks, "camp")
	receipt_reset(hub.profile, "camp")
	check(not paused, "camp does not inherit paused tree")
	check(hub.jungle_region_button.disabled == not hub.profile.temple_owned and hub.wetland_region_button.disabled == not hub.profile.jungle_owned, "camp gates follow real durable clears")
	for button in hub.find_children("*", "Button", true, false):
		check(not "시험용 해금" in button.text, "development bypass absent from shared camp")
	cleanup_state()

func fresh_run(run) -> void:
	profile_state(run.profile, "departure")
	unlock_state(run.growth.unlocks, "departure")
	receipt_reset(run.profile, "departure")
	check(run.run_currency == 0 and run.kills == 0 and run.run_time < 0.25, "uncommitted earnings/kills/time not restored")
	check(run.player.health == run.player.max_health and run.player.max_health == (110.0 if int(expected.growth_ranks.VITALITY) == 1 else 100.0), "fresh full HP incorporates only permanent growth")
	check(run.growth.level == 1 and run.growth.xp == 0 and run.growth.pending_choices == 0 and run.growth.card_ranks == {"U_STEP": 2} and run.growth.selected_card_ranks.is_empty(), "cards reset to built-in two-charge U_STEP baseline; XP/pending choices reset")
	check(not run.growth.choosing and not run.growth.overlay.visible and not run.result_overlay.visible and not run.retreat_overlay.visible and not run.awakening_overlay.visible and not run.pause_menu.visible, "all transient overlays reset")
	check(not run.temple_section.retry_used and not run.temple_section.retry_pending and not run.temple_section.retry_overlay.visible, "retry flags and overlay reset")
	check(not run.player.has_meta(&"companion_focus_target") and run.get_node_or_null("CompanionFocus") == null, "temporary focus target and synthetic controller not restored")
	check(not paused and not run.paused and not run.run_ended and not run.death_pending and not run.settlement_pending, "fresh run control state")
	check(run.player.echo_finisher_enabled == (expected.equipped_weapon == "W_ECHO") and run.player.flow_weave_enabled == (expected.equipped_weapon == "W_FLOW"), "purchased and separately equipped weapon applied")
	check(run.supply_ready == expected.last_launch_supply_used, "only current departure's consumed supply is active")
	cleanup_state(run)

func depart(camp, region: String):
	camp_state(camp)
	var hub = camp.preparation
	hub._select_region(region)
	check(hub.selected_region_id == region and not hub.start_button.disabled, "legal region selection " + region)
	var used: bool = expected.supply_selected and int(expected.supply_count) > 0
	remember_scene(camp)
	hub.start_button.pressed.emit()
	var run = await wait_scene(Session.scene_for_region(self, region))
	check(run.region_id == region and not departures.has(run.run_id) and not run.run_id.is_empty(), "unique real departure ID and correct candidate")
	departures.append(run.run_id)
	var count: int = int(expected.supply_count) - (1 if used else 0)
	commit_model("depart " + region, {"last_launch_id": run.run_id, "last_launch_supply_used": used, "supply_count": count, "supply_selected": count > 0 if used else expected.supply_selected})
	fresh_run(run)
	var before := slot_hashes()
	check(run.profile.begin_run(run.run_id), "same departure ID accepted idempotently")
	check(slot_hashes() == before, "duplicate begin_run does not consume again or write")
	return run

func return_camp(run):
	check(run.result_overlay.visible and not run.settlement_pending and not run.replay_button.disabled, "committed result enables camp return")
	remember_scene(run)
	run.replay_button.pressed.emit()
	var camp = await wait_scene(CAMP)
	camp_state(camp)
	return camp

func gain_levels(run, count: int) -> void:
	for i in count:
		run.growth.gain_xp(run.growth.next_xp()) # Explicit XP fixture; uses real level-up persistence.
		levels += 1
		unlock_generation += 1
		check(run.growth.choosing and run.growth.overlay.visible, "earned fixture level opens real card modal")
		check(run.growth.choose_index(0), "legal offered card selection")
		unlock_state(run.growth.unlocks, "earned fixture level")

func settle_model(run, result: String, earned: int) -> void:
	var first: bool = result == "SUCCESS" and not expected.owned_outpost_ids.has(run.region_id)
	var loss := 0
	if result != "SUCCESS": loss = mini(maxi(0, earned - 1), ceili(float(earned) * (0.5 if result == "DEFEAT" else 0.2)))
	var award: int = earned - loss + (20 if result == "SUCCESS" else 0) + (30 if first else 0)
	var mod := ""
	if first:
		expected.owned_outpost_ids.append(run.region_id)
		if run.region_id == RunProfile.TEMPLE_REGION: expected.acquired_relic_ids.append("RELIC_TEMPLE")
	elif result == "SUCCESS":
		var pool: Array = RunProfile.REGION_MODS[run.region_id].duplicate()
		for item in expected.owned_mods: pool.erase(item)
		mod = pool[posmod(run.run_id.hash(), pool.size())]
		expected.owned_mods.append(mod)
	check(not settlements.has(run.run_id), "settlement ID has not already been credited")
	settlements.append(run.run_id)
	commit_model("settle " + result, {"currency": int(expected.currency) + award, "last_run_id": run.run_id})
	profile_state(run.profile, "settlement")
	check(not run.settlement_pending and run.profile.last_award == award and run.profile.last_lost == loss and run.profile.last_first_clear == first and run.profile.last_mod_award == mod, "exact outcome/loss/success/first-clear/option receipt")
	if result != "RETREAT":
		check(not run.result_overlay.visible and run.ending_remaining > 0, "success/defeat waits through ending presentation")
		run._process(0.81)
	check(run.result_overlay.visible, "settlement result shown")
	var before := slot_hashes()
	for i in 2:
		run._retry_settlement()
		run._finish_run(result)
		run._show_result()
	check(slot_hashes() == before, "repeat retry/finish/show cannot write or double-credit")
	ledger[-1].merge({"earned_fixture": earned, "lost": loss, "award": award, "first_clear": first, "mod": mod})

func finish(run, result: String, earned: int) -> void:
	run.run_currency = earned # Explicit injected earnings and outcome, not a natural win.
	run._finish_run(result)
	settle_model(run, result, earned)

func buy_gear(hub, id: String, cost: int) -> void:
	var previous: String = expected.equipped_weapon
	hub._select_gear(id)
	hub.gear_action_button.pressed.emit()
	expected.owned_gear[id] = true
	commit_model("buy " + id, {"currency": int(expected.currency) - cost})
	profile_state(hub.profile, "gear purchase")
	check(hub.profile.equipped_weapon == previous, "purchase does not auto-equip " + id)
	hub.gear_action_button.pressed.emit()
	commit_model("equip " + id, {"equipped_weapon": id})
	profile_state(hub.profile, "separate explicit equip")

func buy_supply(hub) -> void:
	hub.supply_buy_button.pressed.emit()
	commit_model("buy/select supply", {"currency": int(expected.currency) - 12, "supply_count": int(expected.supply_count) + 1, "supply_selected": true})
	profile_state(hub.profile, "legal camp supply preparation")

func reread(note: String) -> void:
	var before := slot_hashes()
	var profile := RunProfile.new()
	profile.save_prefix = Session.PROFILE
	profile.load_state()
	profile_state(profile, note)
	receipt_reset(profile, note)
	var unlocks := UnlockProgress.new()
	unlocks.save_prefix = Session.UNLOCKS
	unlocks.load_progress()
	unlock_state(unlocks, note)
	check(slot_hashes() == before, note + ": read-only reload preserves exact slot bytes")

func checkpoint(name: String, transient: Dictionary = {}) -> void:
	reread("checkpoint " + name)
	write_json(name + "-checkpoint.json", {"profile": expected, "levels": levels, "unlock_generation": unlock_generation, "slot_hashes": slot_hashes(), "departures": departures, "settlements": settlements, "ledger": ledger, "transient": transient})

func restore_checkpoint(name: String) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(output.path_join(name + "-checkpoint.json")))
	expected = data.profile
	levels = int(data.levels)
	unlock_generation = int(data.unlock_generation)
	departures = data.departures
	settlements = data.settlements
	ledger = data.ledger
	check(slot_hashes() == data.slot_hashes, "fresh " + phase + " process receives exact bytes from " + name)
	return data

func phase_a(camp) -> void:
	camp_state(camp)
	check(expected.currency == 0 and int(expected.generation) == 0 and levels == 0 and expected.owned_outpost_ids.is_empty(), "genuinely new shared campaign, no dev success seed")
	var run = await depart(camp, RunProfile.TEMPLE_REGION)
	gain_levels(run, 2)
	finish(run, "SUCCESS", 100)
	camp = await return_camp(run)
	buy_gear(camp.preparation, "W_FLOW", 35)
	camp.preparation._buy_growth("VITALITY")
	expected.growth_ranks.VITALITY = 1
	commit_model("buy VITALITY", {"currency": int(expected.currency) - 20})
	profile_state(camp.preparation.profile, "legal permanent growth purchase")
	run = await depart(camp, RunProfile.JUNGLE_REGION)
	check(levels == 2, "jungle entry did not synthesize six levels")
	gain_levels(run, 2)
	finish(run, "SUCCESS", 80)
	camp = await return_camp(run)
	run = await depart(camp, RunProfile.WETLAND_REGION)
	gain_levels(run, 2)
	finish(run, "SUCCESS", 80)
	check(expected.currency == 355 and int(expected.generation) == 9 and levels == 6 and settlements.size() == 3, "A precise three-first-clear ledger")
	check(current_scene == run and run.result_overlay.visible, "A exits after wetland commit BEFORE camp return")
	checkpoint("A")

func retry_then_defeat(run) -> void:
	# Synthetic boss-entry/death setup, followed by unchanged retry signal/engine death path.
	var section = run.temple_section
	run.run_currency = 111
	run.run_time = 246.5
	run.teleport(section.boss_point)
	section.boss_entered = true
	run.player.health = 0.0
	run.death_pending = true
	run._physics_process(0.0)
	check(section.retry_pending and section.retry_overlay.visible and not run.run_ended, "real death path offers one retry without settlement")
	var before := slot_hashes()
	section.retry_overlay.get_node("Retry").pressed.emit()
	check(section.retry_used and not section.retry_pending and not section.retry_overlay.visible and run.player.health == run.player.max_health, "wired boss retry restores HP and closes modal")
	check(is_instance_valid(run.boss) and run.run_currency == 111 and not run.supply_ready, "retry spawns boss, retains earnings and does not refund spent supply")
	check(slot_hashes() == before, "boss retry has no durable profile/unlock write")
	run.player.health = 0.0
	run.death_pending = true
	run._physics_process(0.0)
	check(run.run_ended and run.end_result == "DEFEAT", "second death settles defeat, no second retry")
	settle_model(run, "DEFEAT", 111)

func confirm_retreat(run) -> void:
	for button in run.retreat_overlay.get_children():
		if button is Button and button.text == "귀환하기":
			button.pressed.emit()
			return
	check(false, "wired retreat confirmation button exists")

func retreat_with_save_probe(run) -> void:
	run.run_currency = 73
	var before := slot_hashes()
	run._request_retreat()
	check(run.retreat_overlay.visible and paused, "real retreat confirmation opens")
	run.retreat_overlay.get_node("Cancel").pressed.emit()
	check(not run.retreat_overlay.visible and not paused and not run.run_ended and slot_hashes() == before, "wired cancel resumes without durable changes")
	run._request_retreat()
	# Reversible missing-directory write failure, as in verify_result_clarity.
	var missing := "user://owned_missing_failure_probe/profile"
	check(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(missing.get_base_dir())), "failure probe directory is absent inside owned userdata")
	run.profile.save_prefix = missing
	confirm_retreat(run)
	check(run.settlement_pending and run.replay_button.disabled and run.retry_button.visible and run.result_overlay.visible, "failed confirmed retreat blocks camp and exposes retry")
	check(slot_hashes() == before and snapshot(run.profile) == normalized(expected), "failed save leaves money/generation/slot bytes untouched")
	run.replay_button.pressed.emit()
	var event := InputEventKey.new()
	event.keycode = KEY_R
	event.pressed = true
	run._input(event)
	check(current_scene == run, "mouse signal and R cannot leave pending result")
	run.retry_button.pressed.emit()
	check(run.settlement_pending and slot_hashes() == before, "still-failing retry leaves same uncredited bytes")
	run.profile.save_prefix = Session.PROFILE
	run.retry_button.pressed.emit()
	settle_model(run, "RETREAT", 73)
	check(not run.retry_button.visible and not run.replay_button.disabled, "successful save retry enables return")

func phase_b(camp) -> void:
	camp_state(camp)
	buy_gear(camp.preparation, "W_ECHO", 45)
	buy_supply(camp.preparation)
	var run = await depart(camp, RunProfile.TEMPLE_REGION)
	check(run.supply_ready and run.profile.supply_count == 0, "first supply consumed exactly once on departure")
	run.player.health = 20.0
	run.player.health_changed.emit()
	check(run.player.health == 50.0 and not run.supply_ready, "carried supply heals once through existing signal")
	retry_then_defeat(run)
	camp = await return_camp(run)
	run = await depart(camp, RunProfile.JUNGLE_REGION)
	retreat_with_save_probe(run)
	camp = await return_camp(run)
	run = await depart(camp, RunProfile.WETLAND_REGION)
	finish(run, "SUCCESS", 80)
	check(expected.currency == 511 and int(expected.generation) == 18 and expected.owned_mods.size() == 1 and settlements.size() == 6, "six settlements; wetland reclear grants 100, one new valid option, no duplicate first bonus")
	camp = await return_camp(run)
	buy_supply(camp.preparation)
	run = await depart(camp, RunProfile.TEMPLE_REGION)
	check(run.supply_ready and run.profile.supply_count == 0 and run.profile.last_launch_supply_used, "abandoned departure consumes second supply durably")
	# Interruption fixture: temporary card, target/controller, retry flag, HP, time and earnings.
	# Controller is deliberately injected without buying a COMPANION branch; no profile mutation.
	run.growth.apply_card("U_EDGE")
	var enemy = run._spawn_enemy_at(run.player.position + Vector2(80, 0), TrainingEnemy.Role.FRAGMENT, 1000.0)
	enemy.set_physics_process(false)
	var focus = load("res://game/companion_focus.gd").new()
	focus.setup(run)
	run.add_child(focus)
	focus.set_physics_process(false)
	run.player.attack_sequence += 1
	focus._on_hit(enemy)
	focus._physics_process(0.0)
	check(run.player.has_meta(&"companion_focus_target") and focus.target_ref.get_ref() == enemy, "explicit temporary focus fixture uses actual focus controller")
	run.growth.gain_xp(run.growth.next_xp())
	levels += 1
	unlock_generation += 1
	run.temple_section.retry_used = true
	run.player.health = 37.0
	run.run_time = 123.25
	run.run_currency = 777
	run.kills = 9
	check(run.growth.choosing and run.growth.overlay.visible and paused and run.growth.card_ranks.U_EDGE == 1, "B exits during actual card modal with temporary build and pending choice")
	check(expected.currency == 499 and int(expected.generation) == 20 and levels == 7 and expected.last_run_id != run.run_id, "interrupted run writes only departure consumption and earned permanent unlock")
	unlock_state(run.growth.unlocks, "interruption")
	checkpoint("B", {"abandoned_run_id": run.run_id, "run_currency": run.run_currency, "hp": run.player.health, "time": run.run_time, "kills": run.kills, "cards": run.growth.card_ranks, "pending_choices": run.growth.pending_choices, "retry_used": true, "focus": true, "card_overlay": true})

func phase_c(camp, previous: Dictionary) -> void:
	camp_state(camp)
	check(expected.last_launch_id == previous.transient.abandoned_run_id and expected.last_launch_supply_used and int(expected.supply_count) == 0 and expected.currency == 499, "C retains abandoned departure ID/supply charge, purchases and committed currency only")
	var run = await depart(camp, RunProfile.TEMPLE_REGION)
	check(not run.supply_ready and not run.profile.last_launch_supply_used and levels == 7, "abandoned supply not refunded/re-equipped; permanent level survives")
	run.run_currency = 25
	run._request_retreat()
	check(run.retreat_overlay.visible, "final recovery retreat requires confirmation")
	confirm_retreat(run)
	settle_model(run, "RETREAT", 25)
	camp = await return_camp(run)
	check(int(expected.generation) == 22 and expected.currency == 519 and settlements.size() == 7 and departures.size() == 8, "final exact ledger: seven settlements, eight departures, one abandoned")
	reread("final reread")
	checkpoint("C")

func _run() -> void:
	if not guard():
		quit(2)
		return
	var previous := {}
	if phase == "A":
		for value in slot_hashes().values(): check(value == "absent", "new isolated family starts with no profile or unlock slots")
		var blank := RunProfile.new()
		expected = snapshot(blank)
	else:
		previous = restore_checkpoint("A" if phase == "B" else "B")
	var before_boot := slot_hashes()
	var camp = await boot()
	check(slot_hashes() == before_boot, "entry and camp startup do not alter durable slot bytes")
	if phase == "A": await phase_a(camp)
	elif phase == "B": await phase_b(camp)
	else: await phase_c(camp, previous)
	var report := {"phase": phase, "pid": OS.get_process_id(), "checks": checks, "failures": failures, "profile": expected, "unlocks": {"version": 1, "generation": unlock_generation, "lifetime_levelups": levels}, "departures": departures.size(), "settlements": settlements.size(), "slot_hashes": slot_hashes(), "userdata": OS.get_user_data_dir(), "synthetic_fixtures": true}
	write_json(phase + "-report.json", report)
	print("Shared preview lifecycle ", phase, ": ", checks, " checks, ", failures, " failures; pid=", OS.get_process_id())
	quit(1 if failures else 0)
