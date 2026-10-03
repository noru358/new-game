extends SceneTree
const Session=preload("res://game/field_preview_session.gd")
func _initialize()->void: call_deferred("_run")
func _capture(path:String)->void:
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(path)!=OK:
		printerr("FAIL: cannot save full-run capture")
		quit(1)
func _clear()->void:
	current_scene.queue_free()
	current_scene=null
	for i in 5: await process_frame
func _run()->void:
	var output:=OS.get_environment("WETLAND_CAPTURE_DIR")
	if output.is_empty() or not "WetlandV44" in OS.get_user_data_dir():
		printerr("FAIL: isolated full-run capture required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	for size in [Vector2i(960,540),Vector2i(1280,720)]:
		root.size=size
		root.content_scale_size=Vector2i(1280,720)
		root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		var prefix:="user://qa_render_wetland_%d"%size.x
		var profile:=RunProfile.new()
		profile.save_prefix=prefix+"_profile"
		profile.load_state()
		profile.settle("fixture-temple","SUCCESS",100,RunProfile.TEMPLE_REGION)
		profile.settle("fixture-jungle","SUCCESS",100,RunProfile.JUNGLE_REGION)
		Session.activate(self,prefix+"_profile",prefix+"_unlocks")
		var camp=load("res://game/travel_camp.tscn").instantiate()
		root.add_child(camp)
		current_scene=camp
		for i in 4: await physics_frame
		camp.preparation.open_section(0)
		camp.preparation.show()
		camp.preparation._select_region(RunProfile.WETLAND_REGION)
		await _capture(output.path_join("three-region-camp-%d.png"%size.x))
		await _clear()
		var scene=load("res://game/deep_wetland_run.tscn").instantiate()
		root.add_child(scene)
		current_scene=scene
		for i in 5: await physics_frame
		scene.set_physics_process(false)
		scene.wisp.set_physics_process(false)
		scene.teleport(Vector2(2350,1510))
		await _capture(output.path_join("wetland-growth-hud-%d.png"%size.x))
		scene.run_time=240
		scene.temple_section.tick(0)
		scene.temple_section.tick(1.3)
		scene.teleport(Vector2(4750,1450))
		scene.temple_section.tick(0)
		scene.boss.set_physics_process(false)
		scene.boss.attack_cooldown=0
		scene.boss._beast_velocity(0.01)
		scene.boss._beast_velocity(0.01)
		for zone in get_nodes_in_group("enemy_zones"): zone.set_physics_process(false)
		scene._update_run_hud()
		await _capture(output.path_join("wetland-boss-hud-%d.png"%size.x))
		await _clear()
	root.remove_meta(Session.KEY)
	print("Full wetland run/camp static captures: 6; injected access/time, not natural full play")
	quit()
