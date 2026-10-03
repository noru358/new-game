extends SceneTree
func _initialize()->void:call_deferred("_run")
func _run()->void:
 var scene=load("res://game/deep_wetland_field.tscn").instantiate()
 var before=scene.terrain.water_areas.duplicate(true)
 root.add_child(scene)
 for i in 4:await physics_frame
 var node=scene.get_node("WaterbankVegetation")
 var failures:=0
 if before!=scene.terrain.water_areas:failures+=1
 if node.mesh.get_surface_count()!=1:failures+=1
 if node.material_override.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:failures+=1
 var points:Array=node.get_meta("water_footprints")
 if points.size()<40:failures+=1
 var kit=preload("res://game/wetland_waterbank_details.gd")
 for point in points:
  if not kit._wet(scene,point.point,point.radius):failures+=1
 var arrays:Array=node.mesh.surface_get_arrays(0)
 for point in arrays[Mesh.ARRAY_VERTEX]:
  if point.y<0.014 or point.y>0.40:failures+=1
 print("Waterbank details: ",points.size()," wet footprints, ",arrays[Mesh.ARRAY_VERTEX].size()/3," triangles, ",failures," failures")
 scene.queue_free()
 for i in 3:await process_frame
 quit(1 if failures else 0)
