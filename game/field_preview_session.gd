extends RefCounted
## A packaged preview uses one isolated economy across camp and both candidate maps.
## Ordinary source launches keep their existing profiles and scenes.
const KEY := "loop_conquest_field_preview_session"
const PROFILE := "user://first_region_shared_v45_profile"
const UNLOCKS := "user://first_region_shared_v45_unlocks"
static func activate(tree: SceneTree, profile_prefix: String = PROFILE, unlock_prefix: String = UNLOCKS) -> void:
	tree.root.set_meta(KEY, {"profile": profile_prefix, "unlocks": unlock_prefix})
static func temporary_app_path(executable_path: String) -> bool:
	# The attachment preview may unpack an app into a short-lived directory.
	# Advisory only: never move a running bundle or modify its save location.
	for component in executable_path.split("/"):
		if component.begins_with("codex-file-preview-") and not component.ends_with(".app"): return true
	return false

static func active(tree: SceneTree) -> bool:
	return tree.root.has_meta(KEY)
static func configure(scene: Node) -> void:
	if not active(scene.get_tree()): return
	var session: Dictionary = scene.get_tree().root.get_meta(KEY)
	scene.profile_save_prefix = session.profile
	scene.growth_save_prefix = session.unlocks
static func region_scene(tree: SceneTree, jungle: bool) -> String:
	if active(tree):
		return "res://game/jungle_south_circuit.tscn" if jungle else "res://game/temple_circuit_run.tscn"
	return "res://game/jungle_pass.tscn" if jungle else "res://game/hybrid_region.tscn"

static func scene_for_region(tree: SceneTree, region_id: String) -> String:
	if region_id == RunProfile.WETLAND_REGION: return "res://game/deep_wetland_run.tscn"
	return region_scene(tree,region_id == RunProfile.JUNGLE_REGION)
