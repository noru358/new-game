class_name ArenaNavigation
extends RefCounted

const CELL_SIZE := 32.0
const DEFAULT_ARENA_SIZE := Vector2(2400, 1400)
const ENEMY_RADIUS := 17.0

var grid := AStarGrid2D.new()
var grid_size := Vector2i(75, 44)
var obstacles: Array[Vector3] = []
var rectangular_obstacles: Array[Dictionary] = []


func setup(props: Array, arena_size: Vector2 = DEFAULT_ARENA_SIZE) -> void:
	obstacles.clear()
	rectangular_obstacles.clear()
	grid_size = Vector2i(ceili(arena_size.x / CELL_SIZE), ceili(arena_size.y / CELL_SIZE))
	grid.region = Rect2i(Vector2i.ZERO, grid_size)
	grid.cell_size = Vector2.ONE * CELL_SIZE
	grid.offset = Vector2.ONE * CELL_SIZE * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for prop in props:
		if prop is ViewProp:
			obstacles.append(Vector3(prop.global_position.x, prop.global_position.y, prop.footprint_radius))
		elif prop is TempleBlock:
			rectangular_obstacles.append(prop.navigation_obstacle())
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var point := Vector2(float(x) + 0.5, float(y) + 0.5) * CELL_SIZE
			if not is_open(point, ENEMY_RADIUS + 20.0):
				grid.set_point_solid(Vector2i(x, y), true)


func is_open(point: Vector2, clearance: float = ENEMY_RADIUS) -> bool:
	for obstacle in obstacles:
		if point.distance_to(Vector2(obstacle.x, obstacle.y)) < obstacle.z + clearance:
			return false
	for obstacle in rectangular_obstacles:
		var local_point: Vector2 = (point - obstacle.center).rotated(-obstacle.angle)
		var half: Vector2 = obstacle.half_size + Vector2.ONE * clearance
		if absf(local_point.x) < half.x and absf(local_point.y) < half.y:
			return false
	return true


func has_clear_path(from: Vector2, to: Vector2) -> bool:
	var segment := to - from
	var length_squared := segment.length_squared()
	for obstacle in obstacles:
		var center := Vector2(obstacle.x, obstacle.y)
		var clearance := obstacle.z + ENEMY_RADIUS + 2.0
		var start_offset := from - center
		# An enemy touching a ruin can be inside this padded clearance.
		# Let it move outward so the route finder can escape the contact edge.
		if start_offset.length_squared() < clearance * clearance and start_offset.dot(segment) >= 0.0:
			continue
		var fraction := clampf((center - from).dot(segment) / maxf(length_squared, 1.0), 0.0, 1.0)
		if center.distance_to(from + segment * fraction) < clearance:
			return false
	for obstacle in rectangular_obstacles:
		var local_from: Vector2 = (from - obstacle.center).rotated(-obstacle.angle)
		var local_to: Vector2 = (to - obstacle.center).rotated(-obstacle.angle)
		var expanded := Rect2(-obstacle.half_size, obstacle.half_size * 2.0).grow(ENEMY_RADIUS + 2.0)
		if expanded.has_point(local_from) and local_from.dot(local_to - local_from) >= 0.0:
			continue
		if _segment_hits_rect(local_from, local_to, expanded):
			return false
	return true


func _segment_hits_rect(from: Vector2, to: Vector2, area: Rect2) -> bool:
	var delta := to - from
	var enter := 0.0
	var leave := 1.0
	for axis in range(2):
		var start: float = from.x if axis == 0 else from.y
		var motion: float = delta.x if axis == 0 else delta.y
		var minimum: float = area.position.x if axis == 0 else area.position.y
		var maximum: float = area.end.x if axis == 0 else area.end.y
		if absf(motion) < 0.0001:
			if start < minimum or start > maximum:
				return false
		else:
			var first := (minimum - start) / motion
			var last := (maximum - start) / motion
			enter = maxf(enter, minf(first, last))
			leave = minf(leave, maxf(first, last))
			if enter > leave:
				return false
	return true


func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var start := _nearest_open(_cell_at(from), from)
	var goal := _nearest_open(_cell_at(to), to)
	if start.x < 0 or goal.x < 0:
		return PackedVector2Array()
	return grid.get_point_path(start, goal)


func _cell_at(point: Vector2) -> Vector2i:
	return Vector2i(
		clampi(floori(point.x / CELL_SIZE), 0, grid_size.x - 1),
		clampi(floori(point.y / CELL_SIZE), 0, grid_size.y - 1)
	)


func _nearest_open(cell: Vector2i, world_point: Vector2) -> Vector2i:
	for radius in range(6):
		var best := Vector2i(-1, -1)
		var best_distance := 9999
		for y in range(maxi(0, cell.y - radius), mini(grid_size.y - 1, cell.y + radius) + 1):
			for x in range(maxi(0, cell.x - radius), mini(grid_size.x - 1, cell.x + radius) + 1):
				var candidate := Vector2i(x, y)
				if grid.is_point_solid(candidate):
					continue
				# A nearby grid cell across a cliff is not a valid start or goal.
				# Otherwise the first waypoint asks the enemy to walk into the wall.
				if not has_clear_path(world_point, grid.get_point_position(candidate)):
					continue
				var distance := (candidate - cell).length_squared()
				if distance < best_distance:
					best = candidate
					best_distance = distance
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)
