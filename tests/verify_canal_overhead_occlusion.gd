extends SceneTree
## Whole buildings, gate and sluice roofs retain their original opaque meshes.
const Candidate = preload("res://game/canal_overhead_occlusion.gd")
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _run() -> void:
	var scene = load("res://game/canal_city_trial.tscn").instantiate()
	check(not scene.overhead_occlusion_enabled, "roof removal disabled by default")
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
	var snapshot := {}
	for record in scene.building_visuals + scene.landmark_visuals:
		for mesh in record.root.get_children():
			if mesh is MeshInstance3D: snapshot[mesh] = [mesh.material_override, mesh.mesh, mesh.cast_shadow, mesh.visible]
	var barriers: Array = scene.terrain.barriers().duplicate()
	var removed = Candidate.new()
	for size in [Vector2i(960, 540), Vector2i(1280, 720)]:
		root.size = size
		for point in [Vector2(6200, 4000), Vector2(6770, 4045), Vector2(6600, 750), Vector2(6650, 1500), Vector2(2480, 1690)]:
			scene.teleport(point)
			for flag in [false, true]:
				scene.overhead_occlusion_enabled = flag
				removed.install(scene)
				removed.update(scene, 0.6)
				for record in scene.building_visuals + scene.landmark_visuals:
					scene._set_architecture_fade(record.root, true)
				scene._process(0.1)
				check(removed.entries.is_empty() and scene.overhead_occlusion.entries.is_empty(), "no hidden overhead groups, even with legacy toggle")
				for mesh in snapshot:
					check([mesh.material_override, mesh.mesh, mesh.cast_shadow, mesh.visible] == snapshot[mesh] and mesh.material_override.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "original complete opaque building member retained")
	check(scene.terrain.barriers() == barriers, "roof policy never changes collision")
	for pair in [[Vector2(6200, 4000), Vector2(6770, 4045)], [Vector2(6600, 750), Vector2(6650, 1500)]]:
		check(scene.navigation.find_path(pair[0], pair[1]).size() > 1 and scene.navigation.find_path(pair[1], pair[0]).size() > 1, "gate and sluice round trips remain open")
	scene.queue_free()
	await process_frame
	await process_frame
	print("Canal original opaque assets: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
