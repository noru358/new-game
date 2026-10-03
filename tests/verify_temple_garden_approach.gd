extends SceneTree
## Reward interaction is within105 units; the old altar's exact center is not
## required. Confirm a legal southeast approach without moving that altar.
const APPROACH_OFFSET := Vector2(60,60)
var failures: Array[String] = []
func _initialize() -> void:call_deferred("_run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);printerr("FAIL: ",message)
func _run() -> void:
	var userdata:=OS.get_user_data_dir()
	var xdg:=OS.get_environment("XDG_DATA_HOME")
	if not ("TempleGardenV50" in userdata or (OS.get_name()=="Linux" and xdg.is_absolute_path() and userdata.begins_with(xdg.trim_suffix("/")+"/"))):
		printerr("FAIL: independent userdata required before profiles");quit(1);return
	var scene=load("res://game/temple_circuit_run.tscn").instantiate()
	scene.profile_save_prefix="user://garden_approach_%d_profile"%Time.get_ticks_usec()
	scene.growth_save_prefix=scene.profile_save_prefix+"_growth"
	root.add_child(scene)
	for connection in root.focus_exited.get_connections():root.focus_exited.disconnect(connection.callable)
	scene._set_paused(false)
	scene.practice_mode=true
	scene.wisp.set_physics_process(false)
	var section=scene.temple_section
	section.enter_garden()
	# Existing guard/reward fixture policy: actual three reserved guardian spawns
	# and defeated signals, synthetic high damage; not a natural combat claim.
	for point in section.layout.GUARDS:
		scene.teleport(point+Vector2(0,190))
		section.tick(1.1)
		for actor in scene.actors.keys():
			if is_instance_valid(actor) and actor is TrainingEnemy and not actor is GateBoss and section.field_area.has_point(actor.position) and actor.health>0:
				actor.take_hit(10000.0,Vector2.RIGHT,false)
		while scene.growth.choosing:scene.growth.choose_index(0)
	check(section.guardians_defeated==3 and section.guardian_reservations==0,"actual three guardian defeated signals preserved")
	var target: Vector2=section.layout.ALTAR+APPROACH_OFFSET
	var start: Vector2=section.layout.ALTAR+Vector2(60,240)
	check(scene.navigation.is_open(target,30) and scene.navigation.is_open(start,30),"southeast approach and preceding floor legal")
	check(not scene.navigation.find_path(section.layout.FIELD_ENTRY,target).is_empty(),"entry connects to reward approach")
	scene.teleport(start)
	var active:=0.0
	for frame in 120:
		if scene.player.position.distance_to(target)<4:break
		var direction:Vector2=scene.player.position.direction_to(target).rotated(-scene.player.input_rotation)
		for action in ["move_left","move_right","move_up","move_down"]:Input.action_release(action)
		Input.action_press("move_left",maxf(0.0,-direction.x))
		Input.action_press("move_right",maxf(0.0,direction.x))
		Input.action_press("move_up",maxf(0.0,-direction.y))
		Input.action_press("move_down",maxf(0.0,direction.y))
		await physics_frame
		active+=1.0/Engine.physics_ticks_per_second
	for action in ["move_left","move_right","move_up","move_down"]:Input.action_release(action)
	var reached:Vector2=scene.player.position
	check(reached.distance_to(target)<4 and reached.distance_to(section.layout.ALTAR)<105,"normal input reaches permitted reward distance")
	check(section.claim_garden_reward() and section.garden_claimed,"reward succeeds from southeast approach without standing in altar")
	var second:bool=section.claim_garden_reward()
	check(not second,"reward stays once per run")
	var saved:=RunProfile.new();saved.save_prefix=scene.profile_save_prefix;saved.load_state()
	check(saved.awakenings.has("EMBER_GARDEN") and saved.discovered_places.has("TEMPLE_GARDEN"),"discovery/awakening persisted before settlement")
	scene._close_awakening_receipt()
	section.leave_garden()
	check(scene.player.position==section.layout.RETURN_POINT and not section.in_garden,"return contract preserved")
	var report:Dictionary={"failures":failures,"target":[target.x,target.y],"reached":[reached.x,reached.y],"distance_to_altar":reached.distance_to(section.layout.ALTAR),"normal_movement_seconds":active,"guardians":section.guardians_defeated,"claimed":section.garden_claimed,"saved_awakening":saved.awakenings.has("EMBER_GARDEN"),"scope":"normal input on final approach; synthetic guardian damage; actual reward+save+return; no natural combat/fun claim"}
	var path:=OS.get_environment("GARDEN_APPROACH_OUTPUT")
	if not path.is_empty():
		var f:=FileAccess.open(path,FileAccess.WRITE)
		if f!=null:f.store_string(JSON.stringify(report,"  "))
	print("GARDEN_APPROACH: ",JSON.stringify(report))
	scene.queue_free();paused=false
	for i in 3:await process_frame
	quit(0 if failures.is_empty() else 1)
