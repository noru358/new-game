extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",note)
func _run() -> void:
	var scene=load("res://game/wetland_boss_trial.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	for i in 5: await physics_frame
	check(scene.actors.size()==2,"boss practice has no ambiguous ambient crowd")
	check(scene.growth.growth_ended,"no XP or profile progression in this comparison")
	check(not scene.trial_boss.encounter_active,"approach is safe before entry")
	for point in [Vector2(4700,750),Vector2(5300,750),Vector2(5300,1600),Vector2(4700,1600),Vector2(5020,1060)]:
		check(scene.navigation.is_open(point,38),"duel floor open "+str(point))
		check(not scene.navigation.find_path(scene.start_point,point).is_empty(),"duel floor reachable")
	scene.teleport(Vector2(4750,1450))
	scene._physics_process(0.01)
	check(scene.trial_boss.encounter_active,"walking into court starts duel")
	scene.trial_boss.set_physics_process(false)
	scene.trial_boss.attack_cooldown=0
	scene.trial_boss._beast_velocity(0.01)
	scene.trial_boss._beast_velocity(0.01)
	var remaining: int=scene.trial_boss.roots_remaining
	check(remaining==2,"real source creates first of three roots")
	var roots=get_nodes_in_group("enemy_zones")
	check(roots.size()==1 and roots[0].get_parent()==scene.simulation,"warning uses scene-owned simulation")
	scene.teleport(scene.start_point)
	scene._physics_process(0.01)
	check(not scene.trial_boss.encounter_active and scene.trial_boss.roots_remaining==remaining,"leaving preserves pattern without attacking player")
	scene.teleport(Vector2(4750,1450))
	scene._physics_process(0.01)
	scene.trial_boss.take_hit(99999,Vector2.ZERO,false)
	check(scene.trial_finished and scene.trial_won,"boss defeat ends comparison")
	check(scene.growth.xp==0,"defeat does not award campaign XP")
	scene.queue_free()
	for i in 4: await process_frame
	check(get_nodes_in_group("enemy_zones").is_empty(),"scene exit removes root hazards")
	print("Wetland boss scene: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
