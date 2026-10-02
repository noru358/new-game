extends RefCounted
## Reuse the existing sanctuary's authored stonework behind the new court.
const Sanctuary = preload("res://game/temple_sanctuary_environment.gd")
const OFFSET := Vector3(-25.2, 0.0, -12.1)
const FOOTPRINT := Rect2(2572, 0, 456, 240)
static func build(_arena: Node3D) -> Node3D:
	var root := Node3D.new()
	var builder = Sanctuary.new()
	for surface in [builder._stone, builder._paving, builder._growth, builder._threshold]:
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder._shrine()
	builder._finish_batch(root, builder._stone, "SteppedSanctuary", 0, true)
	builder._finish_batch(root, builder._growth, "AttachedMoss", 2, false)
	root.name = "CircuitSanctuaryBackdrop"
	root.position = OFFSET
	root.set_meta("visual_only", true)
	root.set_meta("region_hierarchy", ["동남아", "사원 동선 후보", "성소", "기존 석조 재사용"])
	root.set_meta("candidate_footprint", FOOTPRINT)
	return root
