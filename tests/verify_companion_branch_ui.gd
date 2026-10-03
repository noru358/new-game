extends SceneTree
var failures:=0
var checks:=0
func _initialize()->void:call_deferred("_run")
func check(ok:bool,note:String)->void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",note)
func click(button:Button)->void:
	for down in [true,false]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=down
		event.position=button.get_global_rect().get_center()
		root.push_input(event,true)
	await process_frame
func _run()->void:
	for size in [Vector2i(960,540),Vector2i(1280,720)]:
		root.size=size
		root.content_scale_size=size
		root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		var hub=load("res://game/hub.tscn").instantiate()
		hub.profile_save_prefix="user://focus_branch_ui_%d" % Time.get_ticks_usec()
		hub.growth_save_prefix=hub.profile_save_prefix+"_unlocks"
		root.add_child(hub)
		current_scene=hub
		for i in 3:await process_frame
		hub.profile.currency=1000
		hub.profile.growth_ranks.POWER=2
		hub.profile.growth_ranks.WISP=2
		hub.tabs.current_tab=2
		hub.growth_tabs.current_tab=0
		hub._refresh()
		var button:Button=hub.attack_branch_buttons.COMPANION
		var scroll:ScrollContainer=hub.growth_tabs.get_child(0)
		for i in 3:await process_frame
		scroll.ensure_control_visible(button)
		for i in 3:await process_frame
		check(scroll.get_global_rect().encloses(button.get_global_rect()),"branch explanation reachable at "+str(size))
		check(button.size.y>=button.get_minimum_size().y,"two-line effect fits")
		check(button.text.contains("+10%") and button.text.contains("2초") and button.text.contains("사격 집중"),"numeric and behavioral effects both explained")
		await click(button)
		check(hub.profile.attack_branch=="COMPANION" and hub.profile.currency==940,"existing purchase contract and cost retained")
		await click(button)
		check(hub.profile.currency==940 and button.disabled,"repeat click cannot repurchase branch")
		var output:=OS.get_environment("FOCUS_CAPTURE_DIR")
		if not output.is_empty():
			check("CompanionFocusV46" in OS.get_user_data_dir(),"isolated native UI capture")
			for i in 3:await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("branch-%d.png" % size.x))
		hub.queue_free()
		for i in 4:await process_frame
	print("Companion branch UI: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
