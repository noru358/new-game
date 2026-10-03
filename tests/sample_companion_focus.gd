extends "res://tests/sample_build_comparison.gd"
## Matched normal-speed common-controller observation; not a human strategy test.
var focus_metrics:={"trial":false,"primary_surviving_hits":0,"marked_shots":0,"active_mark_seconds":0.0}
var observed_time:=0.0
func _initialize()->void:
	node_added.connect(_mount)
	call_deferred("_run")
func _mount(node:Node)->void:
	if node.get_script()!=load("res://game/hybrid_region.gd"):return
	node.companion_focus_trial=OS.get_environment("COMPANION_FOCUS_TRIAL")=="1"
	focus_metrics.trial=node.companion_focus_trial
	node.ready.connect(func():node.player.basic_target_struck.connect(func(_enemy):focus_metrics.primary_surviving_hits+=1))
func _on_wisp_shot(target:TrainingEnemy,id:int)->void:
	super._on_wisp_shot(target,id)
	if scene.player.has_meta(&"companion_focus_target"):
		var reference=scene.player.get_meta(&"companion_focus_target")
		if reference is WeakRef and reference.get_ref()==target:focus_metrics.marked_shots+=1
func _observe_actions()->void:
	super._observe_actions()
	var dt:float=maxf(0.0,scene.run_time-observed_time)
	observed_time=scene.run_time
	if scene.player.has_meta(&"companion_focus_target"):focus_metrics.active_mark_seconds+=dt
func _checkpoint(label:String)->void:
	super._checkpoint(label)
	checkpoints[-1]["focus_observation"]=focus_metrics.duplicate(true)
