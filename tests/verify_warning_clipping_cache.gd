extends SceneTree
var pixel_output := ""
var failures := 0
var checks := 0
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pixel-output="):pixel_output=arg.trim_prefix("--pixel-output=")
	call_deferred("run")
func check(value: bool, message: String):
	checks+=1
	if not value:
		failures+=1
		printerr("FAIL: ",message)
func fresh(scene, center: Vector2, a0: float, a1: float, radius: float) -> bool:
	for angle in [a0,(a0+a1)*0.5,a1]:
		if not scene.clear_attack(center,center+Vector2.from_angle(angle)*radius):return false
	return true
func compare(scene,center: Vector2,radius: float):
	for i in 48:
		var a0:float=TAU*float(i)/48
		var a1:float=TAU*float(i+1)/48
		var expected:=fresh(scene,center,a0,a1,radius)
		check(scene._ring_segment_clear(center,a0,a1,radius)==expected,"cached clipping equals fresh rays")
		check(scene._ring_segment_clear(center,a0,a1,radius)==expected,"repeated clipping equals fresh rays")
func advance():
	await physics_frame
	await process_frame
func run():
	var scene=preload("res://tests/fixtures/warning_cache_probe.gd").new()
	root.add_child(scene)
	current_scene=scene
	scene._set_paused(false)
	scene.set_process(false)
	scene.set_physics_process(false)
	scene.player.set_physics_process(false)
	for actor in scene.actors:
		if actor is TrainingEnemy:actor.set_physics_process(false)
	scene.wisp.set_physics_process(false)
	await advance()
	for center in [Vector2(100,100),Vector2(1190,1650),Vector2(1390,1000)]:
		for radius in [66.0,92.0,210.0]:compare(scene,center,radius)
	var blocker:=StaticBody2D.new()
	blocker.collision_layer=4
	blocker.collision_mask=0
	var shape:=RectangleShape2D.new()
	shape.size=Vector2(30,200)
	var collision:=CollisionShape2D.new()
	collision.shape=shape
	blocker.add_child(collision)
	blocker.position=Vector2(175,100)
	scene.simulation.add_child(blocker)
	await advance()
	check(not scene._ring_segment_clear(Vector2(100,100),0,0.01,92),"new blocker changes clipping")
	compare(scene,Vector2(100,100),92)
	blocker.position=Vector2(400,100)
	await advance()
	check(scene._ring_segment_clear(Vector2(100,100),0,0.01,92),"moved blocker clears clipping")
	shape.size=Vector2(600,200)
	await advance()
	check(not scene._ring_segment_clear(Vector2(100,100),0,0.01,92),"changed shape invalidates clipping")
	compare(scene,Vector2(100,100),92)
	collision.set_deferred("disabled",true)
	await advance()
	check(scene._ring_segment_clear(Vector2(100,100),0,0.01,92),"disabled shape clears clipping")
	collision.set_deferred("disabled",false)
	blocker.collision_layer=2
	await advance()
	check(scene._ring_segment_clear(Vector2(100,100),0,0.01,92),"layer change clears clipping")
	blocker.collision_layer=4
	await advance()
	compare(scene,Vector2(100,100),92)
	blocker.queue_free()
	await advance()
	check(scene._ring_segment_clear(Vector2(100,100),0,0.01,92),"freed blocker clears clipping")
	# Fixed clip/mesh output must match the original rays, including wall edges.
	var enemy=scene._spawn_enemy_at(Vector2(1180,1650),TrainingEnemy.Role.ZONE,100)
	enemy.set_physics_process(false)
	var zone:=EnemyZone.new()
	zone.setup(enemy,scene.player)
	scene.simulation.add_child(zone)
	zone.global_position=Vector2(1190,1650)
	zone.set_physics_process(false)
	await advance()
	scene._draw_enemy_warnings(1)
	var cached=scene.warning_mesh.surface_get_arrays(0)
	var cached_image:Image
	if not pixel_output.is_empty():
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		cached_image=root.get_texture().get_image()
		cached_image.save_png(pixel_output+"-cached.png")
	var initial_rays:int=scene.ray_calls
	scene._draw_enemy_warnings(1)
	check(scene.ray_calls==initial_rays,"unchanged zone makes zero repeated terrain rays")
	# Force the cache empty on each query to replay the original clipping result.
	scene.uncached=true
	scene._draw_enemy_warnings(1)
	check(cached==scene.warning_mesh.surface_get_arrays(0),"warning vertices/colors/indices unchanged")
	if not pixel_output.is_empty():
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var original_image:=root.get_texture().get_image()
		original_image.save_png(pixel_output+"-fresh.png")
		check(cached_image.get_data()==original_image.get_data(),"native warning pixels unchanged")
	scene.uncached=false
	for i in 100:compare(scene,Vector2(100+i,100),92)
	check(scene.warning_ring_clipping.size()<=64,"cache remains bounded")
	scene.queue_free()
	await process_frame
	print("Warning clipping cache: ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
