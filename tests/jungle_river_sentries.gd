extends RefCounted
## Southeast Asia -> existing jungle pass -> river detour entrance.
## One authored defender changes role; count, positions and all other groups stay.
## No random weights, terrain, timing, AI, progression or rewards are owned here.

const RIVER_ENTRANCE := Vector2(2820, 1930)


static func entries(route: String, at_crest: bool, trial_enabled: bool) -> Array:
	if route == "stairs":
		return [[Vector2(3970, 1010), TrainingEnemy.Role.BEAST], [Vector2(4020, 1330), TrainingEnemy.Role.LAMP]] if at_crest else [[Vector2(2890, 1100), TrainingEnemy.Role.BEAST], [Vector2(2960, 1180), TrainingEnemy.Role.LAMP]]
	if at_crest:
		return [[Vector2(4450, 1760), TrainingEnemy.Role.ZONE], [Vector2(4620, 1840), TrainingEnemy.Role.BEAST]]
	return [[RIVER_ENTRANCE, TrainingEnemy.Role.LAMP if trial_enabled else TrainingEnemy.Role.ZONE], [Vector2(2960, 2100), TrainingEnemy.Role.FRAGMENT]]


static func schedule(scene: Node, route: String, at_crest: bool, trial_enabled: bool) -> void:
	# Keep the existing scheduler and its clearance/reachability checks.
	for entry in entries(route, at_crest, trial_enabled):
		var point: Vector2 = entry[0]
		if scene.navigation.is_open(point, scene.ACTOR_CLEARANCE + 6.0) and scene.navigation.find_path(point, scene.player.global_position).size() >= 2:
			scene._schedule_spawn(point, entry[1], false)
