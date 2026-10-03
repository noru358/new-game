extends RefCounted
## One courtyard composition shared by legacy and circuit temple sections.
## Uses the existing opaque Southeast Asian stone kit; no new interactions.
const Data = preload("res://game/temple_garden_courtyard_data.gd")
const Kit = preload("res://game/temple_environment_kit.gd")
const FLOOR_TOP := 0.74

static func build(arena, _layout) -> Node3D:
	return load("res://game/temple_garden_environment.gd").new()._build(arena)

func _build(arena) -> Node3D:
	var root := Node3D.new()
	root.name = "TempleGardenCourtyard"
	var kit = Kit.new()
	for surface in [kit._stone, kit._paving, kit._growth]: surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in Data.WALL_SPECS.size():
		var wall: Dictionary = Data.WALL_SPECS[i]
		var area: Rect2 = wall.area
		var rear: bool = wall.place == "rear_cloister"
		# Masonry follows the authored collision envelope. Broad beds have a low
		# retaining rim and irregular garden stones, not a giant green solid box.
		if rear or wall.place == "low_boundary":
			_courses(kit, area, wall.height, i)
		elif wall.place != "water_bowl":
			_bed(kit, area, i, wall.place == "tended_bed")
	# Human-scale columns survive only on the rear perimeter. Broken interior
	# plinths never stand in front of a legal actor/tell at more than21 units.
	for point in [Vector2(5622,1700), Vector2(5622,1450), Vector2(5622,710), Vector2(6280,102), Vector2(6960,102), Vector2(7520,102), Vector2(8170,102)]:
		var area := Rect2(point - Vector2(19,19), Vector2(38,38))
		kit._pier(area, 0.0, 115.0, int(point.x) % 13)
	# Entry pavement has a deliberate axis; the managed walk retains straight
	# paired course strips. The south/east bank gets fewer broken paving groups.
	for spec in [
		[Rect2(5680,1750,500,36), 0], [Rect2(6230,470,32,1170), 1],
		[Rect2(6350,470,32,1170), 2], [Rect2(6600,466,1130,30), 3],
		[Rect2(6600,606,1130,30), 4], [Rect2(7950,740,34,580), 5],
		[Rect2(8120,400,300,28), 6], [Rect2(8120,570,300,28), 7],
	]:
		for piece in arena.terrain.surface_areas({"area":spec[0], "cutouts": _blocked()}):
			kit._paving_field(piece,-0.11,Color("c4c1a5"),82.0,60.0,spec[1])
	for point in [Vector2(6410,1560),Vector2(6710,1500),Vector2(7090,1550),Vector2(7490,1500),Vector2(7850,1530),Vector2(8040,1080),Vector2(8200,700)]:
		var area := Rect2(point - Vector2(38,23),Vector2(76,46))
		for piece in arena.terrain.surface_areas({"area":area,"cutouts":_blocked()}): kit._block(kit._paving,piece,0.5,0.73,Color("b2b69a"),int(point.x)%11,0.16)
	_dry_channel(kit)
	_pond_rim(kit)
	# Small noninteractive stone water bowl beside the existing reward altar.
	# At curb height it is a quiet garden object rather than another sanctuary.
	_bowl(kit,Vector2(8225,345))
	kit._finish_batch(root,kit._stone,"ClippedMasonryAndGardenStones",0,false)
	kit._finish_batch(root,kit._paving,"CoursesAndBrokenWaterChannel",1,false)
	kit._finish_batch(root,kit._growth,"RootsAndLowGardenGrowth",2,false)
	root.set_meta("region_hierarchy",["동남아","큰 폐사원","회랑 뒤 안뜰"])
	root.set_meta("field_bounds",Data.Garden.FIELD_BOUNDS)
	root.set_meta("wall_specs",Data.WALL_SPECS)
	root.set_meta("floor_lift_max",FLOOR_TOP)
	root.set_meta("story_places",["collapsed_cloister","tended_walk","rooted_bank","garden_stone"])
	root.set_meta("resource_counts",{"mesh_instances":root.get_child_count(),"vertices":kit._vertex_counts.reduce(func(a,b):return a+b,0),"masonry_pieces":kit._stone_blocks,"paving_pieces":kit._paving_slabs,"leaf_groups":kit._leaf_groups,"root_strands":kit._root_strands})
	return root

func _blocked() -> Array:
	var result: Array = [Data.Garden.POND]
	for wall in Data.WALL_SPECS: result.append(wall.area)
	return result

func _courses(kit, area: Rect2, height: float, seed: int) -> void:
	var horizontal := area.size.x > area.size.y
	var span := area.size.x if horizontal else area.size.y
	var cursor := 0.0
	var index := 0
	while cursor < span:
		var length := minf(150.0 if seed%2==0 else 122.0,span-cursor)
		var piece := Rect2(area.position+Vector2(cursor,0),Vector2(length,area.size.y)) if horizontal else Rect2(area.position+Vector2(0,cursor),Vector2(area.size.x,length))
		# Never exceed the collision envelope, even at coping/column bases.
		kit._block(kit._stone,piece.grow(-0.6),0.0,height-0.6,Color("9baa93").lightened((index%3)*0.02),seed+index,2.0)
		cursor += length
		index += 1

func _bed(kit, area: Rect2, seed: int, tended: bool) -> void:
	# Closed blocked bed: a recessed soil surface, low stone rim, then roots
	# and broad leaf silhouettes all confined to the same collision footprint.
	kit._block(kit._stone,area.grow(-0.8),0.0,6.0,Color("647e61"),seed,0.6)
	for rim in [Rect2(area.position,Vector2(area.size.x,10)),Rect2(area.position.x,area.end.y-10,area.size.x,10),Rect2(area.position.x,area.position.y+10,10,area.size.y-20),Rect2(area.end.x-10,area.position.y+10,10,area.size.y-20)]:
		kit._block(kit._stone,rim.grow(-0.5),0.0,20.8,Color("a3ad91"),seed,1.0)
	var rows := maxi(2,int(area.size.y/100))
	var columns := maxi(1,int(area.size.x/120))
	for row in rows:
		for column in columns:
			var center := area.position+Vector2((column+0.5)*area.size.x/columns,(row+0.5)*area.size.y/rows)
			var stone := Rect2(center-Vector2(22,17),Vector2(44,34))
			kit._block(kit._stone,stone,6.1,18.0+(row%2),Color("8e9c81"),seed+row+column,2.2)
			var base := Vector3(center.x+13,6.4,center.y+7)
			kit._moss_patch(base,Vector2(22,16),area.grow(-12),seed+row+column,0.4)
			kit._leaf_group(base,area.grow(-12),seed+row+column,2.4)
			if not tended:
				var roots: Array[Vector3] = [Vector3(center.x-26,7,center.y-31),Vector3(center.x-10,15,center.y-4),Vector3(center.x+30,7,center.y+21)]
				kit._root(roots,3.0,area.grow(-12),Color("938766"))

func _dry_channel(kit) -> void:
	for i in range(Data.DRY_CHANNEL.size()-1):
		var a: Vector2 = Data.DRY_CHANNEL[i]
		var b: Vector2 = Data.DRY_CHANNEL[i+1]
		var horizontal := a.y==b.y
		var area := Rect2(a.min(b)-Vector2(0,9) if horizontal else a.min(b)-Vector2(9,0), Vector2(absf(b.x-a.x),18) if horizontal else Vector2(18,absf(b.y-a.y)))
		# Segments stop9 units short at bends: open fractures with flat ground
		# between them, not intersecting coplanar strips or an invented obstacle.
		area = area.grow(-1.0)
		if horizontal: area.position.x+=9; area.size.x-=18
		else: area.position.y+=9; area.size.y-=18
		if not area.has_area():continue
		kit._block(kit._paving,area,0.46,0.72,Color("6a7866"),i,0.2)
		for side in [-1,1]:
			var lip := Rect2(area.position+Vector2(0,side*12),Vector2(area.size.x,4)) if horizontal else Rect2(area.position+Vector2(side*12,0),Vector2(4,area.size.y))
			kit._block(kit._paving,lip,0.5,0.74,Color("b2b89e"),i+3,0.8)

func _pond_rim(kit) -> void:
	var pond: Rect2 = Data.Garden.POND
	for area in [Rect2(pond.position,Vector2(pond.size.x,10)),Rect2(pond.position.x,pond.end.y-10,pond.size.x,10),Rect2(pond.position.x,pond.position.y+10,10,220),Rect2(pond.position.x,pond.position.y+280,10,pond.size.y-290),Rect2(pond.end.x-10,pond.position.y+10,10,pond.size.y-20)]:
		kit._block(kit._stone,area.grow(-0.3),1.1,18.0,Color("afb79a"),int(area.position.x)%5,1.6)
	# Lily leaves stay within blocked water, avoiding false cover on the path.
	for point in [Vector2(6920,990),Vector2(7000,1025),Vector2(7380,1220),Vector2(7460,1180)]:
		kit._moss_patch(Vector3(point.x,1.2,point.y),Vector2(26,18),pond.grow(-35),int(point.x)%7,0.6)

func _bowl(kit, point: Vector2) -> void:
	var area := Rect2(point-Vector2(24,24),Vector2(48,48))
	kit._block(kit._stone,area,0.0,8.0,Color("aeb69c"),4,1.5)
	for rim in [Rect2(area.position,Vector2(48,7)),Rect2(area.position.x,area.end.y-7,48,7),Rect2(area.position.x,area.position.y+7,7,34),Rect2(area.end.x-7,area.position.y+7,7,34)]:
		kit._block(kit._stone,rim,8.1,21.0,Color("c4c5a5"),6,1.3)

static func build_entry(arena, layout) -> Node3D:
	var root := Node3D.new()
	root.name = "TempleGardenCloisterHint"
	var kit = Kit.new()
	kit._paving.begin(Mesh.PRIMITIVE_TRIANGLES)
	var portal: Vector2 = layout.ENTRY_TRIGGER.get_center()
	var direction: Vector2 = layout.RETURN_POINT.direction_to(portal)
	var side := direction.orthogonal() * 39.0
	var cuts: Array = arena.terrain.barriers()
	# The old vestibule floor is higher than the shadow-safe hint. Omit those
	# surfaces rather than burying a new course or raising it through the actor.
	for floor in arena.terrain.floor_areas:
		if floor.get("height",0.7)>arena.terrain.height_at(floor.area.get_center())+0.72:cuts.append(floor.area)
	for step in 4:
		var point: Vector2 = portal - direction * (step * 52.0)
		for offset in [-1,1]:
			var area := Rect2(point+side*offset-Vector2(24,15),Vector2(48,30))
			for piece in arena.terrain.surface_areas({"area":area,"cutouts":cuts}):
				var height: float = arena.terrain.height_at(piece.get_center())
				kit._block(kit._paving,piece,height+0.55,height+0.72,Color("bdc2a2"),step,0.05)
	kit._finish_batch(root,kit._paving,"BrokenCloisterCourses",1,false)
	return root
