extends SceneTree


func _initialize() -> void:
	var enemy := TrainingEnemy.new()
	var growth := RunGrowth.new()
	growth.on_enemy_defeated(enemy)
	enemy.max_health = 220.0
	growth.on_enemy_defeated(enemy)
	var valid := growth.xp == 4 and enemy.currency_reward() == 1
	enemy.role = TrainingEnemy.Role.BEAST
	enemy.max_health = 1.0
	valid = valid and enemy.xp_reward() == 4 and enemy.currency_reward() == 2
	enemy.free()
	growth.free()
	if valid:
		print("Enemy reward verification passed: HP tuning does not change XP or currency")
	else:
		printerr("FAIL: enemy rewards changed with health")
	quit(0 if valid else 1)
