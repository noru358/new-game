extends SceneTree

const PROFILE := "user://verify_surface_overlap_profile"
const UNLOCKS := "user://verify_surface_overlap_unlocks"
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for path in ["res://game/jungle_pass.tscn", "res://game/hybrid_region.tscn"]:
		var scene: Node3D = load(path).instantiate()
		scene.profile_save_prefix = PROFILE
		scene.growth_save_prefix = UNLOCKS
		root.add_child(scene)
		await process_frame
		var faces: Array = scene.resolved_vertical_faces
		var lips: Array = scene.resolved_lips
		_check(not faces.is_empty() and not lips.is_empty(), "%s builds cliff faces and rims" % path)
		for i in faces.size():
			for j in range(i + 1, faces.size()):
				var a: Dictionary = faces[i]
				var b: Dictionary = faces[j]
				if a.axis != b.axis or not is_equal_approx(float(a.fixed), float(b.fixed)): continue
				_check(minf(a.end, b.end) - maxf(a.start, b.start) <= 0.001, "%s has one visible face per vertical wall plane" % path)
		for i in lips.size():
			for j in range(i + 1, lips.size()):
				var a: Dictionary = lips[i]
				var b: Dictionary = lips[j]
				if not is_equal_approx(float(a.height), float(b.height)): continue
				var overlap: Rect2 = a.area.intersection(b.area)
				_check(overlap.size.x * overlap.size.y <= 0.001, "%s has one visible rim surface at each height" % path)
		scene.queue_free()
		await process_frame
	for prefix in [PROFILE, UNLOCKS]:
		for suffix in ["_a.json", "_b.json"]:
			var save_path := ProjectSettings.globalize_path(prefix + suffix)
			if FileAccess.file_exists(save_path): DirAccess.remove_absolute(save_path)
	if failures == 0: print("Surface overlap verification passed: cliff faces and rims in both regions")
	quit(1 if failures else 0)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)
