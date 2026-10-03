extends SceneTree
## Equal two-card fixture, same basic equipment/positions/duration. Frozen AI;
## actual wisp target selection/projectiles/hits. Not human or natural-run balance.
class MeasuredEnemy extends TrainingEnemy:
	var metrics: Dictionary
	func take_hit(damage: float, direction: Vector2, finisher: bool, impact: float = 1.0) -> void:
		metrics.hits += 1
		metrics.hp_removed += minf(maxf(health, 0.0), damage)
		metrics.overkill += maxf(0.0, damage - maxf(health, 0.0))
		if damage >= health: metrics.kills += 1
		super.take_hit(damage, direction, finisher, impact)
class MeasuredBoss extends GateBoss:
	var metrics: Dictionary
	func take_hit(damage: float, direction: Vector2, finisher: bool, impact: float = 1.0) -> void:
		metrics.hits += 1
		metrics.hp_removed += minf(maxf(health, 0.0), damage)
		metrics.overkill += maxf(0.0, damage - maxf(health, 0.0))
		super.take_hit(damage, direction, finisher, impact)
var report_path := ""
func _initialize(): call_deferred("_run")
func _mount_collision(enemy: TrainingEnemy, radius: float) -> void:
	enemy.collision_layer = 2
	enemy.collision_mask = 2
	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	collider.shape = shape
	enemy.add_child(collider)

func _run():
	var expected := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report-path="): report_path = arg.trim_prefix("--report-path=")
		if arg.begins_with("--expected-user-dir="): expected = arg.trim_prefix("--expected-user-dir=")
	if expected.is_empty() or OS.get_user_data_dir() != expected or not FileAccess.file_exists("user://flow-sample-owner.json"): quit(1); return
	Engine.time_scale = 1.0
	var rows := []
	for scenario in ["swarm", "single_boss"]:
		for card in ["S_WISP_COUNT", "S_WISP_DAMAGE", "S_WISP_CADENCE"]:
			var metrics := {"shots": 0, "hits": 0, "hp_removed": 0.0, "overkill": 0.0, "kills": 0}
			var arena := Node2D.new(); root.add_child(arena)
			var player := SandboxPlayer.new(); player.position = Vector2(100, 100); arena.add_child(player); player.set_physics_process(false)
			var wisp := WispCompanion.new(); wisp.player = player; arena.add_child(wisp)
			var growth := RunGrowth.new(); growth.setup(arena, player, wisp); growth.unlocks.save_prefix = "user://balance_unused_unlocks"; arena.add_child(growth); growth.unlocks.lifetime_levelups = 6
			for i in 2: growth.apply_card(card)
			for companion in growth.wisps:
				companion.target_visibility_filter = func(_candidate): return true
				companion.shot_fired.connect(func(_target): metrics.shots += 1)
			if scenario == "single_boss":
				var boss := MeasuredBoss.new(); boss.metrics = metrics; boss.position = Vector2(340, 100); _mount_collision(boss, 38.0); arena.add_child(boss); boss.set_physics_process(false)
			else:
				for i in 18:
					var target := MeasuredEnemy.new(); target.metrics = metrics; target.position = Vector2(270 + 60 * (i % 6), 40 + 60 * (i / 6)); _mount_collision(target, 17.0); arena.add_child(target); target.set_physics_process(false)
			var elapsed := 0.0
			for i in 600: await physics_frame; elapsed += 1.0 / Engine.physics_ticks_per_second
			var pending := get_nodes_in_group("wisp_projectiles").size()
			rows.append({"scenario": scenario, "card": card, "rank": 2, "duration": elapsed, "metrics": metrics.duplicate(), "in_flight_at_end": pending, "resolved_misses": maxi(0, int(metrics.shots) - int(metrics.hits) - pending), "wisps": growth.wisps.size(), "interval": growth.wisps[0].attack_interval, "coefficient": growth.wisps[0].damage_multiplier})
			arena.queue_free(); await process_frame
	var file := FileAccess.open(report_path, FileAccess.WRITE); file.store_string(JSON.stringify({"sample": "fixed_wisp_card_balance_v1", "time_scale": Engine.time_scale, "human_playtest": false, "rows": rows, "notes": "Six10s cases; two fixture cards each, standard starting weapon/no accessory or permanent growth, same stationary target layout. AI and player input frozen. Actual projectile movement, targeting including incoming-damage avoidance, collision and damage callbacks. Swarm18 stationary22HP targets; boss actual1800HP. No respawn or rewards. No claim about natural boss movement, player positioning, camera clipping, run economy or final balance."}, "  ") + "\n")
	print("WISP_CARD_BALANCE completed6 cases at scale1")
	quit()
