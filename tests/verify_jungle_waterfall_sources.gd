extends SceneTree
## Prepared source/mesh checks. Run only in an explicitly isolated QA project.
const Sources = preload("res://game/jungle_waterfall_sources.gd")
var checks := 0
var errors := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool,text: String) -> void:
	checks += 1
	if not ok:
		errors += 1
		printerr("FAIL: ",text)
func supported(node: MeshInstance3D,rock: TriangleMesh) -> bool:
	var spec: Dictionary = node.get_meta("source_spec")
	var heads: PackedVector3Array = node.get_meta("drop_head_points")
	for local in heads:
		var head := node.to_global(local)
		var probe := Vector2(head.x,head.z)*100.0-spec.out*0.55
		var hit := rock.intersect_segment(Vector3(probe.x,600,probe.y)*0.01,Vector3(probe.x,-10,probe.y)*0.01)
		if hit.is_empty() or absf(head.y-hit.position.y-0.002) > 0.008: return false
	return true
func _run() -> void:
	var data := OS.get_user_data_dir()
	var xdg := OS.get_environment("XDG_DATA_HOME")
	if not ("WaterfallSourcesV50" in data or OS.get_name() == "Linux" and xdg.is_absolute_path() and data.begins_with(xdg.trim_suffix("/")+"/")):
		printerr("FAIL: private WaterfallSourcesV50 userdata required")
		quit(1)
		return
	var scene = load("res://game/jungle_south_circuit.tscn").instantiate()
	scene.profile_save_prefix = "user://waterfall_source_fixture"
	scene.growth_save_prefix = scene.profile_save_prefix+"_growth"
	root.add_child(scene)
	var section = scene.temple_section
	var main_rock: TriangleMesh = scene.terrain_mesh.mesh.generate_triangle_mesh()
	var hidden_mesh: MeshInstance3D = section.hidden_visual_root.find_child("RockBanks",true,false)
	var hidden_rock: TriangleMesh = hidden_mesh.mesh.generate_triangle_mesh()
	var count := 0
	var ids := {}
	for node in section.find_children("*","MeshInstance3D",true,false):
		if not Sources.authored(node): continue
		count += 1
		var spec: Dictionary = node.get_meta("source_spec")
		check(not ids.has(spec.id),"unique source "+spec.id)
		ids[spec.id] = true
		var rock := main_rock if spec.field == "main" else hidden_rock
		check(supported(node,rock),"actual drop head touches rendered rock "+spec.id)
		var old := node.position
		node.position.y += 0.5
		check(not supported(node,rock),"raised detached-water negative control "+spec.id)
		node.position = old
		check(node.material_override.albedo_color == Sources.COLOR and node.material_override.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA,"same authored water material")
		var vertices: PackedVector3Array = node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for head in node.get_meta("drop_head_points"): check(vertices.has(head),"support metadata is an actual emitted mesh vertex")
		for foot in node.get_meta("drop_foot_points"):
			check(spec.receiver.grow(0.01).has_point(Vector2(foot.x,foot.z)*100.0),"drop ends in its receiving surface")
			if spec.field == "hidden":
				var in_water := false
				for area in scene.terrain.water_areas:
					if area.has_point(Vector2(foot.x,foot.z)*100.0): in_water = true
				check(in_water,"hidden receiving surface is existing real blocked water")
	check(count == 6,"four main and two hidden water nodes; no count growth")
	print("Waterfall sources: %d checks, %d failures. Native/human acceptance unverified." % [checks,errors])
	quit(0 if errors == 0 else 1)
