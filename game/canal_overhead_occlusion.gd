extends RefCounted
## Bounded canal continuation: two roof/lintel groups only. Their piers are
## separate authored meshes and remain opaque. Houses keep their existing path.
const CLEAR_HOLD := 0.35
const RESTORE_SECONDS := 0.18
const LABELS := ["TiledWardGate", "SluicePavilion"]
var entries: Array[Dictionary] = []
var _installed := false

func install(arena: Node3D) -> void:
	if _installed: return
	_installed = true
	for item in arena.landmark_visuals:
		if not LABELS.has(String(item.root.name)): continue
		var parts: Array[Dictionary] = []
		for mesh in item.root.get_children():
			if not mesh is MeshInstance3D: continue
			var solid: StandardMaterial3D = mesh.get_meta("solid_material", mesh.material_override)
			var returning := solid.duplicate() as StandardMaterial3D
			returning.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			parts.append({"mesh": mesh, "solid": solid, "returning": returning,
				"triangles": mesh.mesh.generate_triangle_mesh(), "shadow": mesh.cast_shadow})
		entries.append({"root": item.root, "parts": parts, "cleared": false,
			"clear_time": 0.0, "alpha": 1.0, "transitions": 0})

func owns(root: Node3D) -> bool:
	for entry in entries:
		if entry.root == root: return true
	return false

func update(arena: Node3D, delta: float) -> void:
	if not _installed: install(arena)
	var targets: Array[Vector3] = []
	var inactive: bool = not is_instance_valid(arena.player) or arena.overview
	if not inactive:
		for actor in arena.actors:
			if not is_instance_valid(actor): continue
			if actor != arena.player and (not arena.combat_enabled or not actor is TrainingEnemy): continue
			if actor.health <= 0: continue
			if not is_instance_valid(arena.actors[actor]) or not arena.actors[actor].is_visible_in_tree(): continue
			if actor.position.distance_to(arena.player.position) > 1050: continue
			for height in [55.0, 85.0]:
				var point: Vector3 = arena.terrain.world_point(actor.position, height)
				if arena.get_viewport().get_visible_rect().has_point(arena.camera.unproject_position(point)): targets.append(point)
	for entry in entries:
		if not is_instance_valid(entry.root): continue
		if inactive:
			_reset(entry)
			continue
		var obscures := _obscures(entry, arena, targets, 10.0 if entry.cleared else 0.0)
		if obscures:
			entry.clear_time = 0.0
			_set_cleared(entry, true)
		else:
			entry.clear_time += maxf(delta, 0.0)
			if entry.clear_time >= CLEAR_HOLD: _set_cleared(entry, false)
		entry.alpha = 0.0 if entry.cleared else move_toward(float(entry.alpha), 1.0, maxf(delta, 0.0) / RESTORE_SECONDS)
		for part in entry.parts:
			part.mesh.visible = not entry.cleared
			if entry.alpha >= 1.0 or entry.cleared:
				part.mesh.material_override = part.solid
			else:
				part.returning.albedo_color.a = entry.alpha
				part.mesh.material_override = part.returning
			part.mesh.cast_shadow = part.shadow if entry.alpha >= 1.0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _obscures(entry: Dictionary, arena: Node3D, targets: Array[Vector3], margin: float) -> bool:
	var toward: Vector3 = arena.camera.global_basis.z * 40.0
	var side: Vector3 = arena.camera.global_basis.x * margin * 0.01
	var offsets: Array[Vector3] = [Vector3.ZERO]
	if margin > 0: offsets.append_array([side, -side, Vector3.UP * margin * 0.01])
	for target in targets:
		for offset in offsets:
			for part in entry.parts:
				if not is_instance_valid(part.mesh): continue
				if not part.triangles.intersect_segment(part.mesh.to_local(target + offset), part.mesh.to_local(target + offset + toward)).is_empty(): return true
	return false

func _set_cleared(entry: Dictionary, cleared: bool) -> void:
	if entry.cleared != cleared:
		entry.cleared = cleared
		entry.transitions += 1

func _reset(entry: Dictionary) -> void:
	_set_cleared(entry, false)
	entry.clear_time = 0.0
	entry.alpha = 1.0
	for part in entry.parts:
		if not is_instance_valid(part.mesh): continue
		part.mesh.show()
		part.mesh.material_override = part.solid
		part.mesh.cast_shadow = part.shadow

func restore() -> void:
	for entry in entries:
		_reset(entry)
		if is_instance_valid(entry.root) and entry.root.has_meta("fade_state"):
			entry.root.remove_meta("fade_state")
	entries.clear()
	_installed = false
