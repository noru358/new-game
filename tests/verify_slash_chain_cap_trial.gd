extends SceneTree
const Flow = preload("res://game/run_flow_trial.gd")
var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _target(arena: Node2D, point: Vector2) -> TrainingEnemy:
	var enemy := TrainingEnemy.new()
	enemy.position = point
	arena.add_child(enemy)
	enemy.max_health = 1000.0
	enemy.health = 1000.0
	enemy.set_physics_process(false)
	return enemy

func _run() -> void:
	print("CAP_PHASE start")
	var arena := Node2D.new()
	root.add_child(arena)
	var player := SandboxPlayer.new()
	arena.add_child(player)
	player.set_physics_process(false)
	player.moving_slash_enabled = true
	var wisp := WispCompanion.new()
	wisp.player = player
	arena.add_child(wisp)
	wisp.set_physics_process(false)
	var growth := RunGrowth.new()
	growth.unlocks.save_prefix = "user://verify_slash_chain_cap_trial_unused"
	growth.setup(arena, player, wisp)
	arena.add_child(growth)
	growth.unlocks.lifetime_levelups = 6
	check(not growth.slash_chain_cap_trial_enabled, "new cap defaults off")
	for id in ["U_SLASH_CADENCE", "S_WISP_CHAIN"]:
		for rank in 3: growth.apply_card(id)
		check(growth.card_ranks[id] == 2, "baseline rank3 refused: " + id)
	growth.slash_chain_cap_trial_enabled = true
	var capacity := 0
	for id in RunGrowth.CARDS:
		capacity += growth.card_max_rank(id)
		check(growth.card_max_rank(id) == int(RunGrowth.CARDS[id].max) + (1 if id in ["U_SLASH_CADENCE", "S_WISP_CHAIN"] else 0), "only approved caps change: " + id)
	check(capacity == 41, "exactly two extra ranks; damage flag independent")
	for id in ["U_SLASH_CADENCE", "S_WISP_CHAIN"]:
		growth.apply_card(id)
		growth.apply_card(id)
		check(growth.card_ranks[id] == 3, "rank3 applied once; rank4 refused: " + id)
	check(is_equal_approx(player.moving_slash_cooldown_reduction, 0.45), "slash rank3 reduces reuse by45%")
	check(wisp.chain_jumps == 3, "chain rank3 adds one extra target")
	check(growth.describe_card("U_SLASH_CADENCE", 3).contains("0.77초 → 0.61초") and growth.describe_card("S_WISP_CHAIN", 3).contains("2명 → 3명"), "rank3 previews match effective values")
	# Legal permanent SLASH5 (10.5%), W_FLOW (10%), SWIFT (4%) total24.5%.
	player.permanent_slash_cooldown_reduction = 0.245
	player._start_moving_slash(Vector2.RIGHT)
	check(is_equal_approx(player.moving_slash_cooldown, 0.3355) and player.moving_slash_cooldown > SandboxPlayer.MOVING_SLASH_DURATION, "strongest legal combination retains335.5ms reuse over220ms movement")
	growth.card_ranks.S_WISP_REPLY = 2
	for i in 30: growth._on_wisp_enemy_hit(null)
	check(player.moving_slash_cooldown == 0.0, "many reply hits floor the reuse timer at zero")
	print("CAP_PHASE chain")
	player.permanent_dash_cooldown_reduction = 0.14
	player.set_dash_upgrade(3)
	check(is_equal_approx(player.dash_recharge_duration(), 0.672), "rank5 permanent dash and run rank3 keep672ms recharge")
	var a := _target(arena, Vector2(100, 100))
	var b := _target(arena, Vector2(200, 100))
	var c := _target(arena, Vector2(300, 100))
	var d := _target(arena, Vector2(400, 100))
	var shot := WispProjectile.new()
	shot.damage = 10.0
	shot.chain_jumps = 3
	shot.target_visibility_filter = func(_enemy): return true
	arena.add_child(shot)
	shot.set_physics_process(false)
	var hits: Array[int] = []
	shot.enemy_hit.connect(func(enemy): hits.append(enemy.get_instance_id()))
	shot._chain_from(a)
	check(a.health == 1000.0 and hits.size() == 3 and hits.has(b.get_instance_id()) and hits.has(c.get_instance_id()) and hits.has(d.get_instance_id()), "first enemy excluded and exactly three chain impacts")
	check(hits[0] != hits[1] and hits[0] != hits[2] and hits[1] != hits[2], "chain cannot repeat a target or loop")
	check(is_equal_approx(b.health, 993.2) and is_equal_approx(c.health, 995.376) and is_equal_approx(d.health, 996.85568), "third impact retains geometric68% decay")
	b.queue_free(); c.queue_free(); d.queue_free()
	await process_frame
	hits.clear()
	shot._chain_from(a)
	check(hits.is_empty() and a.health == 1000.0, "single surviving target receives no chain repeat")
	a.queue_free()
	await process_frame
	print("CAP_PHASE boss")
	var boss := GateBoss.new()
	arena.add_child(boss)
	boss.set_physics_process(false)
	hits.clear()
	var health_before := boss.health
	shot._chain_from(boss)
	check(hits.is_empty() and boss.health == health_before, "isolated single boss gains no chain damage")
	var flow := Flow.new()
	check(flow.boss_deadline() == 300.0 and not flow.should_prepare_boss(210, true, false) and flow.should_prepare_boss(300, false, true), "default300 remains unchanged")
	flow.enabled = true
	check(not flow.should_prepare_boss(239.99, true, false) and flow.should_prepare_boss(240, false, true), "four minute deadline is time based with no choice/arrival gate")
	check(Flow.xp_for_choices(3) == 30 and Flow.xp_for_choices(6) == 78 and Flow.xp_for_choices(9) == 144, "XP observation milestones retain the current curve")
	print("CAP_PHASE cleanup")
	arena.queue_free()
	await process_frame
	print("SLASH_CHAIN_CAP_CHECKS ", checks, " failures ", failures)
	quit(1 if failures else 0)
