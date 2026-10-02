extends RefCounted
## Former cutaway API, retained for callers. Sight-based removal is disabled.
const BASE_HEIGHTS := {"RuinedSanctuaryThreshold": 52.5, "SteppedSanctuary": 55.3, "BrokenRearGallery": 25.3, "CourtMasonryRemnant": 65.0}
var members: Array[Dictionary] = []
var transition_count := 0

func install(_arena: Node3D) -> void: pass
func update(_arena: Node3D, _delta: float) -> void: restore()
func restore() -> void:
	for member in members:
		if not is_instance_valid(member.mesh): continue
		member.mesh.material_override = member.original
		member.mesh.cast_shadow = member.shadow
	members.clear()
