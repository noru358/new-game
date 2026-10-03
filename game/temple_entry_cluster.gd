extends RefCounted
## Southeast Asia / reclaimed temple / court exit into the existing west cloister.
## An authored grouping of broken masonry, sheltered plants and ground contacts.
## Install after the circuit's normal _ready. No terrain, collision or light edits.
const SCALE := 0.01
const SOURCE_AREA := Rect2(1730, 1190, 420, 500)
const REPLACE_AREA := Rect2(1729.5, 1189.5, 421, 501)
const PLACEMENT_OFFSET := Vector3.ZERO
const SOLID_AREA := SOURCE_AREA
const CONTACT_AREA := Rect2(1660, 1200, 90, 500)
const FLOOR_LIFT := 0.67
const Kit = preload("res://game/temple_environment_kit.gd")
var stone := SurfaceTool.new()
var growth := SurfaceTool.new()
var ground := SurfaceTool.new()
var counts := {"stone":0, "growth":0, "ground":0}

static func install(arena: Node3D) -> Node3D:
	if arena.get_script() != load("res://game/temple_circuit_run.gd"): return null
	if OS.get_cmdline_user_args().has("--temple-entry-baseline"): return null
	if arena.has_node("TempleEntryCluster"): return arena.get_node("TempleEntryCluster")
	var root := Node3D.new()
	root.name = "TempleEntryCluster"
	# Replace the complete obstructing hall ornament, rather than a small window.
	root.position = PLACEMENT_OFFSET
	var court:Node3D = arena.temple_sanctuary_root.get_node("ReclaimedCourtMasonry")
	for label in ["WeatheredCourtyardWalls", "CourtyardEdgeGrowth"]:
		var mesh: MeshInstance3D = court.get_node(label)
		mesh.set_meta("temple_entry_original_mesh", mesh.mesh)
		mesh.mesh = _outside_slice(mesh.mesh)
	var builder = load("res://game/temple_entry_cluster.gd").new()
	for surface in [builder.stone, builder.growth, builder.ground]: surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder._masonry_group()
	builder._sheltered_growth()
	builder._ground_contacts(arena)
	for spec in [[builder.stone,"BrokenMasonry","stone",true], [builder.growth,"ShelteredGrowth","growth",false], [builder.ground,"StoneSoilContacts","ground",false]]:
		var visual := MeshInstance3D.new()
		visual.name = spec[1]
		visual.mesh = spec[0].commit()
		visual.material_override = court.get_node("WeatheredCourtyardWalls" if spec[2] == "stone" else "CourtyardEdgeGrowth").material_override
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if spec[3] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(visual)
	root.set_meta("visual_only", true)
	root.set_meta("source_barrier", SOURCE_AREA)
	root.set_meta("solid_bounds", Rect2(SOLID_AREA.position+Vector2(PLACEMENT_OFFSET.x,PLACEMENT_OFFSET.z)/SCALE,SOLID_AREA.size))
	root.set_meta("contact_bounds", Rect2(CONTACT_AREA.position+Vector2(PLACEMENT_OFFSET.x,PLACEMENT_OFFSET.z)/SCALE,CONTACT_AREA.size))
	root.set_meta("max_contact_lift", FLOOR_LIFT+0.055)
	root.set_meta("vertex_counts", builder.counts)
	root.set_meta("plant_scales", {"grass":14.0,"broad_leaf":44.0,"back_vine":78.0})
	arena.add_child(root)
	return root

func _masonry_group() -> void:
	# The entire former hall ornament is gone. Low sill along the walking face,
	# tall broken members at the back, one broad fallen stone between them.
	# No full-height foreground bay remains over the soil/leaf colony.
	for spec in [[Rect2(1731,1194,33,142),18.0,0], [Rect2(1731,1338,36,166),23.0,1], [Rect2(1731,1506,29,182),16.0,2]]:
		_weathered_stone(spec[0],0.0,spec[1],5.5,spec[2],Color("b0a88b"))
	_weathered_stone(Rect2(1770,1280,117,112),0.0,109.0,12.0,3,Color("aaa287"))
	_weathered_stone(Rect2(1925,1296,112,128),0.0,89.0,13.0,4,Color("b4aa8d"))
	_weathered_stone(Rect2(1784,1490,154,89),0.0,37.0,10.0,5,Color("a7a188"))
	_weathered_stone(Rect2(1772,1605,63,52),0.0,21.0,7.0,6,Color("b6ad90"))
	# Low fallen courses on the blocked rear apron mark the retained barrier.
	for spec in [[Rect2(1970,1450,114,83),15.0,1],[Rect2(2069,1560,77,98),12.0,2],[Rect2(2055,1195,90,68),19.0,0]]:
		_weathered_stone(spec[0],0.0,spec[1],6.0,spec[2],Color("989780"))

func _weathered_stone(area: Rect2, bottom: float, top: float, bevel: float, variant: int, tint: Color) -> void:
	var p := area.position; var e := area.end
	var outline: Array[Vector2] = [Vector2(p.x+bevel*1.8,p.y),Vector2(e.x-bevel,p.y),Vector2(e.x,p.y+bevel*1.7),Vector2(e.x,e.y-bevel*1.4),Vector2(e.x-bevel*2.0,e.y),Vector2(p.x+bevel,e.y),Vector2(p.x,e.y-bevel),Vector2(p.x,p.y+bevel*2.1)]
	var lower: Array[Vector3] = []; var shoulder: Array[Vector3] = []; var cap: Array[Vector3] = []
	var center := area.get_center()
	var heights := [0.0,-1.0,-2.0,-3.0,-1.5,0.0,-2.0,-1.0] if variant else [0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0]
	if variant >= 3: heights = [0.0,-2.0,-4.0,-18.0,-24.0,-9.0,-3.0,-1.0] if variant % 2 else [-11.0,-3.0,0.0,-2.0,-6.0,-18.0,-15.0,-9.0]
	for i in outline.size():
		var point: Vector2 = outline[i]
		var high := maxf(bottom+2.0, top+heights[(i+variant)%8])
		lower.append(Vector3(point.x,bottom,point.y))
		shoulder.append(Vector3(point.x,maxf(bottom+1.0,high-bevel*0.64),point.y))
		var inset: Vector2 = point.move_toward(center, minf(bevel,area.size.y*0.16))
		cap.append(Vector3(inset.x,high,inset.y))
	for i in outline.size():
		var j := (i+1)%outline.size()
		var fracture := variant >= 3 and i in [2,3,4]
		_quad(stone,lower[i],shoulder[i],shoulder[j],lower[j],tint.darkened(0.025 if fracture else 0.07))
		_quad(stone,shoulder[i],cap[i],cap[j],shoulder[j],tint.lightened(0.035))
	var peak := Vector3(center.x,cap.reduce(func(a,b):return a+b.y,0.0)/cap.size(),center.y)
	for i in outline.size(): _tri(stone,peak,cap[(i+1)%outline.size()],cap[i],tint.lightened(0.065))

func _sheltered_growth() -> void:
	# A continuous sheltered edge reads from the road after removing the old bay.
	for spec in [[Vector3(1769,0.67,1410),14.0,0.5],[Vector3(1802,0.67,1430),11.0,1.4],[Vector3(1769,0.67,1473),13.0,2.2]]:
		_grass_tuft(spec[0],spec[1],spec[2])
	_rosette(Vector3(1782,0.67,1444),1.0,0.3)
	_rosette(Vector3(1764,0.67,1523),0.68,1.6)
	_rosette(Vector3(1870,0.67,1420),0.57,2.1)
	var kit := Kit.new()
	kit._growth=growth
	for strand in 3:
		var start:=Vector3(1792+strand*18,98-strand*4,1393)
		var path:Array[Vector3]=[start,start+Vector3(-3,-23,1),start+Vector3(2,-47,2),start+Vector3(-4,-70,4),start+Vector3(6,-93,10)]
		kit._root(path,1.2,SOLID_AREA,Color("6d7752"),growth)
		for leaf in 5:
			var origin:=path[mini(leaf,3)]+Vector3(0,-3,0.8)
			_leaf(origin,Vector3(-0.7 if leaf%2 else 0.8,-0.3,0.5).normalized(),24.0,15.0,5.0,Color("5f774f"),float(leaf)*0.2)
	counts.growth+=kit._vertex_counts[2]
	_patch(growth,Vector3(1753,0.69,1455),Vector2(11,29),Color("61734f"),3)
	_patch(growth,Vector3(1753,0.69,1590),Vector2(11,34),Color("657750"),1)

func _rosette(origin: Vector3, scale: float, rotation: float) -> void:
	for i in 6:
		var angle := rotation+float(i)*TAU/6.0
		var direction := Vector3(cos(angle),0,sin(angle))
		_leaf(origin,direction,(52.0+6.0*(i%2))*scale,(32.0+4.0*(i%3))*scale,(37.0+7.0*(i%2))*scale,Color("64804f").lightened(0.025*(i%3)),0.0)

func _leaf(origin: Vector3, along: Vector3, length: float, width: float, rise: float, tint: Color, curl: float) -> void:
	# Rounded lance/heart silhouette, curved along its length and cupped across it.
	# An actual opaque curved surface; no alpha billboard, triangle shard or flat decal.
	var side := along.cross(Vector3.UP).normalized()
	if side.length_squared()<0.01: side=Vector3.RIGHT
	var grid: Array[Array] = []
	for row in 9:
		var t := float(row)/8.0
		var extent := pow(sin(PI*t),0.78)*width*0.5
		var ridge := origin+along*length*t+Vector3.UP*(sin(PI*t*0.85)*rise)
		var points: Array[Vector3] = []
		for column in 5:
			var across := (float(column)-2.0)/2.0
			var point := ridge+side*extent*across+Vector3.UP*(-absf(across)*extent*0.17+curl*t*t)
			point.x=clampf(point.x,SOLID_AREA.position.x+0.7,SOLID_AREA.end.x-0.7)
			point.z=clampf(point.z,SOLID_AREA.position.y+0.7,SOLID_AREA.end.y-0.7)
			points.append(point)
		grid.append(points)
	for row in 8:
		for column in 4:
			var color := tint.lightened(0.028 if column==1 else 0.0).darkened(0.045 if column==3 else 0.0)
			_quad(growth,grid[row][column],grid[row][column+1],grid[row+1][column+1],grid[row+1][column],color)

func _grass_tuft(origin: Vector3, height: float, turn: float) -> void:
	for blade in 7:
		var direction := Vector2.from_angle(turn+blade*0.91)
		var start := origin+Vector3(direction.x*3,0,direction.y*3)
		var side := Vector3(-direction.y,0,direction.x)*2.2
		var points: Array[Vector3] = [start,start+Vector3(direction.x*3,height*0.45,direction.y*3),start+Vector3(direction.x*9,height,direction.y*9),start+Vector3(direction.x*17,height*0.63,direction.y*17)]
		for i in 3:
			var a:=side*(1.0-float(i)/3.0); var b:=side*(1.0-float(i+1)/3.0)
			_quad(growth,points[i]-a,points[i+1]-b,points[i+1]+b,points[i]+a,Color("64794c").lightened(0.02*(blade%3)))

func _ground_contacts(arena:Node3D) -> void:
	# Exposed low soil and stone contacts run beside the new continuous low sill.
	for spec in [[Vector2(1708,1320),Vector2(31,94),0],[Vector2(1703,1480),Vector2(37,86),2],[Vector2(1708,1617),Vector2(28,61),1]]:
		var center:Vector2=spec[0]
		_contact_island(Vector3(center.x,arena.terrain.height_at(center)+FLOOR_LIFT,center.y),spec[1],spec[2])
	for spec in [[Vector2(1708,1280),Vector2(12,25),0],[Vector2(1699,1410),Vector2(13,18),2],[Vector2(1718,1540),Vector2(9,16),3],[Vector2(1705,1637),Vector2(13,24),1]]:
		var point:Vector2=spec[0]
		_patch(ground,Vector3(point.x,arena.terrain.height_at(point)+FLOOR_LIFT+0.055,point.y),spec[1],Color("a2a185"),spec[2])

func _contact_island(center:Vector3,radius:Vector2,variant:int) -> void:
	# A single planar surface with adjacent soil/moss colors, no stacked coplanar decals.
	var outer:Array[Vector3]=[];var inner:Array[Vector3]=[]
	for i in 12:
		var angle:=TAU*float(i)/12.0
		var extent:=0.80 if (i+variant)%4==0 else (0.91 if i%3==0 else 1.0)
		var direction:=Vector3(cos(angle)*radius.x*extent,0,sin(angle)*radius.y*extent)
		outer.append(center+direction);inner.append(center+direction*0.52)
	for i in 12:
		var j:=(i+1)%12
		_quad(ground,inner[i],inner[j],outer[j],outer[i],Color("777f66"))
		_tri(ground,center,inner[j],inner[i],Color("697752"))

func _patch(surface: SurfaceTool, center: Vector3, radius: Vector2, tint: Color, variant: int) -> void:
	var edges: Array[Vector3] = []
	for i in 12:
		var angle := TAU*float(i)/12.0
		var extent := 0.80 if (i+variant)%4==0 else (0.91 if i%3==0 else 1.0)
		edges.append(center+Vector3(cos(angle)*radius.x*extent,0,sin(angle)*radius.y*extent))
	for i in 12: _tri(surface,center,edges[(i+1)%12],edges[i],tint)

func _quad(surface: SurfaceTool, a: Vector3,b: Vector3,c: Vector3,d: Vector3,tint: Color) -> void:
	_tri(surface,a,b,c,tint); _tri(surface,a,c,d,tint)

func _tri(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,tint: Color) -> void:
	var normal := (b-a).cross(c-a).normalized()
	if normal.length_squared()<0.1: return
	for point in [a,b,c]:
		surface.set_normal(normal); surface.set_color(tint); surface.add_vertex(point*SCALE)
	var key := "stone" if surface==stone else ("growth" if surface==growth else "ground")
	counts[key] += 3

static func _outside_slice(mesh: Mesh) -> ArrayMesh:
	# Remove all original hall ornament from the two batches. Plateau is separate.
	# All emitted vertices retain interpolated original colors/normals. Materials stay.
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray=arrays[Mesh.ARRAY_COLOR]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var planes := [[0,REPLACE_AREA.position.x*SCALE,true],[0,REPLACE_AREA.end.x*SCALE,false],[2,REPLACE_AREA.position.y*SCALE,true],[2,REPLACE_AREA.end.y*SCALE,false]]
	var count := indices.size() if not indices.is_empty() else vertices.size()
	for tri in range(0,count,3):
		var polygon: Array = []
		for offset in 3:
			var i := indices[tri+offset] if not indices.is_empty() else tri+offset
			polygon.append({"v":vertices[i],"c":colors[i],"n":normals[i]})
		var bounds := Rect2(Vector2(polygon[0].v.x,polygon[0].v.z)/SCALE,Vector2.ZERO)
		for vertex in polygon: bounds=bounds.expand(Vector2(vertex.v.x,vertex.v.z)/SCALE)
		if bounds.end.x<REPLACE_AREA.position.x or bounds.position.x>REPLACE_AREA.end.x or bounds.end.y<REPLACE_AREA.position.y or bounds.position.y>REPLACE_AREA.end.y:
			_emit(st,polygon)
			continue
		for plane in planes:
			if polygon.size()<3: break
			var outside := _clip(polygon,plane,false)
			_emit(st,outside)
			polygon=_clip(polygon,plane,true)
	return st.commit()

static func _clip(polygon: Array,plane: Array,keep_inside: bool) -> Array:
	var result: Array=[]
	for i in polygon.size():
		var a:Dictionary=polygon[i]; var b:Dictionary=polygon[(i+1)%polygon.size()]
		var av:float=a.v[plane[0]]; var bv:float=b.v[plane[0]]
		var ai:bool=av>=plane[1] if plane[2] else av<=plane[1]
		var bi:bool=bv>=plane[1] if plane[2] else bv<=plane[1]
		if ai==keep_inside: result.append(a)
		if ai!=bi:
			var weight:float=(plane[1]-av)/(bv-av)
			result.append({"v":a.v.lerp(b.v,weight),"c":a.c.lerp(b.c,weight),"n":a.n.lerp(b.n,weight).normalized()})
	return result

static func _emit(st: SurfaceTool,polygon: Array) -> void:
	for i in range(1,polygon.size()-1):
		if (polygon[i].v-polygon[0].v).cross(polygon[i+1].v-polygon[0].v).length_squared()<0.000000000001: continue
		for vertex in [polygon[0],polygon[i],polygon[i+1]]:
			st.set_normal(vertex.n); st.set_color(vertex.c); st.add_vertex(vertex.v)
