class_name ArenaNavigation
extends RefCounted

const CELL_SIZE := 32.0
const GRID_SIZE := Vector2i(75, 44)
const ENEMY_RADIUS := 17.0

var grid := AStarGrid2D.new()
var obstacles: Array[Vector3] = []


func setup(props: Array) -> void:
	obstacles.clear()
	grid.region = Rect2i(Vector2i.ZERO, GRID_SIZE)
	grid.cell_size = Vector2.ONE * CELL_SIZE
	grid.offset = Vector2.ONE * CELL_SIZE * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for prop in props:
		obstacles.append(Vector3(prop.global_position.x, prop.global_position.y, prop.footprint_radius))
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			var point := Vector2(float(x) + 0.5, float(y) + 0.5) * CELL_SIZE
			for obstacle in obstacles:
				if point.distance_to(Vector2(obstacle.x, obstacle.y)) < obstacle.z + ENEMY_RADIUS + 20.0:
					grid.set_point_solid(Vector2i(x, y), true)
					break


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
	return true


func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var start := _nearest_open(_cell_at(from))
	var goal := _nearest_open(_cell_at(to))
	if start.x < 0 or goal.x < 0:
		return PackedVector2Array()
	return grid.get_point_path(start, goal)


func _cell_at(point: Vector2) -> Vector2i:
	return Vector2i(
		clampi(floori(point.x / CELL_SIZE), 0, GRID_SIZE.x - 1),
		clampi(floori(point.y / CELL_SIZE), 0, GRID_SIZE.y - 1)
	)


func _nearest_open(cell: Vector2i) -> Vector2i:
	for radius in range(6):
		var best := Vector2i(-1, -1)
		var best_distance := 9999
		for y in range(maxi(0, cell.y - radius), mini(GRID_SIZE.y - 1, cell.y + radius) + 1):
			for x in range(maxi(0, cell.x - radius), mini(GRID_SIZE.x - 1, cell.x + radius) + 1):
				var candidate := Vector2i(x, y)
				if grid.is_point_solid(candidate):
					continue
				var distance := (candidate - cell).length_squared()
				if distance < best_distance:
					best = candidate
					best_distance = distance
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)
