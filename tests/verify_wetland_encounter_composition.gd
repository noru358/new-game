extends SceneTree
func _initialize()->void:call_deferred("_run")
func _run()->void:
 var kit=preload("res://game/wetland_encounter_composition.gd")
 var failures:=0
 var checks:=0
 for point in [Vector2(1350,2140),Vector2(2350,1510),Vector2(1600,980),Vector2(3800,970),Vector2(4010,1730)]:
  for time in [45.0,90.0,135.0,165.0,195.0,220.0]:
   for phase in [{},{"weights":[35.0,20.0,15.0,10.0,20.0]}]:
    var weights=kit.weights(point,time,phase)
    var total:=0.0
    for value in weights:
     total+=value
     checks+=1
     if value<0:failures+=1
    checks+=1
    if not is_equal_approx(total,100.0):failures+=1
 var open_bank=kit.place_weights(Vector2(2350,1510))
 var causeway=kit.place_weights(Vector2(3800,970))
 var offering=kit.place_weights(Vector2(4010,1730))
 if open_bank[3]<=causeway[3] or causeway[1]<=open_bank[1] or offering[4]<=open_bank[4]:failures+=1
 var prefix="user://wetland_roles_%d" % Time.get_ticks_usec()
 var profile:=RunProfile.new()
 profile.save_prefix=prefix
 profile.settle("fixture-temple","SUCCESS",0)
 profile.settle("fixture-jungle","SUCCESS",0,RunProfile.JUNGLE_REGION)
 var scene=load("res://game/deep_wetland_run.tscn").instantiate()
 scene.profile_save_prefix=prefix
 scene.growth_save_prefix=prefix+"_unlocks"
 root.add_child(scene)
 scene.set_physics_process(false)
 for i in 3:await physics_frame
 if not scene.place_encounter_trial:failures+=1
 scene.place_encounter_trial=true
 scene.run_time=44.99
 if scene._roll_role()!=TrainingEnemy.Role.FRAGMENT:failures+=1
 scene.run_time=245.0
 scene.boss_spawned=true
 if scene._roll_role()!=TrainingEnemy.Role.FRAGMENT:failures+=1
 scene.queue_free()
 for i in 4:await process_frame
 print("Wetland place composition: ",checks," checks, ",failures," failures; wetland candidate default; no strength/fun verdict")
 quit(1 if failures else 0)
