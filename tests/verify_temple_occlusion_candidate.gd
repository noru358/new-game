extends SceneTree
## User requires original opaque assets. Old removal APIs cannot re-enable cuts.
const Candidate = preload("res://game/temple_occlusion_candidate.gd")
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _run() -> void:
	var scene = load("res://game/hybrid_region.tscn").instantiate()
	check(not scene.temple_occlusion_candidate_enabled, "cutaway disabled by default")
	scene.profile_save_prefix = "user://opaque_temple_verify_profile"
	scene.growth_save_prefix = "user://opaque_temple_verify_unlocks"
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
	var snapshot := {}
	for group in [scene.temple_environment_root, scene.temple_sanctuary_root, scene.temple_opening_root]:
		for mesh in group.get_children():
			snapshot[mesh] = [mesh.material_override, mesh.mesh, mesh.cast_shadow, mesh.visible]
	var barriers: Array = scene.terrain.barriers().duplicate()
	var removed = Candidate.new()
	for size in [Vector2i(960, 540), Vector2i(1280, 720)]:
		root.size = size
		for point in [Vector2(416, 1550), Vector2(3980, 850), Vector2(3940, 765), Vector2(4770, 960), Vector2(4320, 1150)]:
			scene.teleport(point)
			for flag in [false, true]:
				scene.temple_occlusion_candidate_enabled = flag
				removed.install(scene)
				removed.update(scene, 0.1)
				scene._update_temple_environment_visibility()
				scene.TempleSanctuaryScript.update_visibility(scene.temple_sanctuary_root, scene)
				scene.TempleOpeningScript.update_visibility(scene.temple_opening_root, scene)
				scene._process(0.1)
				check(removed.members.is_empty() and scene.temple_occlusion_candidate.members.is_empty(), "no removed upper members, even with legacy toggle")
				for mesh in snapshot:
					check([mesh.material_override, mesh.mesh, mesh.cast_shadow, mesh.visible] == snapshot[mesh] and mesh.material_override is StandardMaterial3D and mesh.material_override.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "exact original mesh/material/shadow/visibility remain: " + mesh.name)
	check(scene.terrain.barriers() == barriers, "asset opacity never changes collision")
	scene.temple_section.enter_garden()
	scene._process(0.1)
	check(not scene.temple_environment_root.visible and not scene.temple_sanctuary_root.visible, "separate field transition remains distinct from camera occlusion")
	scene.temple_section.leave_garden()
	scene._process(0.1)
	check(scene.temple_environment_root.visible and scene.temple_sanctuary_root.visible, "main-field return restores environmental roots")
	scene.queue_free()
	await process_frame
	await process_frame
	print("Temple original opaque assets: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
