extends RefCounted
## Layered broadleaf groves; two opaque mesh batches, no movement blockers or RNG use.
const Roots=preload("res://game/wetland_root_environment.gd")
const ROOT_RADIUS:=55.0
static func build(arena:Node3D,points:Array,title:String)->Node3D:
	var root:=Node3D.new()
	root.name=title
	var wood:=SurfaceTool.new()
	var leaves:=SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size():
		var base:Vector3=arena.terrain.world_point(points[i])
		var lean:=Vector3(sin(i*1.7)*0.24,2.25+0.2*sin(i),cos(i*0.8)*0.13)
		var crown:=base+lean+Vector3(0.12,1.04+0.25*sin(i*0.7),0.06)
		Roots._tube(wood,base,base+lean,0.31,0.21,Color("344a3c"))
		Roots._tube(wood,base+lean,crown,0.21,0.10,Color("4a6048"))
		for arm in 4:
			var angle:=arm*TAU/4.0+i*0.6
			var edge:=base+Vector3(cos(angle),0,sin(angle))*ROOT_RADIUS*0.01
			Roots._tube(wood,base+Vector3.UP*0.7,edge,0.16,0.025,Color("4d6348"))
		for lobe in 3:
			var angle:=lobe*TAU/3.0+i*0.45
			var tip:=crown+Vector3(cos(angle)*0.48,lobe*0.13,sin(angle)*0.42)
			Roots._tube(wood,base+lean,tip,0.10,0.04,Color("405a42"))
			_blob(leaves,tip,Vector3(1.08+0.12*sin(i+lobe),0.66,0.92),i*3+lobe,Color("365c46") if lobe==0 else Color("41684b") if lobe==1 else Color("4c7352"))
		# A few hanging vine strokes belong to the background crown, not the walkway.
		if i%3==0:
			var tip:=crown+Vector3(-0.6,0.1,0.15)
			Roots._tube(wood,tip,tip+Vector3(0.1,-1.1,0.08),0.023,0.012,Color("687b50"))
	for pair in [[wood,"ButtressedTrunks"],[leaves,"LayeredCrowns"]]:
		var node:=MeshInstance3D.new()
		node.name=pair[1]
		node.mesh=pair[0].commit()
		var material:StandardMaterial3D=arena._material(Color.WHITE)
		material.vertex_color_use_as_albedo=true
		node.material_override=material
		root.add_child(node)
	root.set_meta("visual_only",true)
	root.set_meta("root_points",points.duplicate())
	root.set_meta("root_radius",ROOT_RADIUS)
	return root
static func _blob(st:SurfaceTool,center:Vector3,scale:Vector3,seed_value:int,color:Color)->void:
	var rings:Array=[]
	for band in [[0.58,0.18],[0.29,0.80],[-0.10,1.0],[-0.44,0.34]]:
		var ring:Array[Vector3]=[]
		for k in 8:
			var a:=TAU*k/8.0+seed_value*0.23
			var r:float=band[1]*(1.0+0.07*sin(seed_value*2.0+k*1.9))
			ring.append(center+Vector3(cos(a)*r,band[0],sin(a)*r)*scale)
		rings.append(ring)
	for band in range(rings.size()-1):
		for k in 8:
			var n:=(k+1)%8
			var shade:=color.lightened(0.04) if band==0 else color.darkened(0.055) if band==2 else color
			_triangle(st,rings[band][k],rings[band+1][k],rings[band+1][n],center,shade)
			_triangle(st,rings[band][k],rings[band+1][n],rings[band][n],center,shade)
	for k in 8:
		_triangle(st,center+Vector3.UP*scale.y*0.65,rings[0][k],rings[0][(k+1)%8],center,color.lightened(0.05))
		_triangle(st,center-Vector3.UP*scale.y*0.49,rings[3][(k+1)%8],rings[3][k],center,color.darkened(0.07))
static func _triangle(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,center:Vector3,color:Color)->void:
	var normal:Vector3=(b-a).cross(c-a).normalized()
	if normal.dot((a+b+c)/3.0-center)<0: normal=-normal
	for vertex in [a,c,b]:
		st.set_color(color)
		st.set_normal(normal)
		st.add_vertex(vertex)
