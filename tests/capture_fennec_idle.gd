extends SceneTree
const Adapter = preload("res://game/fennec_idle_adapter.gd")
var failures: Array[String] = []
var records: Array = []
var output := ""

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func _run() -> void:
	output = OS.get_environment("FENNEC_OUTPUT")
	if output.is_empty() or not OS.get_user_data_dir().contains("FennecIdle-"):
		printerr("Private UUID userdata and FENNEC_OUTPUT required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var native := not DisplayServer.get_name() == "headless"
	for width in [960, 1280]:
		root.size = Vector2i(width, width * 9 / 16)
		root.content_scale_size = root.size
		var scene = load("res://tests/fennec_idle_preview.tscn").instantiate()
		scene.profile_save_prefix = "user://sample-profile"
		scene.growth_save_prefix = "user://sample-growth"
		root.add_child(scene)
		current_scene = scene
		await process_frame
		scene.set_process(false)
		scene.set_physics_process(false)
		scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
		scene.teleport(Vector2(660, 1120))
		scene._process(0.0)
		var target: Vector3 = scene.terrain.world_point(scene.player.position, 35.0)
		scene.camera.position = target + scene.camera_offset
		scene.camera.look_at(target, Vector3.UP)
		var body: Sprite3D = scene.actors[scene.player].get_node("Body")
		var original_radius: float = scene.player.collision_radius
		var views := ["front", "side", "back", "front-body-height"] if width == 960 else ["front", "side", "back"]
		for view in views:
			Adapter.set_direction(body, "front" if view == "front-body-height" else view)
			# Manually inspected forelock crown y290 in the 1536px generated front.
			# Alpha-scissor used y49..1466: crown-to-foot1176, total1417.
			# Retain ear-inclusive reference and offer ONE crown-height comparison.
			body.pixel_size = Adapter.PIXEL_SIZE * (1417.0 / 1176.0 if view == "front-body-height" else 1.0)
			check(body.texture.get_size() == Vector2(384, 448), "same canvas " + view)
			check(body.offset == Vector2(0, 192), "same foot pivot " + view)
			check(body.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "billboard " + view)
			check(body.alpha_cut == SpriteBase3D.ALPHA_CUT_DISCARD, "depth cutout " + view)
			check(scene.player.collision_radius == original_radius, "collision unchanged " + view)
			var right: Vector3 = scene.camera.global_basis.x
			check(Adapter.direction(Vector2(right.x, right.z), scene.camera) == "side", "camera right maps side")
			var toward: Vector3 = scene.camera.global_basis.z
			check(Adapter.direction(Vector2(toward.x, toward.z), scene.camera) == "front", "camera toward maps front")
			check(Adapter.direction(-Vector2(toward.x, toward.z), scene.camera) == "back", "camera away maps back")
			var world_height := body.pixel_size * 384.0
			var projected_height: float = world_height / scene.camera.size * root.size.y
			var label := "%s-%d" % [view, width]
			if native:
				# Bounded frame settling. Never await frame_post_draw indefinitely.
				for frame in 8: await process_frame
				RenderingServer.force_draw(false)
				var image := root.get_texture().get_image()
				check(image != null and image.get_size() == root.size, "actual PNG size " + label)
				if image != null and image.get_size() == root.size:
					check(image.save_png(output.path_join(label + ".png")) == OK, "save " + label)
			records.append({"view":view, "width":width, "height":root.size.y, "camera_size":scene.camera.size, "authored_height_world":world_height, "expected_sprite_height_px":projected_height, "front_crown_to_foot_px":projected_height * 1176.0 / 1417.0 if view.begins_with("front") else -1, "crown_measurement":"manual forelock landmark; prototype approximation", "body_ground":scene.camera.unproject_position(body.get_parent().global_position), "native":native})
		scene.queue_free()
		current_scene = null
		await process_frame
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"records":records,"failures":failures,"native":native}, "  "))
	print("Fennec idle trial failures=", failures.size(), "; native=", native)
	quit(0 if failures.is_empty() else 1)
