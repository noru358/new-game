extends SceneTree
var failures:=0
var checks:=0
func _initialize()->void: call_deferred("_run")
func check(ok:bool,note:String)->void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",note)
func _run()->void:
	var scene=load("res://game/deep_wetland_field.tscn").instantiate()
	var expected=scene.terrain.water_areas.duplicate(true)
	root.add_child(scene)
	for i in 4: await physics_frame
	check(scene.terrain.water_areas==expected,"art does not change water/navigation data")
	var trees:=0
	var triangles:=0
	for title in ["FarBankCanopyKit","InnerCanopyKit"]:
		var visual=scene.get_node(title)
		check(visual.get_child_count()==2,"two opaque batches per grove layer")
		for point in visual.get_meta("root_points"):
			trees+=1
			for i in 16:
				var sample:Vector2=point+Vector2.from_angle(TAU*i/16.0)*visual.get_meta("root_radius")
				var submerged:=false
				for water in scene.terrain.water_areas:
					if water.has_point(sample): submerged=true;break
				check(submerged,"root footprint remains in blocked water "+str(sample))
		for node in visual.get_children():
			check(node.mesh.get_surface_count()==1,"single surface per batch")
			check(node.material_override.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED,"no fading canopy")
			var arrays=node.mesh.surface_get_arrays(0)
			triangles+=arrays[Mesh.ARRAY_VERTEX].size()/3
			for normal in arrays[Mesh.ARRAY_NORMAL]: check(normal.is_finite() and normal.length()>0.99,"valid lighting normals")
	check(trees==33,"same authored groves, now grouped")
	print("Wetland canopy kit: ",trees," trees, ",triangles," triangles, ",checks," checks, ",failures," failures")
	scene.queue_free()
	for i in 4: await process_frame
	quit(1 if failures else 0)
