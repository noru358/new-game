extends RefCounted
## Temple-only finish for the current court/cloister, installed after arena _ready.
## Mesh positions, normals, topology, shadows' footprints and all terrain are preserved.
const SURFACE = preload("res://game/temple_surface_sample.gdshader")
const PAVING := ["CourtAndStairCourses", "ProcessionalAndCloisterCourses"]
const STONE := ["SteppedSanctuary", "LowApronAndEntrance", "WeatheredCourtyardWalls", "WaterLandingRemains"]
const GROWTH := ["AttachedMoss", "CourtyardEdgeGrowth", "BankAndLandingGrowth"]

class MainlineScope:
	extends Node
	var arena: Node3D
	var original_environment: Environment
	var finished_environment: Environment
	var environment_node: WorldEnvironment
	var sun: DirectionalLight3D
	var original_sun: Dictionary
	var finished_sun: Dictionary
	var original_terrain: Material
	var finished_terrain: Material
	var mainline := true
	func _process(_delta: float) -> void:
		var active: bool = arena.temple_section == null or not arena.temple_section.in_garden
		if active == mainline: return
		mainline = active
		# Mainline finishing never changes the independently owned hidden room.
		arena.terrain_mesh.material_override = finished_terrain if active else original_terrain
		if is_instance_valid(environment_node): environment_node.environment = finished_environment if active else original_environment
		if is_instance_valid(sun):
			var state := finished_sun if active else original_sun
			for property in state: sun.set(property,state[property])

static func install(arena: Node3D) -> void:
	if arena.has_meta("temple_surface_sample") or OS.get_cmdline_user_args().has("--temple-surface-baseline"): return
	# Direct scene ownership guard: never finish a hidden room or another region.
	if arena.get_script().resource_path != "res://game/temple_circuit_run.gd": return
	var started := Time.get_ticks_usec()
	var scope := MainlineScope.new()
	scope.name = "TempleSurfaceMainlineScope"
	scope.arena = arena
	var materials: Array[ShaderMaterial] = []
	for kind in 5:
		var material := ShaderMaterial.new()
		material.shader = SURFACE
		material.set_shader_parameter("surface_kind", kind)
		materials.append(material)
	var counts := {"stone":0,"paving":0,"growth":0,"far_bank":0,"terrain":0}
	for mesh in arena.temple_sanctuary_root.find_children("*", "MeshInstance3D", true, false):
		var kind := -1
		if mesh.name in STONE: kind = 0; counts.stone += 1
		elif mesh.name in PAVING: kind = 1; counts.paving += 1
		elif mesh.name in GROWTH: kind = 2; counts.growth += 1
		elif mesh.get_parent().name == "FarBankGroves": kind = 4; counts.far_bank += 1
		if kind < 0: continue
		mesh.set_meta("temple_surface_original_mesh", mesh.mesh)
		mesh.set_meta("temple_surface_original_material", mesh.material_override)
		mesh.mesh = face_uvs(mesh.mesh)
		mesh.material_override = materials[kind]
	# One authoritative terrain mesh contains water, soil, slope and retaining faces.
	# The shader retains their original vertex-color identities and exact geometry.
	arena.terrain_mesh.set_meta("temple_surface_original_material", arena.terrain_mesh.material_override)
	scope.original_terrain = arena.terrain_mesh.material_override
	arena.terrain_mesh.material_override = materials[3]
	scope.finished_terrain = materials[3]
	counts.terrain = 1
	for child in arena.get_children():
		if child is WorldEnvironment:
			scope.environment_node = child
			scope.original_environment = child.environment
			var env: Environment = child.environment.duplicate()
			scope.finished_environment = env
			child.environment = env
			env.ambient_light_color = Color("e1eee8")
			env.ambient_light_energy = 0.56
			env.background_color = Color("9bbab4")
		elif child is DirectionalLight3D:
			scope.sun = child
			for property in ["light_color","light_energy","shadow_enabled","directional_shadow_max_distance","directional_shadow_mode"]:
				scope.original_sun[property] = child.get(property)
			child.light_color = Color("fff0d1")
			child.light_energy = 0.62
			child.shadow_enabled = true
			child.directional_shadow_max_distance = 45.0
			child.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			for property in scope.original_sun: scope.finished_sun[property] = child.get(property)
	arena.add_child(scope)
	scope._process(0.0)
	arena.set_meta("temple_surface_sample", counts)
	arena.set_meta("temple_surface_install_ms",float(Time.get_ticks_usec()-started)/1000.0)

static func _position_key(point: Vector3, normal: Vector3) -> String:
	return "%d,%d,%d/%d,%d,%d" % [roundi(point.x * 10000),roundi(point.y * 10000),roundi(point.z * 10000),roundi(normal.x * 1000),roundi(normal.y * 1000),roundi(normal.z * 1000)]

static func _leader(groups: Array[int], index: int) -> int:
	while groups[index] != index: index = groups[index]
	return index

static func _project(point: Vector3, normal: Vector3) -> Vector2:
	var n := normal.abs()
	if n.y >= n.x and n.y >= n.z: return Vector2(point.x, point.z)
	return Vector2(point.z, point.y) if n.x > n.z else Vector2(point.x, point.y)

static func face_uvs(source: ArrayMesh) -> ArrayMesh:
	# Connect coplanar triangles at their shared vertices; no diagonal wear stripes.
	# Physical UV2 extents keep a two-unit wear band independent of slab size.
	var result := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface).duplicate(true)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else vertices.size()
		var groups: Array[int] = []
		var owners := {}
		var ids: Array = []
		for start in range(0,count,3):
			var triangle := groups.size()
			groups.append(triangle)
			var current: Array[int] = []
			for offset in 3:
				var index := indices[start+offset] if not indices.is_empty() else start+offset
				current.append(index)
				var key := _position_key(vertices[index],normals[index])
				if owners.has(key): groups[_leader(groups,triangle)] = _leader(groups,owners[key])
				else: owners[key] = triangle
			ids.append(current)
		var bounds := {}
		for triangle in ids.size():
			var group := _leader(groups,triangle)
			for index in ids[triangle]:
				var point := _project(vertices[index],normals[index])
				if not bounds.has(group): bounds[group] = Rect2(point,Vector2.ZERO)
				else: bounds[group] = bounds[group].expand(point)
		var uv := PackedVector2Array()
		var extents := PackedVector2Array()
		uv.resize(vertices.size())
		extents.resize(vertices.size())
		for triangle in ids.size():
			var rect: Rect2 = bounds[_leader(groups,triangle)]
			var extent := Vector2(maxf(rect.size.x,0.001),maxf(rect.size.y,0.001))
			for index in ids[triangle]:
				uv[index] = (_project(vertices[index],normals[index])-rect.position) / extent
				extents[index] = extent
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_TEX_UV2] = extents
		result.add_surface_from_arrays(source.surface_get_primitive_type(surface),arrays)
	return result
