extends "res://tests/sample_build_comparison.gd"
## Fixed existing controller, new independent instrumentation. No bot tuning.
const Ledger = preload("res://tests/helpers/build_action_ledger.gd")
var ledger = Ledger.new()
var current_basic := 0
var current_basic_source := ""
var current_basic_step := 0
var current_slash := 0
var observed_hit_targets := {}
var observed_slash_targets := {}
var refund_observed := false
var latest_cooldown := 0.0
var pre_hit_cooldown := 0.0
var focused_shots := 0
var focus_seconds := 0.0
var ledger_time := 0.0

func _initialize() -> void:
	node_added.connect(_mount_observation)
	call_deferred("_run")

func _isolated() -> bool:
	var expected := OS.get_environment("BUILD_ACTION_USER_DIR").simplify_path()
	return expected.contains("/Codex-Combat-Actions-v48/") and OS.get_user_data_dir().simplify_path() == expected and not FileAccess.file_exists("user://loop_conquest_profile_a.json") and not FileAccess.file_exists("user://loop_conquest_profile_b.json")

func _mount_observation(node: Node) -> void:
	if node is TrainingEnemy:
		node.ready.connect(func(): ledger.register(node.get_instance_id(), node.health))

func _observe_actions() -> void:
	super._observe_actions()
	var p: SandboxPlayer = scene.player
	var active: float = scene.run_time
	if p.attack_sequence != current_basic:
		if current_basic > 0: ledger.finish(current_basic_source, current_basic, active, p.next_combo_step == 1 and current_basic_step != p.combo_limit())
		current_basic = p.attack_sequence
		current_basic_step = p.attack_step
		current_basic_source = "basic_%d" % p.attack_step
		observed_hit_targets.clear()
		refund_observed = false
		ledger.begin(current_basic_source, current_basic, active, {"empowered": p.flow_weave_attack, "position": [p.global_position.x, p.global_position.y], "direction": [p.attack_direction.x, p.attack_direction.y]})
	elif p.attack_step == 0 and current_basic > 0:
		ledger.finish(current_basic_source, current_basic, active, p.moving_slash_time > 0.0 or p.dash_time > 0.0)
	if p.moving_slash_sequence != current_slash:
		if current_slash > 0: ledger.finish("slash", current_slash, active, p.dash_time > 0.0)
		current_slash = p.moving_slash_sequence
		observed_slash_targets.clear()
		ledger.begin("slash", current_slash, active)
	elif p.moving_slash_time == 0.0 and current_slash > 0:
		ledger.finish("slash", current_slash, active, p.dash_time > 0.0)
	var dt := maxf(0.0, active - ledger_time)
	if p.has_meta(&"companion_focus_target"): focus_seconds += dt
	ledger_time = active
	latest_cooldown = p.moving_slash_cooldown

func _on_basic_hit(point: Vector2, direction: Vector2, step: int, finisher: bool) -> void:
	# A swing may begin and land between polling frames. Register synchronously.
	_observe_actions()
	var p: SandboxPlayer = scene.player
	for id in p.hit_targets:
		if observed_hit_targets.has(id): continue
		observed_hit_targets[id] = true
		var target = instance_from_id(id)
		if is_instance_valid(target): ledger.hit(id, target.health, current_basic_source, p.attack_sequence, scene.run_time)
	if p.flow_weave_refund_used and not refund_observed:
		# The unchanged path filter reads cooldown immediately before damage.
		# No 0.22-per-event multiplication across the zero floor.
		ledger.refund(pre_hit_cooldown, p.moving_slash_cooldown, scene.run_time, p.attack_sequence)
		refund_observed = true
	super._on_basic_hit(point, direction, step, finisher)

func _on_slash_hit(point: Vector2) -> void:
	_observe_actions()
	var p: SandboxPlayer = scene.player
	for id in p.moving_slash_targets:
		if observed_slash_targets.has(id): continue
		observed_slash_targets[id] = true
		var target = instance_from_id(id)
		if is_instance_valid(target): ledger.hit(id, target.health, "slash", p.moving_slash_sequence, scene.run_time)
	super._on_slash_hit(point)

func _sync_wisp_observers() -> void:
	for wisp in scene.growth.wisps:
		if observed_wisps.has(wisp.get_instance_id()): continue
		wisp.enemy_hit.connect(func(enemy): ledger.hit(enemy.get_instance_id(), enemy.health, "companion", wisp.shots_fired, scene.run_time))
	super._sync_wisp_observers()

func _on_wisp_shot(target: TrainingEnemy, id: int) -> void:
	if scene.player.has_meta(&"companion_focus_target"):
		var ref = scene.player.get_meta(&"companion_focus_target")
		if ref is WeakRef and ref.get_ref() == target: focused_shots += 1
	super._on_wisp_shot(target, id)

func _checkpoint(label: String) -> void:
	if label == "initial":
		var original: Callable = scene.player.attack_path_filter
		scene.player.attack_path_filter = func(from: Vector2, to: Vector2) -> bool:
			var allowed: bool = original.call(from, to) if original.is_valid() else true
			if allowed:
				pre_hit_cooldown = scene.player.moving_slash_cooldown
				for enemy in get_nodes_in_group("training_enemies"):
					if enemy.global_position.is_equal_approx(to): ledger.register(enemy.get_instance_id(), enemy.health)
			return allowed
	super._checkpoint(label)
	checkpoints[-1]["action_ledger"] = ledger.snapshot()
	checkpoints[-1]["focus_seconds"] = focus_seconds
	checkpoints[-1]["focused_shots"] = focused_shots
