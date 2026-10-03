class_name PermanentGrowthCatalog
extends RefCounted

const MAX_RANK := 5
const IDS := ["POWER", "WISP", "SLASH", "FINISH", "VITALITY", "GUARD", "MOBILITY", "SPEED", "SLASH_POWER", "RECOVERY"]
const NAMES := {"POWER": "평타 피해", "WISP": "여우불 발사 간격", "SLASH": "이동 베기 재사용", "FINISH": "3·4타 사거리", "VITALITY": "최대 HP", "GUARD": "받는 피해", "MOBILITY": "대시 충전 시간", "SPEED": "기본 이동속도", "SLASH_POWER": "이동 베기 피해", "RECOVERY": "레벨업 회복량"}
const INCREMENTS := {"POWER": 0.05, "WISP": 0.04, "SLASH": 0.03, "FINISH": 0.05, "VITALITY": 10.0, "GUARD": 0.05, "MOBILITY": 0.04, "SPEED": 0.04, "SLASH_POWER": 0.04, "RECOVERY": 0.02}

static func empty_ranks() -> Dictionary:
	var result := {}
	for id in IDS: result[id] = 0
	return result

static func bonus(id: String, rank: int) -> float:
	var n := clampi(rank, 0, MAX_RANK)
	return float(INCREMENTS.get(id, 0.0)) * (mini(n, 2) + 0.5 * maxi(0, n - 2))

static func percent(value: float) -> String:
	return ("%.1f" % (100.0 * value)).trim_suffix(".0") + "%"

static func display_value(id: String, rank: int) -> String:
	var value := bonus(id, rank)
	match id:
		"VITALITY": return "%d" % roundi(100.0 + value)
		"WISP": return "%.2f초" % (WispCompanion.BASE_ATTACK_INTERVAL * (1.0 - value))
		"GUARD", "MOBILITY", "SLASH": return percent(1.0 - value)
		"RECOVERY": return "최대 HP " + percent(0.20 + value)
	return percent(1.0 + value)

static func apply_to_run(scene) -> void:
	var ranks: Dictionary = scene.profile.growth_ranks
	scene.player.permanent_basic_damage_bonus = bonus("POWER", int(ranks.POWER))
	scene.player.max_health += bonus("VITALITY", int(ranks.VITALITY))
	scene.player.permanent_dash_cooldown_reduction = bonus("MOBILITY", int(ranks.MOBILITY))
	scene.player.permanent_slash_cooldown_reduction = bonus("SLASH", int(ranks.SLASH))
	scene.player.permanent_finisher_reach_bonus = bonus("FINISH", int(ranks.FINISH))
	scene.player.permanent_damage_reduction = bonus("GUARD", int(ranks.GUARD))
	scene.player.permanent_move_speed_bonus = bonus("SPEED", int(ranks.SPEED))
	scene.growth.permanent_wisp_cadence_reduction = bonus("WISP", int(ranks.WISP))
	scene.player.moving_slash_damage_bonus += bonus("SLASH_POWER", int(ranks.get("SLASH_POWER", 0)))
	scene.growth.level_heal_fraction = 0.20 + bonus("RECOVERY", int(ranks.get("RECOVERY", 0)))
