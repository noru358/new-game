extends "res://game/deep_wetland_field.gd"
## Playable combat construction sample. No campaign state or rewards.
const DuelTerrain = preload("res://game/wetland_boss_trial_terrain.gd")
var trial_boss: WetlandBoss
var trial_finished := false
var trial_won := false
var root_visuals: Dictionary = {}
func _init() -> void:
	super._init()
	terrain = DuelTerrain.new()
	start_point = Vector2(4460,1710)
	scene_title = "Wetland stone face — combat candidate"
func _place_encounters() -> Array: return []
func _inner_ruins() -> Array:
	return Field.INNER_RUINS.filter(func(area): return not area.intersects(DuelTerrain.DUEL.grow(30)))
func _ready() -> void:
	super._ready()
	trial_boss = preload("res://game/wetland_boss.tscn").instantiate()
	trial_boss.position = Vector2(5020,1060)
	trial_boss.target = player
	trial_boss.projectile_parent = simulation
	trial_boss.encounter_area = DuelTerrain.DUEL
	trial_boss.arena_bounds = DuelTerrain.DUEL
	trial_boss.navigation = navigation
	trial_boss.collision_mask = 6
	trial_boss.zone_path_filter = clear_attack
	simulation.add_child(trial_boss)
	trial_boss.suspend_encounter()
	trial_boss.remove_from_group("training_enemies")
	var visual := _actor_visual(Color.WHITE)
	visual.get_node("Body").hide()
	_add_health_bar(visual,trial_boss)
	visual.get_node("HealthBar").position.y=2.2
	actors[trial_boss]=visual
	actor_motion[trial_boss]=[trial_boss.position,trial_boss.position]
	_build_stone_face(visual)
	trial_boss.counter_struck.connect(func(point): _flash(point,Color("ffe4a3"),0.34))
	trial_boss.defeated.connect(func(): trial_won=true;trial_finished=true)
	_update_hud()
func _build_stone_face(parent: Node3D) -> void:
	preload("res://game/wetland_guardian_visual.gd").build(self,parent,"StoneFace")
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if paused or get_tree().paused or not is_instance_valid(trial_boss): return
	if player.health<=0:
		trial_finished=true
		trial_boss.suspend_encounter()
		trial_boss.remove_from_group("training_enemies")
	if trial_finished: return
	var inside := DuelTerrain.DUEL.has_point(player.position)
	if inside and not trial_boss.encounter_active:
		trial_boss.resume_from_boundary()
		trial_boss.add_to_group("training_enemies")
	elif not inside and trial_boss.encounter_active:
		trial_boss.pause_for_boundary()
		trial_boss.remove_from_group("training_enemies")
	if not inside: trial_boss.tick_outside(delta)
func _process(delta: float) -> void:
	super._process(delta)
	_update_root_visuals()
	if is_instance_valid(trial_boss) and actors.has(trial_boss):
		var face: Node3D=actors[trial_boss].get_node("StoneFace")
		face.rotation.y=atan2(player.position.x-trial_boss.position.x,player.position.y-trial_boss.position.y)
		face.rotation.x=-0.08 if trial_boss.pattern_active else 0.08 if trial_boss.recovery_time>0 else 0.0
func _update_hud() -> void:
	if hud==null or not is_instance_valid(player): return
	var state := "성소 진입 시 교전"
	if trial_finished: state="격파 · R 다시 시작" if trial_won else "패배 · R 다시 시작"
	elif is_instance_valid(trial_boss) and trial_boss.encounter_active:
		state="뿌리 예고 밖으로 이동" if trial_boss.pattern_active else "반격 기회" if trial_boss.recovery_time>0 else "습지 석면 수호자"
	hud.text="습지 보스 시험 · 저장/보상 없음\n"+state
	if player_health_bar!=null:
		player_health_bar.max_value=player.max_health
		player_health_bar.value=player.health

func _update_root_visuals() -> void:
	preload("res://game/wetland_guardian_visual.gd").update_roots(self,trial_boss,root_visuals)
