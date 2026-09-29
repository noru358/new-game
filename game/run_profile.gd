class_name RunProfile
extends RefCounted

const SUCCESS_BONUS := 20
const FIRST_CLEAR_BONUS := 30
const DEFEAT_LOSS_RATE := 0.50
const RETREAT_LOSS_RATE := 0.20
const GEAR_COST := {"W_FLOW": 35, "W_ECHO": 45, "A_EMBER": 24}
const GROWTH_COST := [20, 35]
const GROWTH_IDS := ["POWER", "WISP", "SLASH", "FINISH", "VITALITY", "GUARD", "MOBILITY", "SPEED"]
const SUPPLY_COST := 12
const SUPPLY_LIMIT := 3
const TEMPLE_REGION := "O_TEMPLE"
const JUNGLE_REGION := "O_JUNGLE_PASS"
const REGION_GEAR := {"O_TEMPLE": "W_FLOW", "O_JUNGLE_PASS": "W_ECHO"}
const GEAR_AFFIXES := {"W_FLOW": ["RIPPLE", "KEEN", "SWIFT", "WEAVE"], "W_ECHO": ["ECHO_WISP", "WIDE", "HEAVY", "DRAW"], "A_EMBER": ["EMBER_STRIKE", "BRIGHT", "STEADY"]}
const REGION_MODS := {"O_TEMPLE": ["RIPPLE", "KEEN", "SWIFT", "WEAVE", "BRIGHT"], "O_JUNGLE_PASS": ["ECHO_WISP", "WIDE", "HEAVY", "DRAW", "EMBER_STRIKE", "STEADY"]}

var save_prefix := "user://loop_conquest_profile"
var generation := 0
var currency := 0
var owned_outpost_ids: Array[String] = []
var acquired_relic_ids: Array[String] = []
var temple_owned: bool:
	get: return owned_outpost_ids.has("O_TEMPLE")
var temple_relic: bool:
	get: return acquired_relic_ids.has("RELIC_TEMPLE")
var jungle_owned: bool:
	get: return owned_outpost_ids.has(JUNGLE_REGION)
var last_run_id := ""
var load_error := false
var recovered_backup := false
var last_award := 0
var last_lost := 0
var last_first_clear := false
var owned_gear: Dictionary = {}
var owned_mods: Array[String] = []
var slotted_mods: Dictionary = {}
var equipped_weapon := "W_START"
var equipped_accessory := ""
var growth_ranks := {"POWER": 0, "WISP": 0, "SLASH": 0, "FINISH": 0, "VITALITY": 0, "GUARD": 0, "MOBILITY": 0, "SPEED": 0}
var supply_count := 0
var supply_selected := false
var last_launch_id := ""
var last_launch_supply_used := false
var last_mod_award := ""


static func gear_name(id: String) -> String:
	match id:
		"W_FLOW": return "흐름의 마력장"
		"W_ECHO": return "집결의 마력장"
		"A_EMBER": return "여우불 장신구"
	return "기본 마력장"


static func gear_for_affix(affix: String) -> String:
	for gear_id in GEAR_AFFIXES:
		if GEAR_AFFIXES[gear_id].has(affix): return gear_id
	return ""


static func affix_description(affix: String) -> String:
	match affix:
		"RIPPLE": return "강화 평타 적중 → 주변에 작은 파동"
		"ECHO_WISP": return "4타 적중 → 여우불 1발 추가"
		"EMBER_STRIKE": return "여우불 적중 → 1.5초 안의 다음 평타가 넓어짐"
		"KEEN": return "이동 베기 피해 +4%"
		"SWIFT": return "이동 베기 재사용 -4%p"
		"WEAVE": return "강화 평타 적중 시 이동 베기 추가 환급 0.10초"
		"WIDE": return "4타 폭발 범위 +10%"
		"HEAVY": return "4타 폭발 피해 +8%"
		"DRAW": return "3타 사거리 +8%"
		"BRIGHT": return "여우불 피해 계수 +0.05"
		"STEADY": return "최대 HP +5"
	return ""


static func affix_title(affix: String) -> String:
	match affix:
		"RIPPLE": return "강화 평타 파동"
		"ECHO_WISP": return "4타 여우불 추가"
		"EMBER_STRIKE": return "여우불·평타 연계"
		"KEEN": return "이동 베기 피해 +4%"
		"SWIFT": return "이동 베기 재사용 -4%p"
		"WEAVE": return "강화 평타 Q 환급 +0.10초"
		"WIDE": return "4타 폭발 범위 +10%"
		"HEAVY": return "4타 폭발 피해 +8%"
		"DRAW": return "3타 사거리 +8%"
		"BRIGHT": return "여우불 피해 +0.05"
		"STEADY": return "최대 HP +5"
	return ""


static func affix_kind(affix: String) -> String:
	return "behavior" if affix in ["RIPPLE", "ECHO_WISP", "EMBER_STRIKE"] else "numeric"


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
	owned_mods.clear()
	slotted_mods = {}
	equipped_weapon = "W_START"
	equipped_accessory = ""
	growth_ranks = {"POWER": 0, "WISP": 0, "SLASH": 0, "FINISH": 0, "VITALITY": 0, "GUARD": 0, "MOBILITY": 0, "SPEED": 0}
	supply_count = 0
	supply_selected = false
	last_launch_id = ""
	last_launch_supply_used = false
	last_mod_award = ""
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
		for id in GROWTH_IDS:
			if not growth_ranks.has(id): growth_ranks[id] = 0
		supply_count = int(best.supply_count)
		supply_selected = bool(best.supply_selected)
		last_launch_id = String(best.last_launch_id)
		last_launch_supply_used = bool(best.last_launch_supply_used)
		if int(best.version) == 2:
			for gear_id in owned_gear:
				var old_mod: String = owned_gear[gear_id]
				owned_gear[gear_id] = true
				owned_mods.append(old_mod)
				slotted_mods[gear_id] = old_mod
			var old_offers: Dictionary = (best.get("pending_affix_offers", {}) as Dictionary).duplicate(true)
			if old_offers.is_empty() and not (best.get("pending_affix_offer", {}) as Dictionary).is_empty():
				var old_offer: Dictionary = best.pending_affix_offer
				old_offers[old_offer.gear_id] = old_offer
			for gear_id in old_offers:
				var offered_mod: String = old_offers[gear_id].affix
				if not owned_mods.has(offered_mod): owned_mods.append(offered_mod)
		else:
			owned_mods.assign(best.owned_mods)
			slotted_mods = (best.slotted_mods as Dictionary).duplicate(true)


func buy_gear(id: String) -> bool:
	if load_error or not GEAR_COST.has(id) or owned_gear.has(id) or currency < int(GEAR_COST[id]): return false
	if id == "W_FLOW" and not temple_owned: return false
	if id == "W_ECHO" and not jungle_owned: return false
	var candidate := _snapshot()
	candidate.currency = currency - int(GEAR_COST[id])
	var next_gear: Dictionary = owned_gear.duplicate(true)
	next_gear[id] = true
	candidate.owned_gear = next_gear
	return _commit(candidate)


func equip(id: String) -> bool:
	if load_error or (id != "W_START" and id != "" and not owned_gear.has(id)): return false
	var candidate := _snapshot()
	if id.begins_with("W_"): candidate.equipped_weapon = id
	elif id == "" or id.begins_with("A_"): candidate.equipped_accessory = id
	else: return false
	return _commit(candidate)


func mod_for(gear_id: String) -> String:
	return String(slotted_mods.get(gear_id, ""))


func slot_mod(gear_id: String, mod_id: String) -> bool:
	if load_error or not owned_gear.has(gear_id): return false
	if not mod_id.is_empty() and (not owned_mods.has(mod_id) or not GEAR_AFFIXES[gear_id].has(mod_id)): return false
	var candidate := _snapshot()
	var next_slots: Dictionary = slotted_mods.duplicate(true)
	if mod_id.is_empty(): next_slots.erase(gear_id)
	else: next_slots[gear_id] = mod_id
	candidate.slotted_mods = next_slots
	return _commit(candidate)


func growth_available(id: String, lifetime_levelups: int) -> bool:
	if id == "SLASH": return lifetime_levelups >= 1
	if id == "FINISH": return lifetime_levelups >= 3
	return GROWTH_IDS.has(id)


func buy_growth(id: String, lifetime_levelups: int = 0) -> bool:
	if load_error or not growth_ranks.has(id) or not growth_available(id, lifetime_levelups): return false
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
	candidate.growth_ranks = {"POWER": 0, "WISP": 0, "SLASH": 0, "FINISH": 0, "VITALITY": 0, "GUARD": 0, "MOBILITY": 0, "SPEED": 0}
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


func region_available(region_id: String) -> bool:
	return region_id == TEMPLE_REGION or (region_id == JUNGLE_REGION and temple_owned)


func settle(run_id: String, result: String, earned: int, region_id: String = TEMPLE_REGION) -> bool:
	if load_error or run_id.is_empty() or earned < 0 or not ["SUCCESS", "DEFEAT", "RETREAT"].has(result) or not region_available(region_id): return false
	if last_run_id == run_id: return true
	var first_clear := result == "SUCCESS" and not owned_outpost_ids.has(region_id)
	var loss_rate := DEFEAT_LOSS_RATE if result == "DEFEAT" else RETREAT_LOSS_RATE if result == "RETREAT" else 0.0
	var lost := mini(maxi(0, earned - 1), ceili(float(earned) * loss_rate))
	var award := earned - lost + (SUCCESS_BONUS if result == "SUCCESS" else 0) + (FIRST_CLEAR_BONUS if first_clear else 0)
	var next_outposts := owned_outpost_ids.duplicate()
	var next_relics := acquired_relic_ids.duplicate()
	if result == "SUCCESS" and not next_outposts.has(region_id): next_outposts.append(region_id)
	if first_clear and region_id == TEMPLE_REGION and not next_relics.has("RELIC_TEMPLE"): next_relics.append("RELIC_TEMPLE")
	var candidate := _snapshot()
	candidate.currency = currency + award
	candidate.owned_outpost_ids = next_outposts
	candidate.acquired_relic_ids = next_relics
	candidate.last_run_id = run_id
	var awarded_mod := ""
	if result == "SUCCESS" and not first_clear:
		var possibilities: Array = REGION_MODS[region_id].duplicate()
		for mod_id in owned_mods: possibilities.erase(mod_id)
		if not possibilities.is_empty():
			awarded_mod = String(possibilities[posmod(run_id.hash(), possibilities.size())])
			var next_mods: Array[String] = owned_mods.duplicate()
			next_mods.append(awarded_mod)
			candidate.owned_mods = next_mods
	if not _commit(candidate): return false
	last_award = award
	last_lost = lost
	last_first_clear = first_clear
	last_mod_award = awarded_mod
	return true


func _snapshot() -> Dictionary:
	return {
		"version": 3, "generation": generation + 1, "currency": currency,
		"owned_outpost_ids": owned_outpost_ids.duplicate(), "acquired_relic_ids": acquired_relic_ids.duplicate(),
		"last_run_id": last_run_id, "owned_gear": owned_gear.duplicate(true),
		"owned_mods": owned_mods.duplicate(), "slotted_mods": slotted_mods.duplicate(true),
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
	owned_mods.assign(candidate.owned_mods)
	slotted_mods = (candidate.slotted_mods as Dictionary).duplicate(true)
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
	if not [1.0, 2.0, 3.0].has(data.get("version")) or not data.get("generation") is float or not data.get("currency") is float:
		return {}
	if int(data.generation) < 1 or int(data.currency) < 0 or not data.get("owned_outpost_ids") is Array or not data.get("acquired_relic_ids") is Array or not data.get("last_run_id") is String:
		return {}
	for id in data.owned_outpost_ids:
		if not id is String: return {}
	for id in data.acquired_relic_ids:
		if not id is String: return {}
	if int(data.version) >= 2:
		if not data.get("owned_gear") is Dictionary or not data.get("equipped_weapon") is String or not data.get("equipped_accessory") is String or not data.get("growth_ranks") is Dictionary or not data.get("supply_count") is float or not data.get("supply_selected") is bool or not data.get("last_launch_id") is String or not data.get("last_launch_supply_used") is bool: return {}
		for id in data.owned_gear:
			if not GEAR_COST.has(id): return {}
			if int(data.version) == 2 and (not data.owned_gear[id] is String or not GEAR_AFFIXES[id].has(data.owned_gear[id])): return {}
			if int(data.version) == 3 and (not data.owned_gear[id] is bool or not data.owned_gear[id]): return {}
		if not ["W_START", "W_FLOW", "W_ECHO"].has(data.equipped_weapon) or (data.equipped_weapon != "W_START" and not data.owned_gear.has(data.equipped_weapon)): return {}
		if not ["", "A_EMBER"].has(data.equipped_accessory) or (data.equipped_accessory == "A_EMBER" and not data.owned_gear.has("A_EMBER")): return {}
		for id in ["POWER", "VITALITY", "MOBILITY"]:
			if not data.growth_ranks.has(id) or not data.growth_ranks[id] is float or int(data.growth_ranks[id]) < 0 or int(data.growth_ranks[id]) > 2: return {}
		for id in data.growth_ranks:
			if not GROWTH_IDS.has(id) or not data.growth_ranks[id] is float or int(data.growth_ranks[id]) < 0 or int(data.growth_ranks[id]) > 2: return {}
		if int(data.supply_count) < 0 or int(data.supply_count) > SUPPLY_LIMIT: return {}
		if int(data.version) == 3:
			if not data.get("owned_mods") is Array or not data.get("slotted_mods") is Dictionary: return {}
			var seen_mods := {}
			for mod_id in data.owned_mods:
				if not mod_id is String or not _valid_mod(mod_id) or seen_mods.has(mod_id): return {}
				seen_mods[mod_id] = true
			for gear_id in data.slotted_mods:
				if not data.owned_gear.has(gear_id) or not data.slotted_mods[gear_id] is String or not data.owned_mods.has(data.slotted_mods[gear_id]) or not GEAR_AFFIXES[gear_id].has(data.slotted_mods[gear_id]): return {}
		if data.has("pending_affix_offer"):
			if not data.pending_affix_offer is Dictionary: return {}
			if not data.pending_affix_offer.is_empty():
				var offer: Dictionary = data.pending_affix_offer
				if not offer.get("region_id") is String or not REGION_GEAR.has(offer.region_id) or not offer.get("gear_id") is String or offer.gear_id != REGION_GEAR[offer.region_id] or not offer.get("affix") is String or not GEAR_AFFIXES[offer.gear_id].has(offer.affix): return {}
		if data.has("pending_affix_offers"):
			if not data.pending_affix_offers is Dictionary: return {}
			for gear_id in data.pending_affix_offers:
				if not REGION_GEAR.values().has(gear_id) or not data.pending_affix_offers[gear_id] is Dictionary: return {}
				var offer: Dictionary = data.pending_affix_offers[gear_id]
				if not offer.get("region_id") is String or not REGION_GEAR.has(offer.region_id) or REGION_GEAR[offer.region_id] != gear_id or not offer.get("gear_id") is String or offer.gear_id != gear_id or not offer.get("affix") is String or not GEAR_AFFIXES[gear_id].has(offer.affix): return {}
	return data


static func _valid_mod(mod_id: String) -> bool:
	for gear_id in GEAR_AFFIXES:
		if GEAR_AFFIXES[gear_id].has(mod_id): return true
	return false
