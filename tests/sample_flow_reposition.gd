extends SceneTree
## Exact repeated input, ordinary physics at 60Hz. Synthetic frozen target;
## this is a combat mechanism fixture, not a difficulty/fun assessment.
var trace: Array = []
var failed := false

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "attack", "dash", "moving_slash"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	var arena := Node2D.new()
	root.add_child(arena)
	var p: SandboxPlayer = load("res://game/player.tscn").instantiate()
	p.global_position = Vector2(800, 700)
	p.flow_weave_enabled = true
	p.moving_slash_enabled = true
	p.moving_slash_distance_multiplier = 1.20
	p.permanent_slash_cooldown_reduction = 0.10
	p.set_combo_rank(2)
	arena.add_child(p)
	var target: TrainingEnemy = load("res://game/enemy.tscn").instantiate()
	target.max_health = 1000.0
	target.position = Vector2(870, 700)
	arena.add_child(target)
	target.set_physics_process(false)
	await physics_frame
	await physics_frame
	p.facing = Vector2.RIGHT
	p.moving_slash_requested = true
	await _frames(15)
	_record("after_slash", p, target)
	_check(target.health < 1000.0 and p.flow_weave_ready, "actual slash hit arms W_FLOW")
	var after_slash := target.health
	# Stop facing forwards after crossing the enemy; no target is ahead.
	p.queued_attack = true
	p.attack_buffer_time = p.ATTACK_BUFFER_TIME
	await _frames(20)
	_record("empty_basic", p, target)
	_check(is_equal_approx(target.health, after_slash), "next forward basic misses the crossed target")
	# Same player's reposition/turn input, then a real back-facing basic.
	Input.action_press("move_left")
	await _frames(7)
	Input.action_release("move_left")
	await _frames(1)
	p.queued_attack = true
	p.attack_buffer_time = p.ATTACK_BUFFER_TIME
	await _frames(8)
	_record("reposition_basic", p, target)
	_check(target.health < after_slash, "repositioned basic hits without auto aim")
	var report := {"fixture": "flow_reposition_v48", "engine": Engine.get_version_info().string, "human_playtest": false, "rendered": false, "time_scale": Engine.time_scale, "trace": trace}
	print("FLOW_REPOSITION ", JSON.stringify(report))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report-path="):
			var file := FileAccess.open(argument.trim_prefix("--report-path="), FileAccess.WRITE)
			file.store_string(JSON.stringify(report, "  ") + "\n")
	arena.queue_free()
	await _frames(2)
	quit(1 if failed else 0)

func _record(label: String, p: SandboxPlayer, enemy: TrainingEnemy) -> void:
	trace.append({"label": label, "position": [p.position.x, p.position.y], "target_position": [enemy.position.x, enemy.position.y], "health": enemy.health, "attack_sequence": p.attack_sequence, "step": p.attack_step, "prepared": p.flow_weave_ready, "empowered": p.flow_weave_attack, "refunded": p.flow_weave_refund_used, "slash_cooldown": p.moving_slash_cooldown})

func _frames(count: int) -> void:
	for i in count: await physics_frame

func _check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL: ", label)
