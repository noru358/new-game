extends RefCounted
## Former roof-removal API. Complete opaque landmark assets now remain visible.
var entries: Array[Dictionary] = []
func install(_arena: Node3D) -> void: pass
func owns(_root: Node3D) -> bool: return false
func update(_arena: Node3D, _delta: float) -> void: restore()
func restore() -> void:
	for entry in entries:
		for part in entry.parts:
			if not is_instance_valid(part.mesh): continue
			part.mesh.show()
			part.mesh.material_override = part.solid
			part.mesh.cast_shadow = part.shadow
	entries.clear()
