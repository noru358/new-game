class_name UnlockProgress
extends RefCounted

const MILESTONES := {
	"S_WISP_COUNT": 2,
	"S_WISP_ORBIT": 4,
	"S_WISP_CHAIN": 6,
}

var save_prefix := "user://loop_conquest_1d_unlocks"
var lifetime_levelups := 0
var generation := 0


func load_progress() -> void:
	lifetime_levelups = 0
	generation = 0
	for suffix in ["_a.json", "_b.json"]:
		var path: String = save_prefix + suffix
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var parser := JSON.new()
		if parser.parse(file.get_as_text()) != OK:
			continue
		var parsed: Variant = parser.data
		if not parsed is Dictionary or parsed.get("version", 0) != 1:
			continue
		var stored_generation := int(parsed.get("generation", -1))
		var stored_levels := int(parsed.get("lifetime_levelups", -1))
		if stored_generation > generation and stored_levels >= 0:
			generation = stored_generation
			lifetime_levelups = stored_levels


func add_levelup() -> Array[String]:
	var before := lifetime_levelups
	lifetime_levelups += 1
	_save_progress()
	var newly_unlocked: Array[String] = []
	for card_id in MILESTONES:
		if before < MILESTONES[card_id] and lifetime_levelups >= MILESTONES[card_id]:
			newly_unlocked.append(card_id)
	return newly_unlocked


func is_unlocked(card_id: String) -> bool:
	return not MILESTONES.has(card_id) or lifetime_levelups >= MILESTONES[card_id]


func _save_progress() -> void:
	var next_generation := generation + 1
	var suffix := "_a.json" if next_generation % 2 == 1 else "_b.json"
	var file := FileAccess.open(save_prefix + suffix, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save card unlock progress")
		return
	file.store_string(JSON.stringify({
		"version": 1,
		"generation": next_generation,
		"lifetime_levelups": lifetime_levelups,
	}))
	file.flush()
	file.close()
	generation = next_generation
