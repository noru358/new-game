extends SceneTree
var failures:=0
var checks:=0
var scene
var focus
var primary_hits:=0
func _initialize()->void:call_deferred("_run")
func check(ok:bool,note:String)->void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",note)
func mark(enemy)->void:
	scene.player.attack_sequence+=1
	focus._on_hit(enemy)
	focus._physics_process(0.0)
func _run()->void:
	var prefix:="user://focus_test_%d" % Time.get_ticks_usec()
	var profile:=RunProfile.new()
	profile.save_prefix=prefix
	profile.settle("fixture", "SUCCESS",1000)
	for id in ["POWER","POWER","WISP","WISP"]:profile.buy_growth(id,6)
	check(profile.buy_attack_branch("COMPANION"),"legal branch fixture")
	scene=load("res://game/hybrid_region.tscn").instantiate()
	check(scene.companion_focus_trial,"accepted companion targeting is enabled by default")
	scene.companion_focus_trial=true
	scene.profile_save_prefix=prefix
	scene.growth_save_prefix=prefix+"_unlocks"
	root.add_child(scene)
	current_scene=scene
	for i in 3:await physics_frame
	scene.set_physics_process(false)
	scene.player.set_physics_process(false)
	scene.wisp.set_physics_process(false)
	focus=scene.get_node("CompanionFocus")
	focus.set_physics_process(false)
	var p=scene.player
	var w=scene.wisp
	scene.teleport(Vector2(660,1120))
	w.global_position=p.global_position
	w.target_visibility_filter=func(_enemy):return true
	var near=scene._spawn_enemy_at(p.position+Vector2(0,45),TrainingEnemy.Role.FRAGMENT,1000)
	var rear=scene._spawn_enemy_at(p.position+Vector2(65,0),TrainingEnemy.Role.SUPPORT,1000)
	near.set_physics_process(false)
	rear.set_physics_process(false)
	for i in 2:await physics_frame
	check(w.find_target()==near,"baseline prefers nearer eligible enemy")
	var cadence:float=w.attack_interval
	var damage:float=w.damage_multiplier+w.permanent_damage_bonus
	p.basic_target_struck.connect(func(_enemy):primary_hits+=1)
	p.facing=Vector2.RIGHT
	p.next_combo_step=1
	p._start_attack()
	p._hit_enemies(p._attack_spec(1))
	focus._physics_process(0.0)
	check(primary_hits==1,"real primary hit emits one surviving target")
	check(w.find_target()==rear,"struck priority target beats nearer unstruck enemy")
	check(focus.marker.visible,"one focus marker visible")
	var capture_dir:=OS.get_environment("FOCUS_CAPTURE_DIR")
	if not capture_dir.is_empty():
		check("CompanionFocusV46" in OS.get_user_data_dir(),"render uses isolated focus userdata")
		DirAccess.make_dir_recursive_absolute(capture_dir)
		for size in [Vector2i(960,540),Vector2i(1280,720)]:
			root.size=size
			root.content_scale_size=Vector2i(1280,720)
			root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
			for i in 30:await process_frame
			focus._physics_process(0.0)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(capture_dir.path_join("focus-%d.png" % size.x))
	var rear_before:float=rear.health
	var near_before:float=near.health
	w._fire(w.find_target())
	for i in 20:await physics_frame
	check(rear.health<rear_before and near.health==near_before,"actual projectile follows clear line to marked enemy")

	check(w.attack_interval==cadence and w.damage_multiplier+w.permanent_damage_bonus==damage,"focus changes neither cadence nor damage")
	var before:float=focus.remaining
	scene.paused=true
	focus._physics_process(20.0)
	check(focus.remaining==before,"manual pause freezes focus deadline")
	scene.paused=false
	paused=true
	focus._physics_process(20.0)
	check(focus.remaining==before,"tree/card pause freezes focus deadline")
	paused=false
	focus._physics_process(2.01)
	check(w.find_target()==near and not focus.marker.visible,"expiration restores nearest targeting")
	mark(rear)
	var shot:=WispProjectile.new()
	shot.target=rear
	shot.damage=rear.health+1
	scene.simulation.add_child(shot)
	shot.set_physics_process(false)
	check(w.find_target()==near,"incoming lethal damage sends next shot to alternative")
	shot.queue_free()
	await process_frame
	check(w.find_target()==rear,"ordinary target fallback does not erase a still-valid focus")
	var saved:Vector2=rear.position
	rear.position=p.position+Vector2(900,0)
	check(w.find_target()==near,"out-of-range target cannot extend range")
	rear.position=saved
	w.target_visibility_filter=func(enemy):return enemy!=rear
	check(w.find_target()==near,"offscreen focused enemy is not targeted")
	w.target_visibility_filter=func(_enemy):return true
	var wall:=StaticBody2D.new()
	wall.collision_layer=4
	wall.position=p.position+Vector2(35,0)
	var shape:=CollisionShape2D.new()
	var rect:=RectangleShape2D.new()
	rect.size=Vector2(5,180)
	shape.shape=rect
	wall.add_child(shape)
	scene.simulation.add_child(wall)
	for i in 2:await physics_frame
	check(w.find_target()==near,"real wall blocks all focused aim points")
	wall.queue_free()
	for i in 2:await physics_frame
	check(w.find_target()==rear,"focus resumes only while live active-time window remains")
	scene.growth.card_ranks["S_WISP_COUNT"]=1
	scene.growth._sync_wisps()
	var added=scene.growth.wisps[-1]
	added.set_physics_process(false)
	added.global_position=w.global_position
	added.target_visibility_filter=func(_enemy):return true
	check(added.find_target()==rear,"newly added companion inherits current player focus")
	rear.remove_from_group("training_enemies")
	check(w.find_target()==near and not p.has_meta(focus.META),"inactive field immediately invalidates weak target")
	rear.add_to_group("training_enemies")
	focus._physics_process(0.0)
	check(not focus.marker.visible and w.find_target()==near,"re-entry cannot resurrect old focus")
	mark(rear)
	scene.temple_section.retry_pending=true
	focus._physics_process(0.0)
	check(not p.has_meta(focus.META),"retry clears focus")
	scene.temple_section.retry_pending=false
	# Multi-hit choice uses contact snapshots, independent of callback ordering/movement.
	p.attack_direction=Vector2.RIGHT
	p.attack_sequence+=1
	focus._on_hit(near)
	focus._on_hit(rear)
	rear.position=p.position+Vector2(0,100)
	focus._physics_process(0.0)
	check(focus.target_ref.get_ref()==rear,"gather movement cannot change contact-time forward priority")
	rear.position=saved
	focus._clear()
	p.attack_sequence+=1
	focus._on_hit(rear)
	focus._on_hit(near)
	focus._physics_process(0.0)
	check(focus.target_ref.get_ref()==rear,"reversed callbacks select same primary target")
	focus._on_hit(near)
	focus._physics_process(0.0)
	check(focus.target_ref.get_ref()==rear,"later same-swing hits cannot replace committed target")
	focus._clear()
	p.attack_sequence+=1
	focus._on_hit(near)
	near.remove_from_group("training_enemies")
	focus._physics_process(0.0)
	near.add_to_group("training_enemies")
	focus._on_hit(rear)
	focus._physics_process(0.0)
	check(focus.target_ref!=null and focus.target_ref.get_ref()==rear,"invalid early candidate does not consume same-swing successful designation")
	focus._clear()
	var hit_count:=primary_hits
	p.hit_targets.clear()
	p._trigger_flow_wave(rear.position)
	focus._physics_process(0.0)
	check(primary_hits==hit_count and not p.has_meta(focus.META),"RIPPLE secondary damage never marks")
	# Lethal primary hit and rejected boss hit do not emit an accepted living target.
	near.position=p.position+Vector2(0,300)
	rear.health=1
	p.next_combo_step=1
	p._start_attack()
	p._hit_enemies(p._attack_spec(1))
	focus._physics_process(0.0)
	check(primary_hits==hit_count and not p.has_meta(focus.META),"lethal primary hit does not leave focus")
	var boss:=GateBoss.new()
	boss.target=p
	boss.position=p.position+Vector2(65,0)
	scene.simulation.add_child(boss)
	boss.set_physics_process(false)
	boss.encounter_active=false
	var boss_health:float=boss.health
	p.next_combo_step=1
	p._start_attack()
	p._hit_enemies(p._attack_spec(1))
	check(boss.health==boss_health and primary_hits==hit_count,"rejected boss hit does not mark")
	boss.queue_free()
	paused=false
	scene.queue_free()
	for i in 5:await process_frame

	for branch in ["","DIRECT"]:
		var other_prefix:String=prefix+"_"+branch
		var other:=RunProfile.new()
		other.save_prefix=other_prefix
		other.settle("fixture", "SUCCESS",1000)
		for id in ["POWER","POWER","WISP","WISP"]:other.buy_growth(id,6)
		if not branch.is_empty():check(other.buy_attack_branch(branch),"legal comparison branch")
		var ordinary=load("res://game/hybrid_region.tscn").instantiate()
		ordinary.companion_focus_trial=true
		ordinary.profile_save_prefix=other_prefix
		ordinary.growth_save_prefix=other_prefix+"_unlocks"
		root.add_child(ordinary)
		for i in 3:await physics_frame
		check(not ordinary.has_node("CompanionFocus"),"no focus helper on "+branch+" branch")
		check(is_equal_approx(ordinary.wisp.permanent_damage_bonus,0.0),"ordinary companion damage unchanged")
		check(is_equal_approx(ordinary.player.permanent_basic_damage_bonus,0.2 if branch=="DIRECT" else 0.1),"ordinary direct damage unchanged")
		ordinary.queue_free()
		for i in 4:await process_frame
	print("Companion focus: ",checks," checks, ",failures," failures; injected contract fixture, not human play")
	quit(1 if failures else 0)
