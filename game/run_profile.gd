class_name RunProfile
extends RefCounted

const SAVE_VERSION := 7
const SUCCESS_BONUS := 20
const FIRST_CLEAR_BONUS := 30
const DEFEAT_LOSS_RATE := 0.50
const RETREAT_LOSS_RATE := 0.20
const GEAR_COST := {"W_FLOW": 35, "W_ECHO": 45, "A_EMBER": 24}
const GROWTH_COST := [20, 35, 60, 95, 140]
const ATTACK_BRANCH_COST := 60
const ATTACK_BRANCHES := ["DIRECT", "COMPANION"]
const GROWTH_IDS := PermanentGrowthCatalog.IDS
const SUPPLY_COST := 12
const SUPPLY_LIMIT := 3
const TEMPLE_REGION := "O_TEMPLE"
const JUNGLE_REGION := "O_JUNGLE_PASS"
const WETLAND_REGION := "O_DEEP_WETLAND"
const REGION_GEAR := {"O_TEMPLE": "W_FLOW", "O_JUNGLE_PASS": "W_ECHO"}
const GEAR_AFFIXES := {"W_FLOW": ["RIPPLE", "KEEN", "SWIFT", "WEAVE"], "W_ECHO": ["ECHO_WISP", "WIDE", "HEAVY", "DRAW"], "A_EMBER": ["EMBER_STRIKE", "BRIGHT", "STEADY", "EMBER_STEP"]}
const REGION_MODS := {"O_TEMPLE": ["RIPPLE", "KEEN", "SWIFT", "WEAVE", "BRIGHT", "EMBER_STEP"], "O_JUNGLE_PASS": ["ECHO_WISP", "WIDE", "HEAVY", "DRAW", "EMBER_STRIKE", "STEADY"], "O_DEEP_WETLAND": ["RIPPLE", "KEEN", "SWIFT", "WEAVE", "ECHO_WISP", "WIDE", "HEAVY", "DRAW", "EMBER_STRIKE", "BRIGHT", "STEADY", "EMBER_STEP"]}

var save_prefix := "user://loop_conquest_profile"
var generation := 0
var legacy_backup_pending := false
var currency := 0
var owned_outpost_ids: Array[String] = []
var acquired_relic_ids: Array[String] = []
var temple_owned: bool:
	get: return owned_outpost_ids.has("O_TEMPLE")
var temple_relic: bool:
	get: return acquired_relic_ids.has("RELIC_TEMPLE")
var jungle_owned: bool:
	get: return owned_outpost_ids.has(JUNGLE_REGION)
var wetland_owned: bool:
	get: return owned_outpost_ids.has(WETLAND_REGION)
var last_run_id := ""
var load_error := false
var unsupported_save_format := false
var recovered_backup := false
var last_award := 0
var last_lost := 0
var last_first_clear := false
var owned_gear: Dictionary = {}
var owned_mods: Array[String] = []
var slotted_mods: Dictionary = {}
var equipped_weapon := "W_START"
var equipped_accessory := ""
var growth_ranks := PermanentGrowthCatalog.empty_ranks()
var discovered_places: Array[String] = []
var awakenings: Array[String] = []
var attack_branch := ""
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
		"EMBER_STEP": return "여우불 적중 → 대시 대기 -0.05초 (0.3초 간격)"
		"STEADY": return "최대 HP +5"
	return ""


static func affix_title(affix: String) -> String:
	match affix:
		"RIPPLE": return "강화 평타 파동"
		"ECHO_WISP": return "4타 여우불 추가"
		"EMBER_STRIKE": return "여우불·평타 연계"
		"KEEN": return "이동 베기 피해 +4%"
		"SWIFT": return "이동 베기 재사용 -4%p"
		"WEAVE": return "강화 평타 베기 환급 +0.10초"
		"WIDE": return "4타 폭발 범위 +10%"
		"HEAVY": return "4타 폭발 피해 +8%"
		"DRAW": return "3타 사거리 +8%"
		"BRIGHT": return "여우불 피해 +0.05"
		"EMBER_STEP": return "여우불·대시 연계"
		"STEADY": return "최대 HP +5"
	return ""


static func affix_source(affix: String) -> String:
	var sources: Array[String] = []
	for region in REGION_MODS:
		if REGION_MODS[region].has(affix):
			sources.append("사원" if region == TEMPLE_REGION else "정글" if region == JUNGLE_REGION else "습지")
	return "·".join(sources) + " 재클리어 보상 (미보유 1개)" if not sources.is_empty() else ""


static func affix_kind(affix: String) -> String:
	return "behavior" if affix in ["RIPPLE", "ECHO_WISP", "EMBER_STRIKE", "EMBER_STEP"] else "numeric"


func load_state() -> void:
	legacy_backup_pending = false
	generation = 0
	currency = 0
	owned_outpost_ids.clear()
	acquired_relic_ids.clear()
	last_run_id = ""
	load_error = false
	unsupported_save_format = false
	recovered_backup = false
	last_award = 0
	last_lost = 0
	last_first_clear = false
	owned_gear = {}
	owned_mods.clear()
	slotted_mods = {}
	equipped_weapon = "W_START"
	equipped_accessory = ""
	growth_ranks = PermanentGrowthCatalog.empty_ranks()
	discovered_places.clear()
	awakenings.clear()
	attack_branch = ""
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
	# A future slot is newer-format data, never a corrupt backup to replace.
	if unsupported_save_format:
		load_error = true
		return
	if best.is_empty():
		load_error = found_any
		return
	legacy_backup_pending = int(best.version) < SAVE_VERSION
	recovered_backup = invalid_count > 0 and valid_count > 0
	discovered_places.assign(best.get("discovered_places", []))
	awakenings.assign(best.get("awakenings", []))
	attack_branch = String(best.get("attack_branch", ""))
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


func save_block_reason() -> String:
	if unsupported_save_format:
		return "더 최신 버전에서 만든 저장 기록입니다. 게임을 업데이트한 뒤 다시 실행하세요. 저장 파일은 보존했으며 출정과 정산을 차단했습니다."
	return "저장 기록과 정상 백업을 읽을 수 없습니다. 기존 파일은 보존했습니다. 저장 폴더에서 백업을 확인하세요." if load_error else ""


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
	if id in ["SLASH", "SLASH_POWER"]: return lifetime_levelups >= 1
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


func discover_garden() -> bool:
	return discover_place("TEMPLE_GARDEN")


func discover_place(id: String) -> bool:
	if load_error or not ["TEMPLE_GARDEN", "JUNGLE_GROTTO"].has(id): return false
	if discovered_places.has(id): return true
	var candidate := _snapshot()
	candidate.discovered_places.append(id)
	return _commit(candidate)


func claim_garden_awakening() -> bool:
	if load_error or not discovered_places.has("TEMPLE_GARDEN"): return false
	if awakenings.has("EMBER_GARDEN"): return true
	var candidate := _snapshot()
	candidate.awakenings.append("EMBER_GARDEN")
	return _commit(candidate)


func claim_grotto_awakening() -> bool:
	if load_error or not discovered_places.has("JUNGLE_GROTTO"): return false
	if awakenings.has("ECHO_GROTTO"): return true
	var candidate := _snapshot()
	candidate.awakenings.append("ECHO_GROTTO")
	return _commit(candidate)


func buy_attack_branch(id: String) -> bool:
	if load_error or not ATTACK_BRANCHES.has(id) or not attack_branch.is_empty(): return false
	if currency < ATTACK_BRANCH_COST or not attack_branch_available(): return false
	var candidate := _snapshot()
	candidate.currency = currency - ATTACK_BRANCH_COST
	candidate.attack_branch = id
	return _commit(candidate)


func attack_branch_available() -> bool:
	var invested := 0
	for id in ["POWER", "WISP", "SLASH", "FINISH"]: invested += int(growth_ranks[id])
	return invested >= 4


func reset_growth() -> bool:
	if load_error: return false
	var refund := ATTACK_BRANCH_COST if not attack_branch.is_empty() else 0
	for id in growth_ranks:
		for rank in int(growth_ranks[id]): refund += int(GROWTH_COST[rank])
	if refund == 0: return true
	var candidate := _snapshot()
	candidate.currency = currency + refund
	candidate.attack_branch = ""
	candidate.growth_ranks = PermanentGrowthCatalog.empty_ranks()
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
	return region_id == TEMPLE_REGION or (region_id == JUNGLE_REGION and temple_owned) or (region_id == WETLAND_REGION and jungle_owned)


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
		"version": SAVE_VERSION, "discovered_places": discovered_places.duplicate(), "awakenings": awakenings.duplicate(), "attack_branch": attack_branch, "generation": generation + 1, "currency": currency,
		"owned_outpost_ids": owned_outpost_ids.duplicate(), "acquired_relic_ids": acquired_relic_ids.duplicate(),
		"last_run_id": last_run_id, "owned_gear": owned_gear.duplicate(true),
		"owned_mods": owned_mods.duplicate(), "slotted_mods": slotted_mods.duplicate(true),
		"equipped_weapon": equipped_weapon, "equipped_accessory": equipped_accessory,
		"growth_ranks": growth_ranks.duplicate(), "supply_count": supply_count,
		"supply_selected": supply_selected, "last_launch_id": last_launch_id,
		"last_launch_supply_used": last_launch_supply_used,
	}


func _preserve_legacy_slots() -> bool:
	# Archive raw bytes before the first v7 write. Never overwrite an archive.
	for suffix in ["_a.json", "_b.json"]:
		var source: String = save_prefix + suffix
		if not FileAccess.file_exists(source): continue
		var bytes := FileAccess.get_file_as_bytes(source)
		if FileAccess.get_open_error() != OK: return false
		var archive: String = save_prefix + "_pre_v7" + suffix
		if FileAccess.file_exists(archive):
			if FileAccess.get_file_as_bytes(archive) != bytes: return false
		else:
			var file := FileAccess.open(archive, FileAccess.WRITE)
			if file == null: return false
			file.store_buffer(bytes)
			file.flush()
			file.close()
			if FileAccess.get_file_as_bytes(archive) != bytes: return false
	legacy_backup_pending = false
	return true


func _commit(candidate: Dictionary) -> bool:
	if load_error or unsupported_save_format: return false
	if legacy_backup_pending and not _preserve_legacy_slots(): return false
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
	discovered_places.assign(candidate.discovered_places)
	awakenings.assign(candidate.awakenings)
	attack_branch = String(candidate.attack_branch)
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
	# Only the version header is known for a future format; do not validate its
	# body against today's schema or classify it as corruption.
	var version: Variant = data.get("version")
	if version is float and is_finite(version) and version == floor(version) and version > SAVE_VERSION:
		unsupported_save_format = true
		load_error = true
		return {}
	if not [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0].has(data.get("version")) or not data.get("generation") is float or not data.get("currency") is float:
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
			if int(data.version) >= 3 and (not data.owned_gear[id] is bool or not data.owned_gear[id]): return {}
		if not ["W_START", "W_FLOW", "W_ECHO"].has(data.equipped_weapon) or (data.equipped_weapon != "W_START" and not data.owned_gear.has(data.equipped_weapon)): return {}
		if not ["", "A_EMBER"].has(data.equipped_accessory) or (data.equipped_accessory == "A_EMBER" and not data.owned_gear.has("A_EMBER")): return {}
		for id in ["POWER", "VITALITY", "MOBILITY"]:
			if not data.growth_ranks.has(id) or not data.growth_ranks[id] is float or not is_finite(data.growth_ranks[id]) or data.growth_ranks[id] != floor(data.growth_ranks[id]) or int(data.growth_ranks[id]) < 0 or int(data.growth_ranks[id]) > (5 if int(data.version) >= 7 else 2): return {}
		for id in data.growth_ranks:
			if int(data.version) < 7 and id in ["SLASH_POWER", "RECOVERY"] and data.growth_ranks[id] != 0.0: return {}
			if not GROWTH_IDS.has(id) or not data.growth_ranks[id] is float or not is_finite(data.growth_ranks[id]) or data.growth_ranks[id] != floor(data.growth_ranks[id]) or int(data.growth_ranks[id]) < 0 or int(data.growth_ranks[id]) > (5 if int(data.version) >= 7 else 2): return {}
		if int(data.supply_count) < 0 or int(data.supply_count) > SUPPLY_LIMIT: return {}
		if int(data.version) >= 3:
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
	if int(data.version) >= 4:
		if not data.get("attack_branch") is String or not ([""] + ATTACK_BRANCHES).has(data.attack_branch): return {}
		if not data.attack_branch.is_empty():
			var invested := 0
			for id in ["POWER", "WISP", "SLASH", "FINISH"]: invested += int(data.growth_ranks.get(id, 0))
			if invested < 4: return {}
	if int(data.version) >= 5:
		if not data.get("discovered_places") is Array or not data.get("awakenings") is Array: return {}
		if data.discovered_places.size() > (2 if int(data.version) >= 6 else 1) or data.awakenings.size() > (2 if int(data.version) >= 6 else 1): return {}
		var seen_places := {}
		for id in data.discovered_places:
			if not id is String or seen_places.has(id) or not (["TEMPLE_GARDEN", "JUNGLE_GROTTO"] if int(data.version) >= 6 else ["TEMPLE_GARDEN"]).has(id): return {}
			seen_places[id] = true
		var seen_awakenings := {}
		for id in data.awakenings:
			if not id is String or seen_awakenings.has(id): return {}
			if id == "EMBER_GARDEN" and not data.discovered_places.has("TEMPLE_GARDEN"): return {}
			if id == "ECHO_GROTTO" and (int(data.version) < 6 or not data.discovered_places.has("JUNGLE_GROTTO")): return {}
			if not ["EMBER_GARDEN", "ECHO_GROTTO"].has(id): return {}
			seen_awakenings[id] = true
	return data


static func _valid_mod(mod_id: String) -> bool:
	for gear_id in GEAR_AFFIXES:
		if GEAR_AFFIXES[gear_id].has(mod_id): return true
	return false
