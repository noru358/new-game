extends RefCounted
## Reversible study: Southeast Asia -> reclaimed temple -> northern sanctuary.
## One monumental shrine, one low apron/entrance; court and groves stay human-scale.
const FACTOR := 1.7
const SOURCE_PIVOT := Vector3(53.2, 0.0, 14.5)
const NORTH_SHIFT := Vector3(0.0, 0.0, -2.0)
const FOOTPRINT := Rect2(2572, 0, 456, 240)
const NORTH_FOOTPRINT := Rect2(2412.4, 0.0, 775.2, 40.0)
const HEIGHT := 655.8
static func transformed(source: Vector3) -> Vector3:
	var point := SOURCE_PIVOT + (source - SOURCE_PIVOT) * FACTOR + NORTH_SHIFT
	point.y = source.y * 0.4 if source.y <= 2.2 else 0.88 + (source.y - 2.2) * FACTOR
	return point
static func apply(root: Node3D) -> void:
	for label in ["SteppedSanctuary", "AttachedMoss"]:
		var mesh := root.get_node(label) as MeshInstance3D
		var arrays: Array = mesh.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for triangle in range(0, count, 3):
			var points: Array[Vector3] = []
			var vertex_ids: Array[int] = []
			for offset in 3:
				var index := indices[triangle + offset] if not indices.is_empty() else triangle + offset
				vertex_ids.append(index)
				points.append(transformed(vertices[index]))
			var normal := (points[1] - points[0]).cross(points[2] - points[0]).normalized()
			for offset in 3:
				surface.set_normal(normal)
				surface.set_color(colors[vertex_ids[offset]])
				surface.add_vertex(points[offset])
		mesh.mesh = surface.commit()
	var apron := Node3D.new()
	apron.name = "SanctuaryEntranceApron"
	apron.position = Vector3(25.2, 0.0, 12.1)
	root.add_child(apron)
	var builder = preload("res://game/temple_environment_kit.gd").new()
	builder._stone.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stone := Color("a6ae92")
	builder._block(builder._stone, FOOTPRINT, 0.0, 55.0, stone.darkened(0.06), 4, 4)
	# Solid face is flush with the existing180-high court cap, not behind it.
	# 0.06map-unit offset avoids coplanar flicker; never a traversable door.
	for area in [Rect2(2730,200,25,40), Rect2(2845,200,25,40)]:
		builder._block(builder._stone, area, 55, 218, stone, 20, 2.5)
	builder._block(builder._stone, Rect2(2726,192,148,48), 218, 240, stone.lightened(0.12), 30, 3)
	builder._quad(builder._stone, Vector3(2755,55,240.06), Vector3(2845,55,240.06), Vector3(2845,218,240.06), Vector3(2755,218,240.06), Color("405e59"))
	builder._finish_batch(apron, builder._stone, "LowApronAndEntrance", 0, true)
