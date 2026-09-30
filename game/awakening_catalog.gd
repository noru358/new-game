extends RefCounted

# Presentation of the two existing permanent rewards. No new save data.
const ENTRIES := {
	"EMBER_GARDEN": {"place": "TEMPLE_GARDEN", "place_name": "숨은 정원", "gear": "A_EMBER", "title": "정원의 불씨", "before": "여우불 장신구 · 마탄 피해 보너스 +15%", "after": "마탄 피해 보너스 +35% · 연쇄 대상 +1", "condition": "여우불 장신구 착용 시 적용. 카드·옵션의 추가 효과와 합산됩니다."},
	"ECHO_GROTTO": {"place": "JUNGLE_GROTTO", "place_name": "폭포 뒤 숨은 계곡", "gear": "W_ECHO", "title": "계곡의 메아리", "before": "집결의 마력장 · 3타 집결 지점에서 4타 폭발", "after": "4타 적중 0.25초 뒤 같은 지점에 추가 폭발", "condition": "집결의 마력장 착용 + 4타 적중 시 발동. 추가 폭발은 4타 기본 피해의 35%로 작은 범위를 공격합니다."},
}


static func status(profile, id: String, lifetime_levelups: int) -> String:
	if not profile.awakenings.has(id): return "미획득"
	var gear: String = ENTRIES[id].gear
	if not profile.owned_gear.has(gear):
		if gear == "W_ECHO" and not profile.jungle_owned: return "보유 · 정글 첫 정복 후 장비 구매 필요"
		return "보유 · 야영지에서 장비 구매 필요"
	if profile.equipped_weapon != gear and profile.equipped_accessory != gear: return "보유 · 해당 장비 미착용"
	if id == "ECHO_GROTTO" and lifetime_levelups < 3: return "장착됨 · 누적 레벨업 3회로 4타 습득 필요"
	return "적용 중" + (" · 4타 적중 시 발동" if id == "ECHO_GROTTO" else " · 여우불 마탄에 적용")


static func comparison(id: String) -> String:
	var entry: Dictionary = ENTRIES[id]
	return "[color=#a5bbb5]획득 전\n%s[/color]\n\n[color=#f5d99c]획득 후\n%s[/color]\n\n[font_size=18]%s[/font_size]" % [entry.before, entry.after, entry.condition]


static func records(profile, lifetime_levelups: int) -> String:
	var lines: Array[String] = []
	for id in ENTRIES:
		var entry: Dictionary = ENTRIES[id]
		if not profile.discovered_places.has(entry.place): continue
		if not profile.awakenings.has(id):
			lines.append("%s\n장소 발견 · 영구 보상은 아직 얻지 않았습니다." % entry.place_name)
			continue
		lines.append("%s — %s\n%s\n\n%s" % [entry.place_name, entry.title, status(profile, id, lifetime_levelups), comparison(id)])
	return "아직 기록된 장소가 없습니다.\n여행 중 발견한 장소와 얻은 각성이 여기에 남습니다." if lines.is_empty() else "\n\n────────────────────\n\n".join(lines)


static func equipped_summary(profile, lifetime_levelups: int) -> String:
	var lines: Array[String] = []
	for id in ENTRIES:
		if profile.awakenings.has(id): lines.append("%s · %s" % [ENTRIES[id].title, status(profile, id, lifetime_levelups)])
	return "획득한 각성 없음" if lines.is_empty() else "\n".join(lines)
