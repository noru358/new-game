extends RefCounted
## Low, opaque water vegetation in coherent bank clusters; no collision or RNG.
const CLUSTERS := [Vector2(1610,1550),Vector2(2240,1140),Vector2(2550,1860),Vector2(3140,1870),Vector2(4380,1230)]
static func build(arena:Node3D)->MeshInstance3D:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var footprints:Array=[]
	for index in CLUSTERS.size():
		var center:Vector2=CLUSTERS[index]
		for pad in 7:
			var angle:=pad*2.399+index*0.6
			var distance:=18.0+pad*15.0
			var p:=center+Vector2(cos(angle),sin(angle))*distance
			var radius:=14.0+float(pad%3)*5.0
			if not _wet(arena,p,radius+3):continue
			footprints.append({"point":p,"radius":radius+3})
			var color:=Color("50715c") if pad%2 else Color("638063")
			var first:=angle+0.22
			# A small missing wedge reads as a broad floating leaf, not a stepping stone.
			for side in 8:
				var a:=first+float(side)*5.82/8.0
				var b:=first+float(side+1)*5.82/8.0
				_triangle(st,Vector3(p.x,2.0,p.y),Vector3(p.x+cos(a)*radius,2.0,p.y+sin(a)*radius*0.8),Vector3(p.x+cos(b)*radius,2.0,p.y+sin(b)*radius*0.8),color)
		for tuft in 5:
			var p:=center+Vector2(-90+tuft*15,45+sin(tuft+index)*18)
			if not _wet(arena,p,12):continue
			footprints.append({"point":p,"radius":12.0})
			for blade in 3:
				var a:=Vector3(p.x+blade*3,1.5,p.y)
				var b:=a+Vector3(4,0,3)
				var tip:=a+Vector3(8*sin(tuft+blade),22+blade*8,8*cos(index+blade))
				_triangle(st,a,b,tip,Color("698469") if blade%2 else Color("526e57"))
	var node:=MeshInstance3D.new()
	node.name="WaterbankVegetation"
	node.mesh=st.commit()
	var material:StandardMaterial3D=arena._material(Color.WHITE)
	material.vertex_color_use_as_albedo=true
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	node.material_override=material
	node.set_meta("water_footprints",footprints)
	node.set_meta("visual_only",true)
	return node
static func _wet(arena:Node3D,p:Vector2,radius:float)->bool:
	for i in 16:
		var q:=p+Vector2.from_angle(TAU*i/16.0)*radius
		var found:=false
		for water in arena.terrain.water_areas:
			if water.has_point(q):found=true;break
		if not found:return false
	return true
static func _triangle(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,color:Color)->void:
	var normal:Vector3=(c-a).cross(b-a).normalized()
	if normal.y<0:normal=-normal
	for vertex in [a,c,b]:
		st.set_color(color)
		st.set_normal(normal)
		st.add_vertex(vertex*0.01)
