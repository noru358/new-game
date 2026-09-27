class_name RunProfile
extends RefCounted

const SUCCESS_BONUS := 20
const FIRST_CLEAR_BONUS := 30
const DEFEAT_LOSS_RATE := 0.50
const RETREAT_LOSS_RATE := 0.20
const GEAR_COST := {"W_FLOW": 35, "A_EMBER": 24}
const GROWTH_COST := [20, 35]
const SUPPLY_COST := 12
const SUPPLY_LIMIT := 3

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
var last_lost := 0
var last_first_clear := false
var owned_gear: Dictionary = {}
var equipped_weapon := "W_START"
var equipped_accessory := ""
var growth_ranks := {"POWER": 0, "VITALITY": 0, "MOBILITY": 0}
var supply_count := 0
var supply_selected := false
var last_launch_id := ""
var last_launch_supply_used := false


func load_state() -> void:
	generation = 0
	currency = 0
	owned_outpost_ids.clear()
	acquired_relic_ids.clear()
	last_run_id = ""
	load_error = false
	recovered_backup = false
	last_award = 0
	last_lost = 0
	last_first_clear = false
	owned_gear = {}
	equipped_weapon = "W_START"
	equipped_accessory = ""
	growth_ranks = {"POWER": 0, "VITALITY": 0, "MOBILITY": 0}
	supply_count = 0
	supply_selected = false
	last_launch_id = ""
	last_launch_supply_used = false
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
	if int(best.version) >= 2:
		owned_gear = (best.owned_gear as Dictionary).duplicate(true)
		equipped_weapon = String(best.equipped_weapon)
		equipped_accessory = String(best.equipped_accessory)
		growth_ranks = (best.growth_ranks as Dictionary).duplicate()
		supply_count = int(best.supply_count)
		supply_selected = bool(best.supply_selected)
		last_launch_id = String(best.last_launch_id)
		last_launch_supply_used = bool(best.last_launch_supply_used)


func buy_gear(id: String, affix: String) -> bool:
	if load_error or not GEAR_COST.has(id) or owned_gear.has(id) or currency < int(GEAR_COST[id]): return false
	if id == "W_FLOW" and not temple_owned: return false
	if id == "W_FLOW" and not ["KEEN", "SWIFT"].has(affix): return false
	if id == "A_EMBER" and not ["BRIGHT", "STEADY"].has(affix): return false
	var candidate := _snapshot()
	candidate.currency = currency - int(GEAR_COST[id])
	var next_gear: Dictionary = owned_gear.duplicate(true)
	next_gear[id] = affix
	candidate.owned_gear = next_gear
	return _commit(candidate)


func equip(id: String) -> bool:
	if load_error or (id != "W_START" and id != "" and not owned_gear.has(id)): return false
	var candidate := _snapshot()
	if id.begins_with("W_"): candidate.equipped_weapon = id
	elif id == "" or id.begins_with("A_"): candidate.equipped_accessory = id
	else: return false
	return _commit(candidate)


func buy_growth(id: String) -> bool:
	if load_error or not growth_ranks.has(id): return false
	var rank := int(growth_ranks[id])
	if rank >= GROWTH_COST.size() or currency < int(GROWTH_COST[rank]): return false
	var candidate := _snapshot()
	candidate.currency = currency - int(GROWTH_COST[rank])
	var next_ranks: Dictionary = growth_ranks.duplicate()
	next_ranks[id] = rank + 1
	candidate.growth_ranks = next_ranks
	return _commit(candidate)


func reset_growth() -> bool:
	if load_error: return false
	var refund := 0
	for id in growth_ranks:
		for rank in int(growth_ranks[id]): refund += int(GROWTH_COST[rank])
	if refund == 0: return true
	var candidate := _snapshot()
	candidate.currency = currency + refund
	candidate.growth_ranks = {"POWER": 0, "VITALITY": 0, "MOBILITY": 0}
	return _commit(candidate)


func buy_supply() -> bool:
	if load_error or currency < SUPPLY_COST or supply_count >= SUPPLY_LIMIT: return false
	var candidate := _snapshot()
	candidate.currency = currency - SUPPLY_COST
	candidate.supply_count = supply_count + 1
	candidate.supply_selected = true
	return _commit(candidate)


func select_supply(selected: bool) -> bool:
	if load_error or (selected and supply_count <= 0): return false
	var candidate := _snapshot()
	candidate.supply_selected = selected
	return _commit(candidate)


func begin_run(run_id: String) -> bool:
	if load_error or run_id.is_empty(): return false
	if last_launch_id == run_id: return true
	var candidate := _snapshot()
	candidate.last_launch_id = run_id
	candidate.last_launch_supply_used = supply_selected and supply_count > 0
	if candidate.last_launch_supply_used:
		candidate.supply_count = supply_count - 1
		candidate.supply_selected = candidate.supply_count > 0
	return _commit(candidate)


func settle(run_id: String, result: String, earned: int) -> bool:
	if load_error or run_id.is_empty() or earned < 0 or not ["SUCCESS", "DEFEAT", "RETREAT"].has(result): return false
	if last_run_id == run_id: return true
	var first_clear := result == "SUCCESS" and not temple_owned
	var loss_rate := DEFEAT_LOSS_RATE if result == "DEFEAT" else RETREAT_LOSS_RATE if result == "RETREAT" else 0.0
	var lost := mini(maxi(0, earned - 1), ceili(float(earned) * loss_rate))
	var award := earned - lost + (SUCCESS_BONUS if result == "SUCCESS" else 0) + (FIRST_CLEAR_BONUS if first_clear else 0)
	var next_outposts := owned_outpost_ids.duplicate()
	var next_relics := acquired_relic_ids.duplicate()
	if result == "SUCCESS" and not next_outposts.has("O_TEMPLE"): next_outposts.append("O_TEMPLE")
	if first_clear and not next_relics.has("RELIC_TEMPLE"): next_relics.append("RELIC_TEMPLE")
	var candidate := _snapshot()
	candidate.currency = currency + award
	candidate.owned_outpost_ids = next_outposts
	candidate.acquired_relic_ids = next_relics
	candidate.last_run_id = run_id
	if not _commit(candidate): return false
	last_award = award
	last_lost = lost
	last_first_clear = first_clear
	return true


func _snapshot() -> Dictionary:
	return {
		"version": 2, "generation": generation + 1, "currency": currency,
		"owned_outpost_ids": owned_outpost_ids.duplicate(), "acquired_relic_ids": acquired_relic_ids.duplicate(),
		"last_run_id": last_run_id, "owned_gear": owned_gear.duplicate(true),
		"equipped_weapon": equipped_weapon, "equipped_accessory": equipped_accessory,
		"growth_ranks": growth_ranks.duplicate(), "supply_count": supply_count,
		"supply_selected": supply_selected, "last_launch_id": last_launch_id,
		"last_launch_supply_used": last_launch_supply_used,
	}


func _commit(candidate: Dictionary) -> bool:
	var suffix := "_a.json" if int(candidate.generation) % 2 == 1 else "_b.json"
	var path := save_prefix + suffix
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(candidate))
	file.flush()
	file.close()
	var stored := _read(path)
	var normalized: Dictionary = JSON.parse_string(JSON.stringify(candidate))
	if stored.is_empty() or stored != normalized:
		return false
	generation = int(candidate.generation)
	currency = int(candidate.currency)
	owned_outpost_ids.assign(candidate.owned_outpost_ids)
	acquired_relic_ids.assign(candidate.acquired_relic_ids)
	last_run_id = String(candidate.last_run_id)
	owned_gear = (candidate.owned_gear as Dictionary).duplicate(true)
	equipped_weapon = String(candidate.equipped_weapon)
	equipped_accessory = String(candidate.equipped_accessory)
	growth_ranks = (candidate.growth_ranks as Dictionary).duplicate()
	supply_count = int(candidate.supply_count)
	supply_selected = bool(candidate.supply_selected)
	last_launch_id = String(candidate.last_launch_id)
	last_launch_supply_used = bool(candidate.last_launch_supply_used)
	return true


func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary: return {}
	var data: Dictionary = parser.data
	if not [1.0, 2.0].has(data.get("version")) or not data.get("generation") is float or not data.get("currency") is float:
		return {}
	if int(data.generation) < 1 or int(data.currency) < 0 or not data.get("owned_outpost_ids") is Array or not data.get("acquired_relic_ids") is Array or not data.get("last_run_id") is String:
		return {}
	for id in data.owned_outpost_ids:
		if not id is String: return {}
	for id in data.acquired_relic_ids:
		if not id is String: return {}
	if int(data.version) == 2:
		if not data.get("owned_gear") is Dictionary or not data.get("equipped_weapon") is String or not data.get("equipped_accessory") is String or not data.get("growth_ranks") is Dictionary or not data.get("supply_count") is float or not data.get("supply_selected") is bool or not data.get("last_launch_id") is String or not data.get("last_launch_supply_used") is bool: return {}
		for id in data.owned_gear:
			if not GEAR_COST.has(id) or not data.owned_gear[id] is String: return {}
			if id == "W_FLOW" and not ["KEEN", "SWIFT"].has(data.owned_gear[id]): return {}
			if id == "A_EMBER" and not ["BRIGHT", "STEADY"].has(data.owned_gear[id]): return {}
		if not ["W_START", "W_FLOW"].has(data.equipped_weapon) or (data.equipped_weapon == "W_FLOW" and not data.owned_gear.has("W_FLOW")): return {}
		if not ["", "A_EMBER"].has(data.equipped_accessory) or (data.equipped_accessory == "A_EMBER" and not data.owned_gear.has("A_EMBER")): return {}
		for id in ["POWER", "VITALITY", "MOBILITY"]:
			if not data.growth_ranks.has(id) or not data.growth_ranks[id] is float or int(data.growth_ranks[id]) < 0 or int(data.growth_ranks[id]) > 2: return {}
		if int(data.supply_count) < 0 or int(data.supply_count) > SUPPLY_LIMIT: return {}
	return data
