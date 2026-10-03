extends RefCounted
## Original temple carving study; +Z faces south. Caller owns placement/scale.
## Two opaque flat-shaded batches; no gameplay nodes or per-frame processing.
## Measured f37e202 local envelope: (-1.059208,0,-1.241853)..(1.129927,3.8,1.292944).
const STONE := Color("929783")
const SHADOW := Color("596458")
static func build(arena: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "MonumentalWetlandFace"
	var stone := SurfaceTool.new()
	var moss := SurfaceTool.new()
	stone.begin(Mesh.PRIMITIVE_TRIANGLES)
	moss.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Squared submerged footing, sloping jaw and broad cheek mass.
	_loft(stone,[Vector4(0,0.88,0.65,-0.77),Vector4(0.27,0.87,0.69,-0.75),
		Vector4(0.45,0.74,0.78,-0.70),Vector4(0.82,0.83,0.86,-0.71),
		Vector4(1.46,0.97,0.91,-0.73),Vector4(2.23,0.96,0.91,-0.76),
		Vector4(2.83,0.88,0.84,-0.78),Vector4(3.14,0.87,0.81,-0.77)],STONE)
	for side in [-1.0,1.0]:
		_relief(stone,_mirror([Vector2(0.20,1.59),Vector2(0.65,1.43),Vector2(0.86,1.83),
			Vector2(0.78,2.18),Vector2(0.31,2.13)],side),0.87,0.985,STONE)
		# Downcast eye seam under a heavy lid, without eyeballs or emission.
		_relief(stone,_mirror([Vector2(0.16,2.31),Vector2(0.49,2.255),Vector2(0.79,2.32),
			Vector2(0.75,2.365),Vector2(0.45,2.32),Vector2(0.17,2.37)],side),0.905,1.015,SHADOW)
		_relief(stone,_mirror([Vector2(0.13,2.39),Vector2(0.45,2.33),Vector2(0.80,2.38),
			Vector2(0.73,2.56),Vector2(0.40,2.60),Vector2(0.17,2.53)],side),0.88,1.065,STONE.lightened(0.04))
		# Long temple ear relief, with a narrow recessed inner cut.
		_relief(stone,_mirror([Vector2(0.83,1.03),Vector2(0.99,1.12),Vector2(1.025,2.46),
			Vector2(0.94,2.66),Vector2(0.82,2.48)],side),0.36,0.74,STONE.darkened(0.035))
		_relief(stone,_mirror([Vector2(0.915,1.25),Vector2(0.955,1.36),Vector2(0.97,2.38),
			Vector2(0.92,2.45)],side),0.735,0.752,SHADOW)
	# Short wide nose: bridge, sloping tip, restrained underside.
	_polyhedron(stone,[Vector3(-0.12,2.47,0.97),Vector3(0.12,2.47,0.97),
		Vector3(-0.22,1.91,1.24),Vector3(0.22,1.91,1.24),Vector3(-0.28,1.77,1.13),
		Vector3(0.28,1.77,1.13),Vector3(-0.16,1.70,0.96),Vector3(0.16,1.70,0.96)],
		[[0,1,3,2],[2,3,5,4],[4,5,7,6],[0,2,4,6],[1,7,5,3],[0,6,7,1]],STONE.lightened(0.025))
	# Small worn lips. The seam is a shallow cut, not an open black slot.
	_relief(stone,[Vector2(-0.39,1.32),Vector2(0,1.29),Vector2(0.39,1.32),
		Vector2(0.30,1.37),Vector2(0,1.35),Vector2(-0.30,1.37)],0.92,1.025,SHADOW)
	_relief(stone,[Vector2(-0.36,1.39),Vector2(0,1.36),Vector2(0.36,1.39),
		Vector2(0.21,1.49),Vector2(0,1.47),Vector2(-0.21,1.49)],0.90,1.045,STONE)
	_relief(stone,[Vector2(-0.31,1.28),Vector2(-0.22,1.18),Vector2(0.22,1.18),
		Vector2(0.31,1.28),Vector2(0,1.25)],0.91,1.035,STONE.lightened(0.015))
	# Low stepped masonry with asymmetrically worn corners, not ornate headwear.
	_crown(stone,3.02,3.23,1.045,0.90,0.025,STONE.darkened(0.07))
	_crown(stone,3.23,3.51,0.98,0.83,0.085,STONE)
	_crown(stone,3.51,3.8,0.76,0.66,0.14,STONE.lightened(0.025))
	_relief(moss,[Vector2(-0.70,3.54),Vector2(-0.36,3.52),Vector2(-0.27,3.68),
		Vector2(-0.38,3.79),Vector2(-0.64,3.79)],0.661,0.667,Color("687a59"))
	_relief(moss,[Vector2(0.74,3.25),Vector2(0.95,3.26),Vector2(0.91,3.43),
		Vector2(0.82,3.47)],0.831,0.837,Color("697b5e"))
	_relief(moss,[Vector2(-0.86,0.10),Vector2(-0.60,0.10),Vector2(-0.64,0.25),
		Vector2(-0.81,0.29)],0.681,0.70,Color("5e7055"))
	for pair in [[stone,"CarvedStone"],[moss,"SparseMoss"]]:
		var node := MeshInstance3D.new()
		node.name = pair[1]
		node.mesh = pair[0].commit()
		var material: StandardMaterial3D = arena._material(Color.WHITE)
		material.vertex_color_use_as_albedo = true
		node.material_override = material
		root.add_child(node)
	root.set_meta("visual_only",true)
	return root

static func _mirror(points: Array, side: float) -> Array:
	var result: Array = []
	for p in points: result.append(Vector2(p.x*side,p.y))
	return result

static func _relief(st: SurfaceTool, outline: Array, back: float, front: float, color: Color) -> void:
	var vertices: Array = []
	for z in [back,front]:
		for p in outline: vertices.append(Vector3(p.x,p.y,z))
	var n := outline.size()
	var faces: Array = []
	for i in n:
		faces.append([i,(i+1)%n,(i+1)%n+n,i+n])
	# Concave lip and eyelid outlines need polygon triangulation, not a fan.
	var indices := Geometry2D.triangulate_polygon(PackedVector2Array(outline))
	for i in range(0,indices.size(),3):
		faces.append([indices[i],indices[i+1],indices[i+2]])
		faces.append([indices[i]+n,indices[i+1]+n,indices[i+2]+n])
	_polyhedron(st,vertices,faces,color)

static func _loft(st: SurfaceTool, bands: Array, color: Color) -> void:
	var vertices: Array = []
	for band in bands:
		var y: float = band.x
		var w: float = band.y
		var front: float = band.z
		var back: float = band.w
		for p in [Vector2(-w*0.68,front),Vector2(w*0.68,front),Vector2(w,front-0.24),
			Vector2(w,back+0.24),Vector2(w*0.7,back),Vector2(-w*0.7,back),
			Vector2(-w,back+0.24),Vector2(-w,front-0.24)]:
			vertices.append(Vector3(p.x,y,p.y))
	var faces: Array = []
	for band in range(bands.size()-1):
		for i in 8: faces.append([band*8+i,band*8+(i+1)%8,(band+1)*8+(i+1)%8,(band+1)*8+i])
	faces.append([0,1,2,3,4,5,6,7])
	var cap: Array = []
	for i in 8: cap.append((bands.size()-1)*8+i)
	faces.append(cap)
	_polyhedron(st,vertices,faces,color)

static func _crown(st: SurfaceTool, low: float, high: float, w: float, depth: float, chip: float, color: Color) -> void:
	var vertices: Array = []
	for y in [low,high]:
		for p in [Vector2(-w+0.15,depth),Vector2(w-0.17,depth),Vector2(w,depth-0.18-chip),
			Vector2(w,-depth+0.18),Vector2(w-0.20,-depth),Vector2(-w+0.16,-depth),
			Vector2(-w,-depth+0.17),Vector2(-w,depth-0.14)]:
			vertices.append(Vector3(p.x,y-(chip if y==high and p.x>w*0.8 else 0.0),p.y))
	var faces: Array = [[0,1,2,3,4,5,6,7],[8,9,10,11,12,13,14,15]]
	for i in 8: faces.append([i,(i+1)%8,(i+1)%8+8,i+8])
	_polyhedron(st,vertices,faces,color)

static func _polyhedron(st: SurfaceTool, vertices: Array, faces: Array, color: Color) -> void:
	var center := Vector3.ZERO
	for v in vertices: center += v
	center /= vertices.size()
	for face in faces:
		for i in range(1,face.size()-1):
			_triangle(st,vertices[face[0]],vertices[face[i]],vertices[face[i+1]],center,color)

static func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, center: Vector3, color: Color) -> void:
	var normal := (b-a).cross(c-a).normalized()
	if normal.dot((a+b+c)/3.0-center)<0.0:
		var swap := b
		b = c
		c = swap
		normal = -normal
	# Clockwise engine front faces; explicit flat normals point outward.
	for vertex in [a,c,b]:
		st.set_normal(normal)
		st.set_color(color)
		st.add_vertex(vertex)
