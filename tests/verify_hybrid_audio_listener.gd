extends SceneTree
var failures:=0
var checks:=0
var capture: AudioEffectCapture
var audio: AudioStreamPlayer2D
func _initialize()->void: call_deferred("_run")
func check(ok:bool,note:String)->void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",note)
func _record()->Vector2:
	audio.stop()
	# Drain the previous clip/mixer block before comparing a different position.
	await create_timer(0.15).timeout
	capture.clear_buffer()
	audio.play()
	await create_timer(0.30).timeout
	print("AUDIO_PROBE ",audio.global_position," listener=",str(root.get_audio_listener_2d().global_position) if root.get_audio_listener_2d()!=null else "default viewport center"," frames=",capture.get_frames_available())
	var frames:=capture.get_buffer(capture.get_frames_available())
	var energy:=Vector2.ZERO
	for frame in frames: energy+=Vector2(frame.x*frame.x,frame.y*frame.y)
	if frames.size()>0: energy/=frames.size()
	return Vector2(sqrt(energy.x),sqrt(energy.y))
func _run()->void:
	var scene=load("res://game/deep_wetland_field.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	for i in 4: await physics_frame
	scene.set_physics_process(false)
	scene.wisp.set_physics_process(false)
	for actor in scene.actors: actor.set_physics_process(false)
	var listener: AudioListener2D=scene.player.get_node_or_null("HybridAudioListener")
	check(listener!=null and listener.is_current(),"hybrid player owns the active 2D listener")
	if listener==null: quit(1);return
	check(is_equal_approx(listener.global_rotation,-PI/4),"panning orientation matches the isometric camera")
	AudioServer.add_bus()
	var bus:=AudioServer.bus_count-1
	AudioServer.set_bus_name(bus,"HybridListenerQA")
	capture=AudioEffectCapture.new()
	capture.buffer_length=0.5
	AudioServer.add_bus_effect(bus,capture)
	audio=scene.wisp.shot_audio
	audio.bus="HybridListenerQA"
	scene.player.global_position=Vector2(5000,1500)
	scene.wisp.global_position=scene.player.global_position+Vector2(30,-30)
	listener.clear_current()
	var far_without:=await _record()
	listener.make_current()
	var far_with:=await _record()
	scene.player.global_position=Vector2(1000,1500)
	scene.wisp.global_position=scene.player.global_position+Vector2(30,-30)
	var near_with:=await _record()
	check(listener.global_position==scene.player.global_position,"listener follows actual player movement")
	check(far_without.length()<0.00001,"baseline far-world playback attenuates to silence")
	check(far_with.length()>0.0001,"same far-world playback produces captured audio after correction")
	check(absf(near_with.length()-far_with.length())<maxf(0.002,far_with.length()*0.20),"equal relative distance retains similar gain anywhere on map")
	scene.wisp.global_position=scene.player.global_position+Vector2(160,-160)
	var right:=await _record()
	scene.wisp.global_position=scene.player.global_position+Vector2(-160,160)
	var left:=await _record()
	check(right.y>right.x and left.x>left.y,"screen-left and screen-right panning agree with the camera")
	print("Hybrid audio capture: ",JSON.stringify({"far_without":str(far_without),"far_with":str(far_with),"near_with":str(near_with),"right":str(right),"left":str(left),"checks":checks,"failures":failures,"human_listening":false}))
	audio.stop()
	scene.queue_free()
	for i in 4: await process_frame
	AudioServer.remove_bus(bus)
	quit(1 if failures else 0)
