extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _run() -> void:
	for width in [100.0, 50.0]:
		var props := []
		for area in [Rect2(0, 0, 760, 1200), Rect2(760 + width, 0, 840 - width, 1200)]:
			var block := TempleBlock.new()
			root.add_child(block)
			block.setup(area, false)
			props.append(block)
		var nav := ArenaNavigation.new()
		nav.agent_radius = 30
		nav.strict_contact_escape = true
		nav.setup(props, Vector2(1600, 1200))
		var start := Vector2(760 + width * 0.5, 200)
		var finish := Vector2(start.x, 1000)
		var path := nav.find_path(start, finish)
		if width == 100:
			check(nav.is_open(start, 30), "100-wide corridor fits a 60-diameter actor")
			check(path.size() > 1, "physically valid corridor attaches to path grid")
			for point in path: check(nav.is_open(point, 32), "route keeps actor radius plus shot/path safety margin")
			for i in range(1, path.size()): check(nav.has_clear_path(path[i - 1], path[i]), "all route segments respect walls")
		else:
			check(not nav.is_open(start, 30) and path.is_empty(), "50-wide corridor stays closed to a 60-diameter actor")
		for block in props: block.queue_free()
		await process_frame
	var block := TempleBlock.new()
	root.add_child(block)
	block.setup(Rect2(200, 200, 200, 200), false)
	var edge_nav := ArenaNavigation.new()
	edge_nav.agent_radius = 30
	edge_nav.strict_contact_escape = true
	edge_nav.setup([block], Vector2(800, 800))
	for pair in [[Vector2(432, 300), Vector2.RIGHT], [Vector2(168, 300), Vector2.LEFT], [Vector2(300, 432), Vector2.DOWN], [Vector2(300, 168), Vector2.UP]]:
		var point: Vector2 = pair[0]
		var outward: Vector2 = pair[1]
		check(edge_nav.has_clear_path(point, point + outward * 64), "exact padded boundary permits outward escape")
		check(not edge_nav.has_clear_path(point, point - outward * 64), "exact padded boundary blocks inward crossing")
	block.queue_free()
	await process_frame
	print("Navigation physical-clearance corridor: ", failures, " failures")
	quit(1 if failures else 0)
