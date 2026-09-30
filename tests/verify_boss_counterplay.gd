extends SceneTree
# Repeat late-phase patterns without deaths; this does not measure kill time.
var failures := 0
func _initialize() -> void: call_deferred("_run")
func controls(direction: Vector2, attack: bool) -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "attack"]: Input.action_release(action)
	if direction.length() > 0.1:
		Input.action_press("move_right" if direction.x > 0 else "move_left", absf(direction.x))
		Input.action_press("move_down" if direction.y > 0 else "move_up", absf(direction.y))
	if attack: Input.action_press("attack")
func _run() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "attack", "dash", "moving_slash"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	Engine.time_scale = 3.0
	Engine.physics_ticks_per_second = 180
	for jungle in [false, true]:
		for evade in [false, true]:
			var arena := Node2D.new()
			root.add_child(arena)
			var player = load("res://game/player.tscn").instantiate()
			player.position = Vector2(1100, 700)
			player.input_rotation = 0.0
			player.move_speed_multiplier = 1.12
			player.basic_speed_bonus = 0.18
			player.attack_active_multiplier = 1.6
			player.attack_recovery_multiplier = 0.78
			player.max_health = 1000
			arena.add_child(player)
			player.health = 1000
			var boss = load("res://game/jungle_warden.tscn" if jungle else "res://game/gate_boss.tscn").instantiate()
			boss.position = Vector2(1160, 700)
			boss.target = player
			boss.collision_mask = 4
			arena.add_child(boss)
			boss.phase = 2
			boss.charge_damage = 25
			var damage_dealt := 0.0
			for i in 960:
				var away: Vector2 = boss.position.direction_to(player.position)
				var distance: float = player.position.distance_to(boss.position)
				var direction := -away if distance > 65 else Vector2.ZERO
				var attack := true
				if evade:
					if boss is JungleWarden:
						if boss.sweep_warning > 0:
							var forward: float = (player.position - boss.position).dot(boss.locked_direction)
							var side: float = (player.position - boss.position).dot(boss.locked_direction.orthogonal())
							var choices := [Vector2(forward + 75, 0), Vector2(325 - forward, 1), Vector2(290 - side, 2), Vector2(290 + side, 3)]
							choices.sort_custom(func(a, b): return a.x < b.x)
							direction = [-boss.locked_direction, boss.locked_direction, boss.locked_direction.orthogonal(), -boss.locked_direction.orthogonal()][int(choices[0].y)] if choices[0].x > 0 else Vector2.ZERO
							attack = false
						elif boss.gust_warning > 0:
							direction = -away if distance > 120 else Vector2.ZERO
							attack = false
					else:
						if boss.warning_time > 0 or boss.charge_time > 0:
							direction = boss.locked_direction.orthogonal()
							attack = false
						elif boss.shock_warning > 0:
							direction = away if distance < 255 else Vector2.ZERO
							attack = false
						elif boss.ring_warning > 0:
							direction = -away if distance > 85 else Vector2.ZERO
							attack = false
				controls(direction, attack)
				await physics_frame
				damage_dealt += boss.max_health - boss.health
				boss.health = boss.max_health
			print("PROBE jungle=", jungle, " evade=", evade, " received=", 1000 - player.health, " dealt=", damage_dealt, " strikes=", boss.attacks_fired)
			var received: float = 1000 - player.health
			if (evade and received > 22.0) or (not evade and received < 80.0) or damage_dealt < 80.0 or boss.attacks_fired < 4:
				failures += 1
				printerr("FAIL: close pressure, readable escape and counterattack must coexist")
			controls(Vector2.ZERO, false)
			arena.queue_free()
			await process_frame
	quit(1 if failures else 0)
