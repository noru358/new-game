extends SceneTree
func _initialize() -> void:
	var entry = preload("res://game/field_preview_entry.gd")
	var failures := 0
	var session = preload("res://game/field_preview_session.gd")
	if not session.temporary_app_path("/private/var/folders/example/T/codex-file-preview-Hpz9Mi/Loop Conquest - v49.app/Contents/MacOS/Loop Conquest - v49 Field Preview"): failures += 1
	for path in ["/Users/lty/Downloads/LoopConquest-v49/Loop Conquest - v49.app/Contents/MacOS/Loop Conquest - v49 Field Preview", "/Users/runner/scratch/extracted/Loop Conquest - v49.app/Contents/MacOS/Loop Conquest - v49 Field Preview", "/Users/lty/Downloads/codex-file-preview-not-a-folder.app/Contents/MacOS/game"]:
		if session.temporary_app_path(path): failures += 1
	if entry.selected_scene(PackedStringArray()) != "res://game/travel_camp.tscn": failures += 1
	for key in entry.SCENES:
		if entry.selected_scene(PackedStringArray(["--preview-scene=" + key])) != entry.SCENES[key]: failures += 1
	for args in [["--preview-scene=res://arbitrary.tscn"], ["--preview-scene=unknown"], ["--preview-scene=camp", "--preview-scene=jungle-south"]]:
		if not entry.selected_scene(PackedStringArray(args)).is_empty(): failures += 1
	print("Packaged preview entry: ", failures, " failures; fixed scene whitelist only")
	quit(1 if failures else 0)
