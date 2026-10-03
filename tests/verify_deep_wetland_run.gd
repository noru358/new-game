extends SceneTree
var failures:=0
var checks:=0
func _initialize()->void: call_deferred("_run")
func check(ok:bool,note:String)->void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",note)
func _run()->void:
	var session=preload("res://game/field_preview_session.gd")
	var prefix:="user://qa_wetland_run_%d"%Time.get_ticks_usec()
	var profile:=RunProfile.new()
	profile.save_prefix=prefix+"_profile"
	check(profile.settle("access-temple","SUCCESS",100,RunProfile.TEMPLE_REGION),"fixture earns temple access")
	check(profile.settle("access-jungle","SUCCESS",100,RunProfile.JUNGLE_REGION),"fixture earns jungle access")
	session.activate(self,prefix+"_profile",prefix+"_unlocks")
	var scene=load("res://game/deep_wetland_run.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	for i in 5: await physics_frame
	check(scene.region_id==RunProfile.WETLAND_REGION,"actual third-region identity")
	check(scene.temple_section!=null,"real destination section mounted")
	check(not scene.growth.growth_ended,"run growth is active")
	check(scene.BOSS_TIME==240,"four-minute contract")
	check(scene.profile.save_prefix==prefix+"_profile","same isolated camp record")
	for wall in scene.terrain.wall_areas:
		check(wall.has("color"),"minimap wall material present")
	check(scene.garden_terrain_mesh==null,"no duplicate hidden full-map mesh")
	scene.run_time=240
	scene.temple_section.tick(0)
	scene.temple_section.tick(1.3)
	check(scene.boss_spawned and scene.boss is WetlandBoss,"real wetland guardian spawned after countdown")
	scene.teleport(Vector2(4770,1480))
	scene.temple_section.tick(0)
	check(scene.boss.encounter_active,"destination entry starts duel")
	scene._update_run_hud()
	check(scene.boss_health_bar.visible and not scene.actors[scene.boss].get_node("HealthBar").visible,"one boss health bar during the duel")
	check(scene.minimap.title_text=="습지 지도" and not "테라스" in scene.minimap.legend_override,"wetland-specific map labels")
	scene.boss.set_physics_process(false)
	scene.boss.attack_cooldown=0
	scene.boss._beast_velocity(0.01)
	scene.boss._beast_velocity(0.01)
	var roots:=get_nodes_in_group("enemy_zones")
	check(roots.size()==1,"root tell created in real run")
	scene.temple_section.tick(0)
	check(not roots[0].is_queued_for_deletion(),"intruder cleanup preserves boss-owned roots")
	scene.run_currency=80
	scene.boss.take_hit(99999,Vector2.ZERO,false)
	scene._physics_process(0)
	check(scene.run_ended and scene.end_result=="SUCCESS","boss defeat settles the real run")
	check(scene.profile.wetland_owned and not scene.settlement_pending,"third-region clear persisted")
	var balance:int=scene.profile.currency
	check(scene.profile.settle(scene.run_id,"SUCCESS",80,RunProfile.WETLAND_REGION) and scene.profile.currency==balance,"result retries do not duplicate rewards")
	var reload:=RunProfile.new()
	reload.save_prefix=prefix+"_profile"
	reload.load_state()
	check(reload.wetland_owned and reload.currency==balance,"restart retains third-region result")
	scene.queue_free()
	for i in 5: await process_frame
	root.remove_meta(session.KEY)
	var folder:=DirAccess.open("user://")
	for file in folder.get_files():
		if file.begins_with(prefix.trim_prefix("user://")): folder.remove(file)
	print("Wetland run: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
