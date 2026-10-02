extends "res://game/temple_section.gd"
func _build_garden() -> void: pass
func _tick_garden(_delta: float) -> void: pass
func enter_garden() -> void: pass
func leave_garden() -> void: pass
func excludes_ambient_spawn(point: Vector2) -> bool:
	return not layout.MAIN_BOUNDS.has_point(point) or (boss_ready and boss_area.grow(100).has_point(point))
func _clear_arena_intruders() -> void:
	for actor in arena.actors.keys():
		if is_instance_valid(actor) and actor is TrainingEnemy and actor != arena.boss and boss_area.grow(100).has_point(actor.global_position): _remove_actor(actor)
	for group in ["enemy_bolts","enemy_zones"]:
		for node in get_tree().get_nodes_in_group(group):
			if arena.simulation.is_ancestor_of(node) and node.get("source") != arena.boss: node.queue_free()
func tick(delta: float) -> void:
	super.tick(delta)
	if destination_label != null: destination_label.text="침수 성소 · 석면 수호자\n"+("경계 진입 시 교전" if boss_ready else "4분 이후 접근하여 교전")
func _update_hud() -> void:
	section_hud.text="안쪽 성소 · 석면 수호자" if not boss_ready else "석면 수호자 · 안쪽 성소에서 교전"
