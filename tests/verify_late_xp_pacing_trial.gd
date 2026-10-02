extends SceneTree
func _initialize() -> void:
	var growth = load("res://game/run_growth.gd").new()
	var failures := 0
	for rank in range(1, 40):
		growth.level = rank
		if growth.next_xp() != 8 + 2 * (rank - 1): failures += 1
	growth.late_xp_slope_trial = true
	for rank in range(1, 7):
		growth.level = rank
		if growth.next_xp() != 8 + 2 * (rank - 1): failures += 1
	var total := 0
	var previous := 0
	for rank in range(1, 40):
		growth.level = rank
		var required: int = growth.next_xp()
		if required <= previous: failures += 1
		previous = required
		if rank <= 6: total += required
	if total != 78: failures += 1
	growth.free()
	print("Late XP opt-in: ", failures, " failures; first six choices and live baseline preserved")
	quit(1 if failures else 0)
