extends SceneTree
## Static native-render samples of original full assets at former occlusion cases.
var output := ""
var records: Array = []
var failures: Array = []
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func _run() -> void:
	output = OS.get_environment("OPAQUE_OUTPUT")
	if output.is_empty() or not OS.get_user_data_dir().contains("LoopConquestMapTrials/"):
		printerr("FAIL: explicit output and private project required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	Engine.time_scale = 1.0
	Engine.max_fps = 60
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for kind in ["temple", "canal"]:
		var scene = load("res://game/hybrid_region.tscn" if kind == "temple" else "res://game/canal_city_trial.tscn").instantiate()
		if kind == "temple":
			scene.profile_save_prefix = "user://opaque_render_profile"
			scene.growth_save_prefix = "user://opaque_render_unlocks"
		root.add_child(scene)
		current_scene = scene
		await physics_frame
		for connection in root.focus_exited.get_connections(): root.focus_exited.disconnect(connection.callable)
		scene._set_paused(false)
		scene.set_physics_process(false)
		scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
		var meshes: Array = []
		if kind == "temple":
			for group in [scene.temple_environment_root, scene.temple_sanctuary_root, scene.temple_opening_root]:
				for mesh in group.get_children(): meshes.append(mesh)
		else:
			for record in scene.building_visuals + scene.landmark_visuals:
				for mesh in record.root.get_children():
					if mesh is MeshInstance3D: meshes.append(mesh)
		var snapshot := {}
		for mesh in meshes: snapshot[mesh] = [mesh.material_override, mesh.mesh, mesh.cast_shadow, mesh.visible]
		var samples := [[Vector2(3940, 765), "threshold"], [Vector2(4770, 960), "sanctuary"]] if kind == "temple" else [[Vector2(6200, 4000), "gate"], [Vector2(6600, 750), "sluice"]]
		for size in [Vector2i(960, 540), Vector2i(1280, 720)]:
			root.size = size
			for sample in samples:
				scene.teleport(sample[0])
				for i in 40: await process_frame
				await RenderingServer.frame_post_draw
				var frame := root.get_texture().get_image()
				check(frame != null and not frame.is_empty(), "native render present")
				var filename := "%s-%s-%s.png" % [kind, sample[1], size.x]
				if frame != null and not frame.is_empty(): check(frame.save_png(output.path_join(filename)) == OK, "native render saved")
				for mesh in snapshot:
					check([mesh.material_override, mesh.mesh, mesh.cast_shadow, mesh.visible] == snapshot[mesh] and mesh.material_override is StandardMaterial3D and mesh.material_override.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "original complete opaque mesh remains: " + mesh.name)
				records.append({"file": filename, "kind": kind, "point": [sample[0].x, sample[0].y], "resolution": [size.x, size.y], "original_opaque_meshes": meshes.size()})
		scene.queue_free()
		current_scene = null
		await process_frame
		await process_frame
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine": Engine.get_version_info().string, "records": records, "failures": failures, "complete": failures.is_empty(), "fixture": "Static native render at former cut/fade viewpoints. Scene and actor physics disabled; 960/1280; exact original mesh/material/shadow/visibility snapshots retained. Separate automated tests cover collision and walking. No visibility/readability or human fun acceptance."}, "  ") + "\n")
	file.close()
	print("Opaque native render: complete=", failures.is_empty())
	quit(0 if failures.is_empty() else 1)
