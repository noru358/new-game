extends SceneTree
## Real player/helper/wisp physics; isolated injected setup, not natural campaign evidence.
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("_run")
func check(ok:bool,note:String)->void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",note)
func _run()->void:
	var prefix:="user://focus_lifecycle_%d" % Time.get_ticks_usec()
	var profile:=RunProfile.new()
	profile.save_prefix=prefix
	profile.settle("fixture","SUCCESS",1000)
	for id in ["POWER","POWER","WISP","WISP"]:profile.buy_growth(id,6)
	profile.buy_attack_branch("COMPANION")
	var scene=load("res://game/hybrid_region.tscn").instantiate()
	scene.profile_save_prefix=prefix
	scene.growth_save_prefix=prefix+"_unlocks"
	scene.companion_focus_trial=true
	root.add_child(scene)
	current_scene=scene
	for i in 3:await physics_frame
	# Only ambient scheduling is disabled. Player, companion, projectiles and focus run normally.
	scene.set_physics_process(false)
	scene.teleport(Vector2(660,1120))
	scene.player.facing=Vector2.RIGHT
	var target=scene._spawn_enemy_at(Vector2(725,1120),TrainingEnemy.Role.SUPPORT,1000)
	target.set_physics_process(false)
	var focus=scene.get_node("CompanionFocus")
	var initial:float=target.health
	Input.action_press("attack")
	for i in 40:
		await physics_frame
		if scene.player.has_meta(focus.META):break
	Input.action_release("attack")
	check(scene.player.has_meta(focus.META),"real input and automatic physics commit focus")
	check(target.health<initial,"real input actually damaged the priority target")
	var remaining:float=focus.remaining
	scene.growth.gain_xp(scene.growth.next_xp())
	check(scene.growth.choosing and paused,"actual card modal pauses the scene")
	await create_timer(0.20,true).timeout
	check(is_equal_approx(focus.remaining,remaining),"card modal consumes no active focus time")
	scene.growth.choose_index(0)
	check(not paused,"real card choice resumes physics")
	for i in 130:await physics_frame
	check(not scene.player.has_meta(focus.META) and not focus.marker.visible,"automatic deadline clears focus without manual helper ticks")
	# A second accepted strike renews focus; real section switching removes it permanently.
	scene.player.next_combo_step=1
	scene.player.attack_step=0
	scene.player.attack_lock=0
	scene.player.attack_blocked_until_release=false
	scene.player.facing=Vector2.RIGHT
	target.position=scene.player.position+Vector2(65,0)
	Input.action_press("attack")
	for i in 40:
		await physics_frame
		if scene.player.has_meta(focus.META):break
	Input.action_release("attack")
	check(scene.player.has_meta(focus.META),"later real strike renews focus")
	scene.temple_section.enter_garden()
	for i in 3:await physics_frame
	check(scene.temple_section.in_garden and not target.is_in_group("training_enemies"),"actual field transition deactivates old target")
	check(not scene.player.has_meta(focus.META) and not focus.marker.visible,"automatic field switch clears focus")
	scene.temple_section.leave_garden()
	for i in 3:await physics_frame
	check(not scene.temple_section.in_garden and target.is_in_group("training_enemies"),"actual return restores ordinary target availability")
	check(not scene.player.has_meta(focus.META),"return does not restore expired field focus")
	Input.action_release("attack")
	paused=false
	scene.queue_free()
	for i in 5:await process_frame
	print("Companion focus automatic lifecycle: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
