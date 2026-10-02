extends SceneTree
var output := ""
var failures := 0
var results: Array = []
func _initialize() -> void: call_deferred("_run")
func _image() -> Image:
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func _difference(a: Image, b: Image) -> int:
	var count := 0
	# Player is centered; avoid spending time on static HUD/background pixels.
	for y in range(a.get_height()/4, a.get_height()*3/4):
		for x in range(a.get_width()/3, a.get_width()*2/3):
			var c := a.get_pixel(x,y) - b.get_pixel(x,y)
			if absf(c.r) + absf(c.g) + absf(c.b) > 0.04: count += 1
	return count
func _run() -> void:
	output = OS.get_environment("WETLAND_CAPTURE_DIR")
	if output.is_empty() or not "WetlandV44" in OS.get_user_data_dir():
		printerr("FAIL: isolated wetland capture required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var scene = load("res://game/deep_wetland_field.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 5: await physics_frame
	scene.set_physics_process(false)
	scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
	for actor in scene.actors:
		if actor != scene.player: scene.actors[actor].hide()
	scene.wisp.set_physics_process(false)
	var body: Sprite3D = scene.actors[scene.player].get_node("Body")
	var meshes: Array[Node] = scene.find_children("*", "MeshInstance3D", true, false)
	var visibility: Array = []
	for mesh in meshes: visibility.append(mesh.visible)
	for size in [Vector2i(960,540), Vector2i(1280,720)]:
		root.size = size
		root.content_scale_size = Vector2i(1280,720)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		for point in [Vector2(3620,970),Vector2(3980,970),Vector2(4060,690),Vector2(4600,690),scene.Field.INNER_COURT,Vector2(4780,1670),scene.Field.OFFERING_GROVE,Vector2(3420,1630)]:
			scene.teleport(point)
			for i in 30: await process_frame
			scene.set_process(false)
			var counts: Array = []
			for scenery in [true,false]:
				for i in meshes.size(): meshes[i].visible = visibility[i] if scenery else false
				body.hide()
				var empty := await _image()
				body.show()
				var filled := await _image()
				counts.append(_difference(filled,empty))
				if scenery: filled.save_png(output.path_join("visible-%d-%d-%d.png" % [point.x,point.y,size.x]))
			var ratio := float(counts[0])/maxf(1.0,float(counts[1]))
			results.append({"point":[point.x,point.y],"width":size.x,"visible_pixels":counts[0],"unobstructed_pixels":counts[1],"ratio":ratio})
			if counts[1]<100 or ratio<0.92:
				failures += 1
				printerr("FAIL: player occlusion ",point," ",size," ratio=",ratio)
			for i in meshes.size(): meshes[i].visible = visibility[i]
			scene.set_process(true)
	var file := FileAccess.open(output.path_join("visibility.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"cases":results,"failures":failures},"  "))
	file.close()
	scene.queue_free()
	for i in 3: await process_frame
	print("Wetland field opaque visibility: ",results.size()," cases, ",failures," failures")
	quit(1 if failures else 0)
