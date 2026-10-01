extends SceneTree
## Focused opt-in comparison contracts, not a human preference or full-suite pass.
const Candidate = preload("res://game/temple_occlusion_candidate.gd")
var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _advance(candidate, scene, seconds: float) -> void:
	for i in ceili(seconds * 60): candidate.update(scene, 1.0 / 60)

func _member(candidate, label: String) -> Dictionary:
	for member in candidate.members:
		if String(member.mesh.name) == label: return member
	return {}

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene = load("res://game/hybrid_region.tscn").instantiate()
	# Exercise this helper in isolation; native mount coverage follows below.
	if scene.get("temple_occlusion_candidate") != null:
		scene.temple_occlusion_candidate_enabled = false
	scene.profile_save_prefix = "user://verify_occlusion_candidate_profile"
	scene.growth_save_prefix = "user://verify_occlusion_candidate_unlocks"
	root.add_child(scene)
	current_scene = scene
	for i in 5: await process_frame
	scene.set_process(false)
	scene.set_physics_process(false)
	scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
	for actor in scene.actors.keys():
		if actor != scene.player: scene.temple_section._remove_actor(actor)
	var barriers: Array = scene.terrain.barriers().duplicate(true)
	var camera_size: float = scene.camera.size
	var body: Sprite3D = scene.actors[scene.player].get_node("Body")
	var body_depth := body.no_depth_test
	var body_priority := body.render_priority
	var candidate := Candidate.new()
	candidate.install(scene)
	_check(candidate.members.size() == 4, "only four named temple members enter the opt-in comparison")
	for member in candidate.members:
		_check(member.original is StandardMaterial3D and member.original.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "original solid material remains available: " + String(member.mesh.name))
		_check(member.base > 0 and member.base < member.full, "authored lower footing is retained: " + String(member.mesh.name))
	var threshold := _member(candidate, "RuinedSanctuaryThreshold")
	var remnant := _member(candidate, "CourtMasonryRemnant")
	for size in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = size
		await process_frame
		scene.teleport(Vector2(3940, 765))
		candidate.update(scene, 1.0 / 120)
		_check(threshold.cut and is_equal_approx(threshold.height, threshold.base), "actual threshold torso ray clears upper stone at " + str(size))
		_check(remnant.height == remnant.full, "distant unrelated court remnant stays complete")
		scene.teleport(Vector2(3900, 1120))
		_advance(candidate, scene, 0.25)
		_check(threshold.cut, "brief direction reversal does not restore the upper threshold")
		scene.teleport(Vector2(3940, 765))
		var transitions_before: int = threshold.transitions
		_advance(candidate, scene, 0.15)
		_check(threshold.transitions == transitions_before, "return during grace period does not retrigger a visual change")
		scene.teleport(Vector2(3900, 1120))
		_advance(candidate, scene, 0.85)
		_check(not threshold.cut and is_equal_approx(threshold.height, threshold.full), "sustained departure restores full threshold silhouette")
		scene.teleport(Vector2(4770, 960))
		_advance(candidate, scene, 0.15)
		_check(remnant.cut and is_equal_approx(remnant.height, remnant.base), "court obstruction preserves lower opaque courses and clears upper part")
		_check(remnant.mesh.material_override is ShaderMaterial and not Candidate.CUT_SHADER.contains("ALPHA"), "cut material never uses translucent ghost blending")
		scene.teleport(Vector2(4320, 1150))
		_advance(candidate, scene, 0.85)
		_check(not remnant.cut, "court remnant reliably restores after departure")
		scene.teleport(Vector2(3980, 850))
		scene._update_temple_environment_visibility()
		_check(threshold.mesh.material_override.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "legacy broad rectangle fades even without face/torso mesh coverage")
		candidate.update(scene, 1.0 / 60)
		_check(not threshold.cut, "exact camera ray avoids the legacy near-edge false positive")
	# An enemy must still receive protection when the player's own view is clear.
	var enemy = scene._spawn_enemy_at(Vector2(3940, 765), TrainingEnemy.Role.BEAST, 100.0)
	enemy.set_physics_process(false)
	scene.teleport(Vector2(3900, 1120))
	_advance(candidate, scene, 0.15)
	_check(threshold.cut, "visible enemy behind exact threshold geometry is protected")
	scene.actors[enemy].hide()
	_advance(candidate, scene, 0.85)
	_check(not threshold.cut, "hidden actor cannot hold a structure cut")
	scene.temple_section._remove_actor(enemy)
	# Warning-only fixture: real existing boss ring, no changed dimensions or depth.
	scene._spawn_now(scene.temple_section.BOSS_POINT, TrainingEnemy.Role.BEAST, true)
	scene.boss.set_physics_process(false)
	scene.boss.encounter_active = true
	scene.teleport(Vector2(4350, 1180))
	scene.boss.ring_warning = 0.55
	scene._draw_boss_warning()
	var warning_mesh: ImmediateMesh = scene.boss_warning_mesh
	_advance(candidate, scene, 0.15)
	_check(remnant.cut, "actual boss outer warning can clear the upper remnant without actor overlap")
	_check(scene.boss_warning_mesh == warning_mesh and warning_mesh.get_surface_count() > 0, "separate boss ring geometry remains drawn with the upper remnant removed")
	scene.boss.ring_warning = 0
	_advance(candidate, scene, 0.85)
	_check(not remnant.cut, "warning-only upper removal restores after warning ends")
	scene.boss.queue_free()
	await process_frame
	candidate.update(scene, 0.02)
	_check(not is_instance_valid(scene.boss), "freed boss reference is safely handled")
	var expired := TrainingEnemy.new()
	scene.actors[expired] = null
	expired.free()
	candidate.update(scene, 0.02)
	scene.actors.erase(expired)
	_check(true, "freed actor reference is skipped before type access")
	scene.teleport(Vector2(3940, 765))
	_advance(candidate, scene, 0.15)
	scene.overview = true
	candidate.update(scene, 0.02)
	_check(not threshold.cut and threshold.mesh.material_override == threshold.original, "overview immediately restores original solid members")
	scene.overview = false
	_advance(candidate, scene, 0.15)
	scene.temple_section.in_garden = true
	candidate.update(scene, 0.02)
	_check(not threshold.cut and threshold.height == threshold.full, "garden entry clears all pending cut state")
	scene.temple_section.in_garden = false
	_advance(candidate, scene, 0.15)
	scene.player.health = 0
	_advance(candidate, scene, 0.85)
	_check(not threshold.cut, "dead player cannot keep upper masonry removed")
	_check(scene.terrain.barriers() == barriers and scene.camera.size == camera_size, "candidate preserves all navigation barriers and camera size")
	_check(body.no_depth_test == body_depth and body.render_priority == body_priority, "existing single-sprite boss visibility ownership remains untouched")
	var original_members: Array = candidate.members.duplicate()
	candidate.restore()
	for member in original_members:
		_check(member.mesh.material_override == member.original, "disabling candidate restores exact original material: " + String(member.mesh.name))
	scene.queue_free()
	await process_frame
	await _verify_native_mount()
	print("Temple occlusion candidate: ", checks, " checks; ", failures, " failures")
	quit(1 if failures else 0)


func _verify_native_mount() -> void:
	var scene = load("res://game/hybrid_region.tscn").instantiate()
	if scene.get("temple_occlusion_candidate") == null:
		scene.free()
		return
	_check(scene.temple_occlusion_candidate_enabled, "production temple enables the tested cutaway by default")
	scene.profile_save_prefix = "user://verify_occlusion_native_profile"
	scene.growth_save_prefix = "user://verify_occlusion_native_unlocks"
	root.add_child(scene)
	current_scene = scene
	for i in 3: await process_frame
	scene.set_process(false)
	scene.set_physics_process(false)
	scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
	scene.teleport(Vector2(3940, 765))
	scene._process(1.0 / 60)
	var member := _member(scene.temple_occlusion_candidate, "RuinedSanctuaryThreshold")
	_check(member.cut and member.mesh.material_override is ShaderMaterial, "native frame clears the actual upper obstruction")
	scene.temple_occlusion_candidate_enabled = false
	scene._process(1.0 / 60)
	_check(member.mesh.material_override is StandardMaterial3D and member.mesh.material_override.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "disabling first restores source material then runs the exact legacy fade")
	_check(scene.temple_occlusion_candidate.members.is_empty(), "legacy comparison releases candidate state")
	scene.temple_occlusion_candidate_enabled = true
	scene._process(1.0 / 60)
	var returned := _member(scene.temple_occlusion_candidate, "RuinedSanctuaryThreshold")
	_check(returned.cut and returned.original is StandardMaterial3D, "re-enabling never captures the shader as its original material")
	scene.queue_free()
	await process_frame
	var jungle = load("res://game/jungle_pass.tscn").instantiate()
	jungle.profile_save_prefix = "user://verify_occlusion_native_jungle_profile"
	jungle.growth_save_prefix = "user://verify_occlusion_native_jungle_unlocks"
	root.add_child(jungle)
	current_scene = jungle
	for i in 3: await process_frame
	_check(jungle.temple_occlusion_candidate.members.is_empty(), "jungle does not mount temple cut materials")
	jungle.queue_free()
	await process_frame
