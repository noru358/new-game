class_name RunProfile
extends RefCounted

const SUCCESS_BONUS := 20
const FIRST_CLEAR_BONUS := 30

var save_prefix := "user://loop_conquest_profile"
var generation := 0
var currency := 0
var owned_outpost_ids: Array[String] = []
var acquired_relic_ids: Array[String] = []
var temple_owned: bool:
	get: return owned_outpost_ids.has("O_TEMPLE")
var temple_relic: bool:
	get: return acquired_relic_ids.has("RELIC_TEMPLE")
var last_run_id := ""
var load_error := false
var recovered_backup := false
var last_award := 0
var last_first_clear := false


func load_state() -> void:
	generation = 0
	currency = 0
	owned_outpost_ids.clear()
	acquired_relic_ids.clear()
	last_run_id = ""
	load_error = false
	recovered_backup = false
	last_award = 0
	last_first_clear = false
	var found_any := false
	var valid_count := 0
	var invalid_count := 0
	var best: Dictionary = {}
	for suffix in ["_a.json", "_b.json"]:
		var path: String = save_prefix + suffix
		if not FileAccess.file_exists(path): continue
		found_any = true
		var data := _read(path)
		if data.is_empty():
			invalid_count += 1
			continue
		valid_count += 1
		if best.is_empty() or int(data.generation) > int(best.generation): best = data
	if best.is_empty():
		load_error = found_any
		return
	recovered_backup = invalid_count > 0 and valid_count > 0
	generation = int(best.generation)
	currency = int(best.currency)
	owned_outpost_ids.assign(best.owned_outpost_ids)
	acquired_relic_ids.assign(best.acquired_relic_ids)
	last_run_id = String(best.last_run_id)


func settle(run_id: String, result: String, earned: int) -> bool:
	if load_error or run_id.is_empty() or earned < 0 or not ["SUCCESS", "DEFEAT", "RETREAT"].has(result): return false
	if last_run_id == run_id: return true
	var first_clear := result == "SUCCESS" and not temple_owned
	var award := earned + (SUCCESS_BONUS if result == "SUCCESS" else 0) + (FIRST_CLEAR_BONUS if first_clear else 0)
	var next_outposts := owned_outpost_ids.duplicate()
	var next_relics := acquired_relic_ids.duplicate()
	if result == "SUCCESS" and not next_outposts.has("O_TEMPLE"): next_outposts.append("O_TEMPLE")
	if first_clear and not next_relics.has("RELIC_TEMPLE"): next_relics.append("RELIC_TEMPLE")
	var candidate := {
		"version": 1,
		"generation": generation + 1,
		"currency": currency + award,
		"owned_outpost_ids": next_outposts,
		"acquired_relic_ids": next_relics,
		"last_run_id": run_id,
	}
	var suffix := "_a.json" if (generation + 1) % 2 == 1 else "_b.json"
	var path := save_prefix + suffix
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(candidate))
	file.flush()
	file.close()
	var stored := _read(path)
	if stored.is_empty() or int(stored.generation) != int(candidate.generation) or int(stored.currency) != int(candidate.currency) or stored.owned_outpost_ids != candidate.owned_outpost_ids or stored.acquired_relic_ids != candidate.acquired_relic_ids or String(stored.last_run_id) != run_id:
		return false
	generation = int(candidate.generation)
	currency = int(candidate.currency)
	owned_outpost_ids = next_outposts
	acquired_relic_ids = next_relics
	last_run_id = run_id
	last_award = award
	last_first_clear = first_clear
	return true


func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary: return {}
	var data: Dictionary = parser.data
	if data.get("version") != 1 or not data.get("generation") is float or not data.get("currency") is float:
		return {}
	if int(data.generation) < 1 or int(data.currency) < 0 or not data.get("owned_outpost_ids") is Array or not data.get("acquired_relic_ids") is Array or not data.get("last_run_id") is String:
		return {}
	for id in data.owned_outpost_ids:
		if not id is String: return {}
	for id in data.acquired_relic_ids:
		if not id is String: return {}
	return data
