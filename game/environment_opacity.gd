extends RefCounted
## Restore authored environmental materials. No sight test, fade, cut or outline.
## Field transitions still own the parent root's visibility.

static func restore(root: Node) -> void:
	if not is_instance_valid(root): return
	if root is MeshInstance3D:
		if root.has_meta("solid_material"):
			root.material_override = root.get_meta("solid_material")
		root.visible = true
		if root.has_meta("fade_state"): root.remove_meta("fade_state")
	for child in root.get_children(): restore(child)


static func restore_canal(arena: Node) -> void:
	for record in arena.building_visuals + arena.landmark_visuals:
		restore(record.root)
		if record.root.has_meta("fade_state"): record.root.remove_meta("fade_state")
