extends RefCounted
## One jungle gate approach sample. Visual geometry only; never terrain data.
## Broad worn planes retain worked masonry versus eroded rock, without noise.
const SCALE := 0.01
const MAX_TREAD_LIFT := 2.0

static func enabled() -> bool:
	return not OS.get_cmdline_user_args().has("--worn-stone-baseline")

static func post_mesh(size: Vector3, seed: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	# All profiles stay inside the former box, including its bottom and peak.
	var rings: Array = []
	var heights := [-0.5, -0.33, -0.27, 0.12, 0.18, 0.42, 0.5]
	var widths := [1.0, 1.0, 0.88, 0.88, 0.96, 0.96, 0.82]
	for i in heights.size():
		var ring: Array[Vector3] = []
		var corners := _outline(Vector2(size.x, size.z) * widths[i], 0.13 + 0.02 * float(seed % 3))
		for p in corners: ring.append(Vector3(p.x, size.y * heights[i], p.y))
		rings.append(ring)
	_join_rings(st, rings)
	st.generate_normals()
	return st.commit()

static func rock_mesh(size: Vector3, seed: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	# Three deliberate profiles: a heavy foot, uneven shoulder and worn crown.
	# Each coordinate is bounded by the original box. No spherical plastic rock.
	var profiles := [
		[Vector2(-0.32,-0.5), Vector2(0.29,-0.5), Vector2(0.5,-0.23), Vector2(0.5,0.24), Vector2(0.25,0.5), Vector2(-0.30,0.5), Vector2(-0.5,0.22), Vector2(-0.5,-0.21)],
		[Vector2(-0.29,-0.43), Vector2(0.22,-0.48), Vector2(0.46,-0.18), Vector2(0.40,0.27), Vector2(0.19,0.42), Vector2(-0.25,0.46), Vector2(-0.46,0.13), Vector2(-0.43,-0.24)],
		[Vector2(-0.20,-0.28), Vector2(0.18,-0.33), Vector2(0.29,-0.12), Vector2(0.26,0.18), Vector2(0.13,0.30), Vector2(-0.17,0.29), Vector2(-0.30,0.09), Vector2(-0.27,-0.17)],
	]
	var rings: Array = []
	for level in 3:
		var ring: Array[Vector3] = []
		for i in 8:
			var p: Vector2 = profiles[level][(i + seed % 2 * 4) % 8]
			if seed % 2 == 1: p = -p
			# Size/depth variation reduces only; the old outline remains the bound.
			p.x *= 1.0 - 0.08 * float(seed % 3)
			p.y *= 1.0 - 0.06 * float((seed + 1) % 3)
			var y := -0.5 if level == 0 else 0.16 + 0.045 * float((i + seed) % 3) if level == 1 else 0.50 - 0.025 * float((i + seed) % 3)
			ring.append(Vector3(p.x * size.x, y * size.y, p.y * size.z))
		rings.append(ring)
	_join_rings(st, rings)
	st.generate_normals()
	return st.commit()

static func _outline(size: Vector2, cut: float) -> Array[Vector2]:
	var half := size * 0.5
	var c := minf(size.x, size.y) * cut
	return [Vector2(-half.x+c,-half.y), Vector2(half.x-c,-half.y), Vector2(half.x,-half.y+c), Vector2(half.x,half.y-c), Vector2(half.x-c,half.y), Vector2(-half.x+c,half.y), Vector2(-half.x,half.y-c), Vector2(-half.x,-half.y+c)]

static func _join_rings(st: SurfaceTool, rings: Array) -> void:
	for level in rings.size() - 1:
		for i in 8:
			var j := (i + 1) % 8
			_quad(st, rings[level][i], rings[level+1][i], rings[level+1][j], rings[level][j])
	for i in range(1, 7):
		_tri(st, rings[0][0], rings[0][i], rings[0][i+1])
		_tri(st, rings[-1][0], rings[-1][i+1], rings[-1][i])

static func append_treads(st: SurfaceTool, ramp: Dictionary, elevation: Callable, color: Color) -> void:
	var area: Rect2 = ramp.area
	var width := area.size.x / 12.0
	for step in 12:
		# Ordered crosswise courses remain legible as a built stair route. Ends
		# erode by a few broad cuts; no checkerboard or raised false foothold.
		var north := 14.0 + float([0, 7, 3, 11][step % 4])
		var south := 14.0 + float([8, 0, 6, 3][step % 4])
		var rect := Rect2(area.position.x + step * width + 2.0, area.position.y + north, width - 4.0, area.size.y - north - south)
		var border := _outline(rect.size, 0.14 + float(step % 3) * 0.025)
		var center := rect.get_center()
		var inner: Array[Vector3] = []
		var outer: Array[Vector3] = []
		for p in border:
			var q := center + p
			var r := center + Vector2(p.x * 0.88, p.y * 0.986)
			outer.append(Vector3(q.x, elevation.call(q) + 0.35, q.y) * SCALE)
			inner.append(Vector3(r.x, elevation.call(r) + MAX_TREAD_LIFT, r.y) * SCALE)
		st.set_color(color.lightened(0.035 if step % 3 == 0 else 0.0))
		for i in range(1, 7): _tri(st, inner[0], inner[i+1], inner[i])
		st.set_color(color.darkened(0.12))
		for i in 8:
			var j := (i+1) % 8
			_quad(st, outer[i], inner[i], inner[j], outer[j])

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_tri(st, a, b, c)
	_tri(st, a, c, d)
