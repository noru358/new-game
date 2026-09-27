extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _run() -> void:
	var scene: Node2D = load("res://game/view_prototype.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	var player: SandboxPlayer = scene.get_node("Player")
	var growth: RunGrowth = scene.get_node("RunGrowth")
	growth.unlocks.lifetime_levelups = 6
	_check(not growth.roll_choices().has("S_WISP_REPLY"), "slash-dependent card is hidden before the move unlocks")
	player.moving_slash_enabled = true
	for seed_value in 24:
		growth.rng.seed = seed_value
		var choices := growth.roll_choices()
		var basic := false
		var wisp := false
		for card_id in choices:
			basic = basic or RunGrowth.CARDS[card_id].group == "BASIC"
			wisp = wisp or card_id.begins_with("S_WISP_")
		_check(choices.size() == 3 and basic and wisp, "early choices include manual and wisp branches")
	for card_id in RunGrowth.CARDS:
		if card_id.begins_with("S_WISP_") and card_id != "S_WISP_REPLY":
			growth.card_ranks[card_id] = RunGrowth.CARDS[card_id].max
	for seed_value in 24:
		growth.rng.seed = seed_value + 100
		_check(growth.roll_choices().has("S_WISP_REPLY"), "last available wisp remains in late choices")
	growth.card_ranks["S_WISP_REPLY"] = 2
	_check(growth.roll_choices().size() == 3, "exhausted wisp slot returns to the full pool")
	growth.card_ranks["S_WISP_FOLLOWUP"] = 1
	player.attack_sequence = 10
	growth.wisps[0].fire_cooldown = 0.5
	player.attack_landed.emit(player.global_position, Vector2.RIGHT, 1, false)
	_check(is_equal_approx(growth.wisps[0].fire_cooldown, 0.42), "manual hit advances wisp fire")
	player.attack_landed.emit(player.global_position, Vector2.RIGHT, 1, false)
	_check(is_equal_approx(growth.wisps[0].fire_cooldown, 0.42), "multi-target attack triggers once")
	player.attack_sequence += 1
	player.attack_landed.emit(player.global_position, Vector2.RIGHT, 2, false)
	_check(is_equal_approx(growth.wisps[0].fire_cooldown, 0.34), "next manual attack can advance wisp again")
	player.moving_slash_cooldown = 0.5
	growth.wisps[0].enemy_hit.emit(null)
	_check(is_equal_approx(player.moving_slash_cooldown, 0.38), "wisp hit advances slash cooldown at rank two")
	scene.queue_free()
	await physics_frame
	if failures == 0: print("Card diversity verification passed: early/late offerings, fallback, cross-branch effects")
	quit(1 if failures else 0)
