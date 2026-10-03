extends RefCounted
## An open-sided rock passage and small water shrine, authored for the fixed
## southeast camera. Roof stones remain behind the walked floor at all times.
## No fades, cutaways, particles, interactions, enemies or progression nodes.
const Layout = preload("res://game/jungle_grotto_layout.gd")
const Data = preload("res://game/jungle_hidden_terrain.gd")
const Vegetation = preload("res://game/jungle_emergent_tree.gd")
const Waterfalls = preload("res://game/jungle_waterfall_sources.gd")
const FLOOR_LIFT := 0.65

static func build(arena, layout) -> Node3D:
	var terrain = arena.terrain
	var root := Node3D.new()
	root.name = "JungleHiddenSanctuary"
	var rock := SurfaceTool.new()
	var masonry := SurfaceTool.new()
	var wood := SurfaceTool.new()
	var growth := SurfaceTool.new()
	var floor := SurfaceTool.new()
	for surface in [rock, masonry, wood, growth, floor]: surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var banks: Array[Rect2] = []
	var bank_profiles: Array = []
	var records: Array = []
	for record in terrain.wall_areas:
		if not record.get("hidden_rock", false): continue
		banks.append(record.area)
		records.append(record)
	# Perimeter strips overlap the grid's outer cells. Give those existing tall
	# edge profiles their own footprint, then cut it from the grid rock. Every
	# blocked point still has rock; no two exterior faces compete for depth.
	var ordered: Array = []
	var edges := [Rect2(6000,80,4200,40),Rect2(6000,2840,4200,40),Rect2(6000,80,40,2800),Rect2(10160,80,40,2800)]
	for edge in edges:
		for record in records:
			if record.area == edge: ordered.append(record)
	for record in records:
		if not edges.has(record.area): ordered.append(record)
	var emitted: Array = []
	var profiles: Array = []
	for record in ordered:
		# The landmarks replace this exact part of the bank with their own full
		# foundation. Keeping both faces causes native depth flicker and buries
		# the columns. Collision/minimap and the outer blocked union are unchanged.
		var cutouts: Array = [Data.SHOULDER,Data.BACK]
		for area in emitted:
			if record.area.intersects(area): cutouts.append(area)
		var pieces: Array = terrain.surface_areas({"area":record.area,"cutouts":cutouts})
		bank_profiles.append({"source":record.area,"pieces":pieces})
		for piece in pieces:
			emitted.append(piece)
			var profile: Dictionary = record.duplicate()
			profile["area"] = piece
			profiles.append(profile)
	var adjacent: Array = profiles + [{"area":Data.SHOULDER,"flat_top":120.0},{"area":Data.BACK,"flat_top":30.0}]
	for profile in profiles: _bank(rock,profile,adjacent)
	# Keep all original plant/root anchors and densities while repairing faces.
	var bank_index := 0
	for record in records:
		if not record.get("foreground_edge", false) and record.area.size.x >= 280 and bank_index % 3 == 0:
			_bank_growth(wood, growth, record, bank_index)
		bank_index += 1
	_threshold(rock, masonry, wood)
	_water_basin(masonry, Rect2(7190, 2745, 320, 85), 35.0)
	_water_basin(masonry, Rect2(9240, 1360, 90, 90), 26.0)
	_shrine(masonry, wood, growth)
	_ground_courses(floor, terrain)
	for pair in [[rock,"RockBanks"],[masonry,"WaterReceivingStone"],[wood,"RootAndVine"],[growth,"BankVegetation"],[floor,"ThresholdAndSunlitCourses"]]:
		var node := MeshInstance3D.new()
		node.name = pair[1]
		node.mesh = pair[0].commit()
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.88 if pair[1] == "WaterReceivingStone" else 1.0
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(node)
	root.set_meta("source_bank_areas", banks)
	root.set_meta("bank_profiles", bank_profiles)
	root.set_meta("region_hierarchy", ["동남아", "정글", "폭포 뒤 굴→작은 물받이→뿌리 성역"])
	root.set_meta("fixed_open_roof", true)
	root.set_meta("field_bounds", layout.FIELD_BOUNDS)
	root.set_meta("floor_lift", FLOOR_LIFT)
	for spec in Waterfalls.HIDDEN: root.add_child(Waterfalls.build(arena,spec,profiles))
	return root

static func build_entry(arena, _layout) -> Node3D:
	# Keep the four clues and existing terrain, with each drop rooted in a real
	# rock lip instead of a detached fixed-height plate. No collision is added.
	var root := Node3D.new()
	root.name = "JungleHiddenEntrance"
	for spec in Waterfalls.MAIN: root.add_child(Waterfalls.build(arena,spec))
	for point in [Vector2(1130,455),Vector2(1360,540),Vector2(1380,780)]:
		var bush: MeshInstance3D = arena._sphere(0.35,Color("356b51"))
		bush.name = "GrottoBush"
		bush.position = arena.terrain.world_point(point,30)
		bush.scale = Vector3(1.4,0.75,1.0)
		root.add_child(bush)
	return root

static func _bank(st: SurfaceTool, record: Dictionary, adjacent: Array = []) -> void:
	# The continuous ground outline is precisely the blocked strip; crags vary
	# inside it, instead of multiplying separate colliders or painting a maze wall.
	var area: Rect2 = record.area
	var low: bool = record.get("foreground_edge", false)
	var divisions := maxi(1, ceili(area.size.x / 140.0))
	for i in divisions:
		# Derive both neighboring cell corners from the same expression. Repeated
		# Rect2 position+width additions made subpixel overlapping slivers at joins.
		var x0 := area.position.x + i * area.size.x / divisions
		var x1 := area.end.x if i == divisions-1 else area.position.x + (i+1) * area.size.x / divisions
		var cell := Rect2(x0,area.position.y,x1-x0,area.size.y)
		var h: float = record.height
		var tint: Color = record.color.lightened(0.025 * sin(cell.position.x * 0.011 + cell.position.y * 0.013))
		var top: Array[Vector3] = []
		for p in [Vector2(x0,area.position.y),Vector2(x1,area.position.y),Vector2(x1,area.end.y),Vector2(x0,area.end.y)]:
			top.append(Vector3(p.x, _bank_edge_height(record,p), p.y))
		var center := Vector3(cell.get_center().x, h * (0.86 if low else 0.98), cell.get_center().y)
		for edge in 4:
			var a: Vector3 = top[edge]
			var b: Vector3 = top[(edge + 1) % 4]
			_tri(st, a, center, b, tint.lightened(0.025 * edge))
			# Cell sides inside one strip have identical shared edge heights. Between
			# strips, emit only the exposed height above the neighbor's rock surface.
			if edge == 1 and i < divisions-1 or edge == 3 and i > 0: continue
			_bank_side(st,a,b,edge,adjacent,tint.darkened(0.12))

static func _bank_edge_height(record: Dictionary, p: Vector2) -> float:
	if record.has("flat_top"): return record.flat_top
	return record.height * (0.58 if record.get("foreground_edge",false) else 0.74+0.13*sin(p.x*0.009+p.y*0.016))

static func _bank_side(st: SurfaceTool,a: Vector3,b: Vector3,edge: int,adjacent: Array,tint: Color) -> void:
	var horizontal := edge == 0 or edge == 2
	var origin := a.x if horizontal else a.z
	var length := (b.x-a.x) if horizontal else (b.z-a.z)
	var cuts: Array[float] = [0.0,1.0]
	var neighbors: Array = []
	for record in adjacent:
		var area: Rect2 = record.area
		var touching := is_equal_approx(area.end.y,a.z) if edge == 0 else is_equal_approx(area.position.x,a.x) if edge == 1 else is_equal_approx(area.position.y,a.z) if edge == 2 else is_equal_approx(area.end.x,a.x)
		if not touching: continue
		var t0 := ((area.position.x if horizontal else area.position.y)-origin)/length
		var t1 := ((area.end.x if horizontal else area.end.y)-origin)/length
		var interval := Vector2(maxf(0.0,minf(t0,t1)),minf(1.0,maxf(t0,t1)))
		if interval.x < 0.00001: interval.x = 0.0
		if interval.y > 0.99999: interval.y = 1.0
		if interval.y-interval.x <= 0.00001: continue
		cuts.append(interval.x)
		cuts.append(interval.y)
		neighbors.append({"range":interval,"profile":record})
	cuts.sort()
	for i in range(cuts.size()-1):
		if cuts[i+1]-cuts[i] <= 0.00001: continue
		var p: Vector3 = a if cuts[i] == 0.0 else b if cuts[i] == 1.0 else a.lerp(b,cuts[i])
		var q: Vector3 = a if cuts[i+1] == 0.0 else b if cuts[i+1] == 1.0 else a.lerp(b,cuts[i+1])
		var lower_p := Vector3(p.x,0,p.z)
		var lower_q := Vector3(q.x,0,q.z)
		var mid: float = (cuts[i]+cuts[i+1])*0.5
		for neighbor in neighbors:
			if mid > neighbor.range.x and mid < neighbor.range.y:
				lower_p.y = _bank_edge_height(neighbor.profile,Vector2(p.x,p.z))
				lower_q.y = _bank_edge_height(neighbor.profile,Vector2(q.x,q.z))
				break
		var dp := p.y-lower_p.y
		var dq := q.y-lower_q.y
		if dp <= 0.0001 and dq <= 0.0001: continue
		if dp <= 0.0001 or dq <= 0.0001:
			var cross: Vector3 = p.lerp(q,dp/(dp-dq))
			if dp > 0.0001: _tri(st,lower_p,cross,p,tint)
			else: _tri(st,cross,lower_q,q,tint)
		else: _quad(st,lower_p,lower_q,q,p,tint)

static func _threshold(rock: SurfaceTool, stone: SurfaceTool, wood: SurfaceTool) -> void:
	var area := Data.SHOULDER
	_block(rock, area, 0, 120, Color("68776c"))
	# A collapsed, asymmetric lintel sits entirely north of the traversed floor.
	# Its broken southeast end exposes the passage from the locked camera.
	_block(stone, Rect2(6705,2330,78,112),120,220,Color("849183"))
	_block(stone, Rect2(6922,2330,52,80),120,178,Color("778677"))
	_block(rock, Rect2(6670 + 38,2330,188,106),196,228,Color("909b8a"))
	_block(stone, Rect2(6890,2375,75,52),121,145,Color("899589"))
	# Roots clasp the roof's back and broken end, never sweep across the actor lane.
	_strand(wood, [Vector3(6750,226,2345),Vector3(6800,232,2380),Vector3(6880,204,2400),Vector3(6940,130,2418)], [9.0,10.0,8.0,3.0], Color("686349"))

static func _water_basin(st: SurfaceTool, area: Rect2, rise: float) -> void:
	var stone := Color("9aa68e")
	# A low receiving lip and uneven side stones surround actual blocked water.
	for rim in [Rect2(area.position,Vector2(area.size.x,15)),Rect2(area.position,Vector2(18,area.size.y)),Rect2(area.end.x-18,area.position.y,18,area.size.y),Rect2(area.position.x,area.end.y-17,area.size.x,17)]:
		_block(st,rim,1.4,rise,stone)
	_quad(st,Vector3(area.position.x+18,1.6,area.position.y+15),Vector3(area.position.x+18,1.6,area.end.y-17),Vector3(area.end.x-18,1.6,area.end.y-17),Vector3(area.end.x-18,1.6,area.position.y+15),Color("4e8b83"))

static func _shrine(st: SurfaceTool, wood: SurfaceTool, leaves: SurfaceTool) -> void:
	# A medium monument against the northern bank, unlike the main emergent tree.
	var dry := Color("b4b397")
	_block(st,Data.BACK,0,30,Color("89947d"))
	for spec in [[Rect2(9530,110,78,95),164.0],[Rect2(9690,110,82,95),190.0],[Rect2(9910,110,76,95),112.0]]:
		_block(st,spec[0],30,spec[1],dry)
		_block(st,spec[0].grow(-7),spec[1]-26,spec[1]-12,dry.darkened(0.18))
	_block(st,Rect2(9510,118,260,66),171,190,dry.lightened(0.07))
	_water_basin(st,Rect2(9785,100,115,100),65)
	# The offering bowl is behind the interaction point; its south-facing apron
	# stays free. No new interaction or collider is attached to these stones.
	_block(st,Rect2(9760,292,135,106),0.8,9,Color("adae92"))
	_water_basin(st,Rect2(9778,310,102,70),18)
	_strand(wood,[Vector3(9520,30,91),Vector3(9570,200,112),Vector3(9660,199,143),Vector3(9745,75,173),Vector3(9800,32,185)],[17.0,13.0,11.0,8.0,3.0],Color("75694d"))
	_strand(wood,[Vector3(9960,36,94),Vector3(9900,133,121),Vector3(9820,87,148),Vector3(9850,35,202)],[13.0,10.0,7.0,2.0],Color("686248"))
	for i in 8:
		var p := Vector3(9500+i*63,42+(i%3)*8,95+(i%2)*15)*0.01
		Vegetation._lobe(leaves,p,Vector3(0.38,0.16,0.21),Color("698452"),i+23)

static func _bank_growth(wood: SurfaceTool, leaves: SurfaceTool, record: Dictionary, seed: int) -> void:
	var area: Rect2 = record.area
	var center := area.position + Vector2(minf(area.size.x*0.5,180),area.size.y*0.42)
	var level: float = record.height * 0.83
	# Broad low colonies cling to nonwalkable rock. No tall near-side crowns.
	for i in 3:
		var p := Vector3(center.x+i*26-26,level,center.y+(i%2)*12)*0.01
		Vegetation._lobe(leaves,p,Vector3(0.35,0.13,0.21),Color("66855b").lightened(0.035*(seed%3)),seed+i)
	_strand(wood,[Vector3(center.x-48,level,center.y-20),Vector3(center.x-10,level+8,center.y),Vector3(center.x+52,level*0.63,center.y+26)],[5.0,4.0,1.5],Color("777651"))

static func _ground_courses(st: SurfaceTool, terrain) -> void:
	var barriers: Array[Rect2] = terrain.barriers()
	# Disjoint tiles give damp grey threshold -> pale open clearing -> warm shrine.
	# They sit below the actor shadow and preserve the one-height terrain contract.
	for spec in [[Rect2(6300,2530,660,160),Color("869389")],[Rect2(7300,2060,780,440),Color("b0b59a")],[Rect2(9560,260,430,350),Color("beb89a")]]:
		var field: Rect2 = spec[0]
		for x in range(int(field.position.x),int(field.end.x)-69,90):
			for y in range(int(field.position.y),int(field.end.y)-69,90):
				var tile := Rect2(x+3,y+3,78,78)
				var usable := true
				for barrier in barriers:
					if tile.intersects(barrier): usable = false; break
				if not usable: continue
				var c: Color = spec[1].lightened(0.02*sin(x*0.01+y*0.016))
				_quad(st,Vector3(tile.position.x,FLOOR_LIFT,tile.position.y),Vector3(tile.position.x,FLOOR_LIFT,tile.end.y),Vector3(tile.end.x,FLOOR_LIFT,tile.end.y),Vector3(tile.end.x,FLOOR_LIFT,tile.position.y),c)

static func _strand(st: SurfaceTool, centers: Array, radii: Array, tint: Color) -> void:
	var world_centers: Array = []
	var world_radii: Array = []
	for p in centers: world_centers.append(p*0.01)
	for radius in radii: world_radii.append(radius*0.01)
	Vegetation._taper(st,world_centers,world_radii,tint,7,0.12)

static func _block(st: SurfaceTool, area: Rect2, bottom: float, top: float, tint: Color) -> void:
	var points := [area.position,Vector2(area.end.x,area.position.y),area.end,Vector2(area.position.x,area.end.y)]
	var upper: Array[Vector3] = []
	for p in points: upper.append(Vector3(p.x,top,p.y))
	_quad(st,upper[0],upper[3],upper[2],upper[1],tint)
	for i in 4:
		var a: Vector3 = upper[i]
		var b: Vector3 = upper[(i+1)%4]
		_quad(st,Vector3(a.x,bottom,a.z),Vector3(b.x,bottom,b.z),b,a,tint.darkened(0.12+0.03*i))

static func _quad(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3,tint: Color) -> void:
	_tri(st,a,b,c,tint)
	_tri(st,a,c,d,tint)

static func _tri(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,tint: Color) -> void:
	Vegetation._tri(st,a*0.01,b*0.01,c*0.01,tint)
