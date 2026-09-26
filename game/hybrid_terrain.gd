class_name HybridTerrain
extends RefCounted

const SIZE := Vector2(2400, 2000)
const SCALE := 0.01
const COURT := Rect2(600, 500, 1200, 1000)
const TERRACE := Rect2(1150, 800, 450, 400)

# One surface per ground position. Geometry, height and blocked edges share these records.
var plateaus := [
	{"area": COURT, "height": 160.0, "base": 0.0, "name": "중정", "openings": {"north": [800.0, 1060.0], "south": [800.0, 1060.0], "east": [1050.0, 1310.0]}},
	{"area": TERRACE, "height": 320.0, "base": 160.0, "name": "테라스", "openings": {"west": [900.0, 1100.0]}}
]
var ramps := [
	{"area": Rect2(800, 200, 260, 300), "axis": 1, "from": 0.0, "to": 160.0, "name": "북쪽 경사로"},
	{"area": Rect2(800, 1500, 260, 300), "axis": 1, "from": 160.0, "to": 0.0, "name": "남쪽 경사로"},
	{"area": Rect2(1800, 1050, 300, 260), "axis": 0, "from": 160.0, "to": 0.0, "name": "측면 경사로"},
	{"area": Rect2(850, 900, 300, 200), "axis": 0, "from": 160.0, "to": 320.0, "name": "테라스 경사로"}
]

func ramp_height(ramp: Dictionary, point: Vector2) -> float:
	var area: Rect2 = ramp.area
	var fraction: float = (point[ramp.axis] - area.position[ramp.axis]) / area.size[ramp.axis]
	return lerpf(ramp.from, ramp.to, clampf(fraction, 0.0, 1.0))

func height_at(point: Vector2) -> float:
	for ramp in ramps:
		if ramp.area.has_point(point):
			return ramp_height(ramp, point)
	if TERRACE.has_point(point):
		return 320.0
	return 160.0 if COURT.has_point(point) else 0.0

func surface_name(point: Vector2) -> String:
	for ramp in ramps:
		if ramp.area.has_point(point):
			return ramp.name
	return "테라스" if TERRACE.has_point(point) else "중정" if COURT.has_point(point) else "저지대"

func world_point(point: Vector2, lift: float = 0.0) -> Vector3:
	return Vector3(point.x, height_at(point) + lift, point.y) * SCALE

func barriers() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for plateau in plateaus:
		var a: Rect2 = plateau.area
		for side in ["north", "south", "west", "east"]:
			var horizontal: bool = side == "north" or side == "south"
			var start: float = a.position.x if horizontal else a.position.y
			var end: float = a.end.x if horizontal else a.end.y
			var fixed: float = (a.position.y if side == "north" else a.end.y) if horizontal else (a.position.x if side == "west" else a.end.x)
			var opening: Array = plateau.openings.get(side, [])
			var spans: Array = [[start, end]] if opening.is_empty() else [[start, opening[0]], [opening[1], end]]
			for span in spans:
				result.append(Rect2(span[0], fixed - 5, span[1] - span[0], 10) if horizontal else Rect2(fixed - 5, span[0], 10, span[1] - span[0]))
	for ramp in ramps:
		var a: Rect2 = ramp.area
		if ramp.axis == 0:
			result.append(Rect2(a.position.x, a.position.y - 5, a.size.x, 10))
			result.append(Rect2(a.position.x, a.end.y - 5, a.size.x, 10))
		else:
			result.append(Rect2(a.position.x - 5, a.position.y, 10, a.size.y))
			result.append(Rect2(a.end.x - 5, a.position.y, 10, a.size.y))
	for a in [Rect2(0, 0, 2400, 12), Rect2(0, 1988, 2400, 12), Rect2(0, 0, 12, 2000), Rect2(2388, 0, 12, 2000)]:
		result.append(a)
	return result
