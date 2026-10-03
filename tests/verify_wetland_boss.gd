extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",note)
func _run() -> void:
	var sandbox := Node2D.new()
	root.add_child(sandbox)
	var player = load("res://game/player.tscn").instantiate()
	player.position = Vector2(550,500)
	sandbox.add_child(player)
	player.set_physics_process(false)
	var boss = load("res://game/wetland_boss.tscn").instantiate()
	boss.position = Vector2(300,500)
	boss.target = player
	boss.projectile_parent = sandbox
	boss.encounter_area = Rect2(0,0,1000,1000)
	sandbox.add_child(boss)
	boss.set_physics_process(false)
	boss.attack_cooldown = 0.0
	boss._beast_velocity(0.01)
	check(boss.pattern_active and boss.roots_remaining==3,"phase one starts three placements")
	boss._beast_velocity(0.01)
	check(boss.attacks_started==1,"one distinct warning placed")
	var zone = get_first_node_in_group("enemy_zones")
	zone.set_physics_process(false)
	check(zone.warning_time==EnemyZone.WARNING,"full visible warning before damage")
	var health: float = player.health
	zone._physics_process(0.1)
	check(player.health==health,"warning is harmless")
	var remaining: int = boss.roots_remaining
	boss.take_hit(10,Vector2.RIGHT,true)
	check(boss.pattern_active and boss.roots_remaining==remaining,"ordinary hit cannot cancel the cast")
	var fixed_point: Vector2 = zone.position
	player.position += Vector2(0,180)
	check(zone.position==fixed_point,"placed root does not chase the player")
	zone.warning_time=0
	zone._physics_process(0.02)
	check(player.health==health,"moving outside footprint avoids damage")
	player.position=fixed_point
	zone._physics_process(0.02)
	check(player.health<health,"active root damages a stationary player")
	boss.pause_for_boundary()
	check(not boss.encounter_active and boss.roots_remaining==remaining,"boundary keeps unfinished cast count")
	zone._physics_process(0.01)
	check(zone.is_queued_for_deletion(),"root cannot damage outside encounter")
	boss.resume_from_boundary()
	boss._beast_velocity(0.7)
	check(boss.roots_remaining==remaining-1,"reentry resumes remaining casts")
	boss._beast_velocity(0.7)
	boss._beast_velocity(0.6)
	check(not boss.pattern_active and boss.recovery_time>0,"completed sequence opens counter window")
	var previous: float = boss.health
	check(boss.take_direct_hit(10,Vector2.RIGHT,false),"direct hit recognizes counter window")
	check(is_equal_approx(previous-boss.health,13.0),"existing direct counter multiplier retained")
	boss.phase=2
	boss.recovery_time=0
	boss.attack_cooldown=0
	boss._beast_velocity(0.01)
	check(boss.roots_remaining==5,"phase two adds placements rather than untelegraphed hits")
	boss.roots_remaining=1
	player.velocity=Vector2(200,0)
	boss._place_root()
	check(boss.last_root_point.x>player.position.x, "last tell visibly anticipates continuing travel")
	var anticipated: Vector2=boss.last_root_point
	player.position+=Vector2(0,70)
	check(boss.last_root_point==anticipated,"anticipated tell remains fixed when player turns")
	boss.suspend_encounter()
	check(not boss.pattern_active and boss.roots_remaining==0,"fresh encounter resets candidate state")
	sandbox.queue_free()
	for i in 4: await process_frame
	print("Wetland boss candidate: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
