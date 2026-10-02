extends SceneTree
func _initialize() -> void:
	var entry = preload("res://game/field_preview_entry.gd")
	var failures := 0
	if entry.selected_scene(PackedStringArray()) != "res://game/travel_camp.tscn": failures += 1
	for key in entry.SCENES:
		if entry.selected_scene(PackedStringArray(["--preview-scene=" + key])) != entry.SCENES[key]: failures += 1
	for args in [["--preview-scene=res://arbitrary.tscn"], ["--preview-scene=unknown"], ["--preview-scene=camp", "--preview-scene=jungle-south"]]:
		if not entry.selected_scene(PackedStringArray(args)).is_empty(): failures += 1
	print("Packaged preview entry: ", failures, " failures; fixed scene whitelist only")
	quit(1 if failures else 0)
