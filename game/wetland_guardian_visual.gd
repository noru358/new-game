extends RefCounted
static func build(arena: Node3D, parent: Node3D, figure_name: String = "BossFigure") -> void:
	var figure := Node3D.new()
	figure.name=figure_name
	parent.add_child(figure)
	var mesh := CylinderMesh.new()
	mesh.radial_segments=7
	mesh.top_radius=0.63
	mesh.bottom_radius=0.81
	mesh.height=1.65
	var head := MeshInstance3D.new()
	head.name="FaceCore"
	head.mesh=mesh
	head.position.y=1.0
	head.material_override=arena._material(Color("8f9d7c"))
	figure.add_child(head)
	for x in [-0.26,0.26]:
		face_detail(arena,figure,Vector3(x,1.27,0.59),Vector3(0.27,0.13,0.15),Color("2d443a"))
		face_detail(arena,figure,Vector3(x,1.41,0.62),Vector3(0.37,0.12,0.18),Color("acb28e"))
	face_detail(arena,figure,Vector3(0,1.08,0.68),Vector3(0.15,0.39,0.23),Color("a5ae8c"))
	face_detail(arena,figure,Vector3(0,0.78,0.64),Vector3(0.38,0.09,0.15),Color("435846"))
	for x in [-0.6,0.6]:
		face_detail(arena,figure,Vector3(x,0.18,0.05),Vector3(0.40,0.25,0.75),Color("536d52"))
static func face_detail(arena: Node3D, parent: Node3D, at: Vector3, size: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size=size
	node.mesh=mesh
	node.position=at
	node.material_override=arena._material(color)
	parent.add_child(node)

static func update_roots(arena: Node3D, boss, root_visuals: Dictionary) -> void:
	for zone in arena.get_tree().get_nodes_in_group("enemy_zones"):
		if not arena.simulation.is_ancestor_of(zone) or not is_instance_valid(boss) or zone.source != boss: continue
		if not root_visuals.has(zone):
			var cluster := Node3D.new()
			for offset in [Vector2(-32,-10),Vector2(27,-24),Vector2(10,34)]:
				var spike := MeshInstance3D.new()
				var mesh := CylinderMesh.new()
				mesh.top_radius=0.02
				mesh.bottom_radius=0.11
				mesh.height=0.8
				mesh.radial_segments=5
				spike.mesh=mesh
				spike.position=Vector3(offset.x*0.01,0.4,offset.y*0.01)
				spike.material_override=arena._material(Color("718759"))
				cluster.add_child(spike)
			cluster.position=arena.terrain.world_point(zone.global_position)
			arena.add_child(cluster)
			root_visuals[zone]=cluster
		root_visuals[zone].visible=zone.warning_time<=0.0
	for zone in root_visuals.keys():
		if not is_instance_valid(zone) or zone.is_queued_for_deletion():
			root_visuals[zone].queue_free()
			root_visuals.erase(zone)
