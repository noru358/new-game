extends Node
## Used only as the packaged field-preview entry point. Release path overrides stay disabled.
const SCENES := {
	"camp": "res://game/travel_camp.tscn",
	"temple-circuit": "res://game/temple_circuit_run.tscn",
	"jungle-south": "res://game/jungle_south_circuit.tscn",
	"deep-wetland": "res://game/deep_wetland_trial.tscn",
}
static func selected_scene(arguments: PackedStringArray) -> String:
	var choice := "camp"
	var supplied := false
	for argument in arguments:
		if not argument.begins_with("--preview-scene="): continue
		if supplied: return ""
		supplied = true
		choice = argument.trim_prefix("--preview-scene=")
		if not SCENES.has(choice): return ""
	return SCENES[choice]
func _ready() -> void:
	var path := selected_scene(OS.get_cmdline_user_args())
	if path.is_empty():
		printerr("FAIL: unsupported or repeated preview scene selection")
		get_tree().quit(2)
		return
	preload("res://game/field_preview_session.gd").activate(get_tree())
	get_tree().call_deferred("change_scene_to_file", path)
