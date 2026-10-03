extends Node
## Only COMPANION branch uses this short-lived targeting instruction; never saved.
const META:=&"companion_focus_target"
const DURATION:=2.0
var arena
var remaining:=0.0
var target_ref:WeakRef
var pending:Array[Dictionary]=[]
var committed_sequence:=-1
var pending_sequence:=-1
var marker:MeshInstance3D
var marker_target_id:=0
func setup(owner_arena)->void:
	arena=owner_arena
	name="CompanionFocus"
	arena.player.basic_target_struck.connect(_on_hit)
func _ready()->void:
	marker=MeshInstance3D.new()
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in [Vector3(-0.10,0.07,0),Vector3(0,-0.10,0),Vector3(0.10,0.07,0)]:st.add_vertex(p)
	marker.mesh=st.commit()
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color("b8f2dd")
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	marker.material_override=material
	marker.visible=false
	add_child(marker)
func _on_hit(enemy:TrainingEnemy)->void:
	if not _valid(enemy) or committed_sequence==arena.player.attack_sequence:return
	if pending_sequence!=arena.player.attack_sequence:
		pending.clear()
		pending_sequence=arena.player.attack_sequence
	var offset:Vector2=enemy.global_position-arena.player.global_position
	pending.append({"ref":weakref(enemy),"alignment":offset.normalized().dot(arena.player.attack_direction),"distance":offset.length_squared(),"x":enemy.global_position.x,"y":enemy.global_position.y,"role":int(enemy.role)})
func _valid(enemy)->bool:
	if not is_instance_valid(enemy) or not enemy is TrainingEnemy or enemy.is_queued_for_deletion() or enemy.health<=0 or not enemy.is_in_group("training_enemies") or not arena.simulation.is_ancestor_of(enemy):return false
	if enemy is GateBoss and (not enemy.encounter_active or (enemy.encounter_area.has_area() and not enemy.encounter_area.has_point(arena.player.global_position))):return false
	return true
func _better(a:Dictionary,b:Dictionary)->bool:
	if b.is_empty():return true
	if not is_equal_approx(a.alignment,b.alignment):return a.alignment>b.alignment
	if not is_equal_approx(a.distance,b.distance):return a.distance<b.distance
	if not is_equal_approx(a.x,b.x):return a.x<b.x
	if not is_equal_approx(a.y,b.y):return a.y<b.y
	return a.role<b.role
func _clear()->void:
	target_ref=null
	remaining=0.0
	marker_target_id=0
	if is_instance_valid(arena.player) and arena.player.has_meta(META):arena.player.remove_meta(META)
	if is_instance_valid(marker):marker.hide()
func _physics_process(delta:float)->void:
	if arena.run_ended or arena.player.health<=0 or (arena.temple_section!=null and arena.temple_section.retry_pending):
		pending.clear()
		_clear()
		return
	if arena.paused or get_tree().paused:return
	if not pending.is_empty():
		var best:TrainingEnemy
		var best_record:Dictionary={}
		for record in pending:
			var enemy=record.ref.get_ref()
			if _valid(enemy) and _better(record,best_record):
				best=enemy
				best_record=record
		pending.clear()
		if best!=null:
			committed_sequence=pending_sequence
			target_ref=weakref(best)
			arena.player.set_meta(META,target_ref)
			remaining=DURATION
	if target_ref!=null and not arena.player.has_meta(META):
		_clear()
		return
	var target=target_ref.get_ref() if target_ref!=null else null
	if not _valid(target):
		_clear()
		return
	remaining=maxf(0.0,remaining-delta)
	if remaining<=0:
		_clear()
		return
	marker.position=arena.terrain.world_point(target.global_position,135.0 if not target is GateBoss else 235.0)
	marker.look_at(arena.camera.global_position,Vector3.UP)
	if not marker.visible or marker_target_id!=target.get_instance_id():marker.reset_physics_interpolation()
	marker_target_id=target.get_instance_id()
	marker.show()
