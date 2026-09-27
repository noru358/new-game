extends SceneTree

const PREFIX := "user://verify_meta_preparation_profile"
const UNLOCK_PREFIX := "user://verify_meta_preparation_unlocks"
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	var legacy := FileAccess.open(PREFIX + "_a.json", FileAccess.WRITE)
	legacy.store_string(JSON.stringify({
		"version": 1, "generation": 1, "currency": 100,
		"owned_outpost_ids": [], "acquired_relic_ids": [], "last_run_id": "old-run"
	}))
	legacy.close()
	var profile := RunProfile.new()
	profile.save_prefix = PREFIX
	profile.load_state()
	_check(profile.currency == 100 and profile.owned_gear.is_empty() and profile.equipped_weapon == "W_START", "v1 currency and progress load with default preparation state")
	_check(not profile.buy_gear("W_FLOW", "KEEN"), "clear-gated weapon cannot be purchased early")
	_check(not profile.buy_gear("A_EMBER", "BAD"), "invalid random option is rejected")
	_check(profile.buy_gear("A_EMBER", "BRIGHT") and profile.currency == 76, "accessory purchase spends currency once")
	_check(not profile.buy_gear("A_EMBER", "BRIGHT") and profile.currency == 76, "owned item cannot be purchased twice")
	_check(profile.equip("A_EMBER"), "owned accessory equips")
	_check(profile.buy_growth("POWER") and profile.currency == 56 and int(profile.growth_ranks.POWER) == 1, "permanent growth purchases and saves")
	_check(profile.reset_growth() and profile.currency == 76 and int(profile.growth_ranks.POWER) == 0, "respec returns spent currency")
	_check(profile.settle("meta-clear", "SUCCESS", 0) and profile.currency == 126 and profile.temple_owned, "first clear opens new combat choice")
	_check(profile.buy_gear("W_FLOW", "SWIFT") and profile.equip("W_FLOW") and profile.currency == 91, "new weapon has one stored random option and can equip")
	_check(profile.equip("W_START") and profile.equipped_weapon == "W_START" and profile.equip("W_FLOW"), "owned weapon can be compared with the basic style")
	_check(profile.equip("") and profile.equipped_accessory == "" and profile.equip("A_EMBER"), "accessory can be removed and re-equipped")
	for id in ["POWER", "VITALITY", "MOBILITY"]: _check(profile.buy_growth(id), "growth purchase: " + id)
	_check(profile.currency == 31, "three growth branches charge their stated prices")
	_check(profile.buy_supply() and profile.supply_count == 1 and profile.currency == 19, "one-use supply purchases")
	_check(profile.select_supply(false) and profile.select_supply(true), "supply can be reserved or conserved")
	var migrated := RunProfile.new()
	migrated.save_prefix = PREFIX
	migrated.load_state()
	_check(not migrated.load_error and migrated.currency == 19 and migrated.equipped_weapon == "W_FLOW" and migrated.equipped_accessory == "A_EMBER" and migrated.owned_gear.W_FLOW == "SWIFT" and migrated.supply_count == 1, "v2 purchases and loadout reload together")
	var hub: Control = load("res://game/hub.tscn").instantiate()
	hub.profile_save_prefix = PREFIX
	root.add_child(hub)
	await process_frame
	_check(hub.currency_label.text.contains("19") and hub.start_button.disabled == false and hub.weapon_button.text.contains("기본으로 변경"), "preparation UI displays saved currency, progress and loadout")
	hub._gear_action("W_FLOW")
	_check(hub.profile.equipped_weapon == "W_START", "hub button switches back to basic weapon")
	hub._gear_action("W_FLOW")
	hub._gear_action("A_EMBER")
	_check(hub.profile.equipped_accessory == "", "hub button removes accessory")
	hub._gear_action("A_EMBER")
	hub.queue_free()
	await process_frame
	var scene: Node3D = load("res://game/hybrid_region.tscn").instantiate()
	scene.profile_save_prefix = PREFIX
	scene.growth_save_prefix = UNLOCK_PREFIX
	root.add_child(scene)
	await physics_frame
	await physics_frame
	_check(scene.player.max_health == 110.0 and is_equal_approx(scene.player.permanent_basic_damage_bonus, 0.05) and is_equal_approx(scene.player.dash_recharge_duration(), 1.2 * (1.0 - 0.15 - 0.04)), "permanent growth changes the real run")
	_check(scene.player.flow_weave_enabled and scene.player.moving_slash_distance_multiplier == 1.20 and is_equal_approx(scene.player.permanent_slash_cooldown_reduction, 0.14) and is_equal_approx(scene.wisp.permanent_damage_bonus, 0.20), "equipped gear changes Q and wisp combat")
	var target := TrainingEnemy.new()
	target.max_health = 1000.0
	target.position = scene.player.position + Vector2(70, 0)
	scene.simulation.add_child(target)
	target.set_physics_process(false)
	scene.player.attack_path_filter = Callable()
	scene.player.moving_slash_direction = Vector2.RIGHT
	scene.player._hit_moving_slash(scene.player.position, target.position)
	_check(scene.player.flow_weave_ready, "Q hit prepares the weapon's next-hit weave")
	var after_slash: float = target.health
	scene.player.facing = Vector2.RIGHT
	scene.player._start_attack()
	scene.player._hit_enemies(scene.player._attack_spec(1))
	_check(is_equal_approx(target.health, after_slash - 13.125) and scene.player.flow_weave_attack and not scene.player.flow_weave_ready, "Q into basic attack gives one 25 percent empowered hit")
	scene.player._start_attack()
	_check(not scene.player.flow_weave_attack, "weave does not persist to another attack")
	target.queue_free()
	_check(scene.growth.describe_card("U_EDGE", 1).contains("105% → 120%") and scene.growth.describe_card("S_WISP_DAMAGE", 1).contains("12.0 → 14.0") and scene.growth.describe_card("U_SLASH_CADENCE", 1).contains("0.95초 → 0.78초"), "numeric cards include equipped and permanent bonuses")
	scene.growth.card_ranks["S_WISP_COUNT"] = 1
	scene.growth._sync_wisps()
	_check(scene.growth.wisps.size() == 2 and is_equal_approx(scene.growth.wisps[1].permanent_damage_bonus, 0.20), "new wisps inherit accessory effect")
	_check(scene.profile.supply_count == 0 and scene.supply_ready, "prepared supply is deducted once at departure")
	var launch_generation: int = scene.profile.generation
	_check(scene.profile.begin_run(scene.run_id) and scene.profile.generation == launch_generation, "same departure cannot consume or save twice")
	scene.player.receive_hit(80.0)
	_check(scene.player.health == 60.0 and not scene.supply_ready, "one-use charm heals after crossing its threshold")
	scene.player.hurt_immunity = 0.0
	scene.player.receive_hit(10.0)
	_check(scene.player.health == 50.0, "one-use charm does not fire again")
	scene.queue_free()
	await physics_frame
	var after := RunProfile.new()
	after.save_prefix = PREFIX
	after.load_state()
	_check(after.supply_count == 0 and not after.supply_selected and after.currency == 19, "departure consumption remains after reload")
	_cleanup()
	if failures == 0: print("Meta preparation verification passed: migration, spending, loadout, respec, supply and run effects")
	quit(1 if failures else 0)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _cleanup() -> void:
	for prefix in [PREFIX, UNLOCK_PREFIX]:
		for suffix in ["_a.json", "_b.json"]:
			var path := ProjectSettings.globalize_path(prefix + suffix)
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
