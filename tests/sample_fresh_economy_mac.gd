extends "res://tests/sample_fresh_economy.gd"
## Same three-run driver, real camp buttons, purchases and settlement as prior
## sampler. Only the platform isolation gate accepts the UUID Mac launcher.
var resume_checkpoint: Dictionary = {}

func _isolated_empty_home() -> bool:
	var expected := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--expected-user-dir="): expected = argument.trim_prefix("--expected-user-dir=")
	if expected.is_empty() or OS.get_user_data_dir().simplify_path() != expected.simplify_path() or not expected.contains("/LoopConquestFlowSamples/") or not FileAccess.file_exists("user://flow-sample-owner.json"):
		failure = "Require exact launcher-owned UUID user directory"
		return false
	for prefix in ["user://loop_conquest_profile", "user://loop_conquest_1d_unlocks"]:
		for suffix in ["_a.json", "_b.json"]:
			if FileAccess.file_exists(prefix + suffix): failure = "Require empty isolated campaign slots"; return false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--resume-checkpoint="):
			var path := argument.trim_prefix("--resume-checkpoint=")
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if not parsed is Dictionary or parsed.get("sample") != "fresh_economy_input_journey_v1" or parsed.get("runs", []).size() != 1:
				failure = "Require the preserved one-run journey checkpoint"; return false
			resume_checkpoint = parsed.runs[0].after_shopping
			var profile := RunProfile.new()
			profile.currency = int(resume_checkpoint.currency)
			profile.growth_ranks = resume_checkpoint.growth.duplicate()
			profile.owned_gear = resume_checkpoint.owned_gear.duplicate()
			profile.owned_mods.assign(resume_checkpoint.owned_mods)
			profile.slotted_mods = resume_checkpoint.slotted_mods.duplicate()
			profile.equipped_weapon = resume_checkpoint.weapon
			profile.equipped_accessory = resume_checkpoint.accessory
			profile.owned_outpost_ids.assign(resume_checkpoint.owned_outposts)
			profile.awakenings.assign(resume_checkpoint.awakenings)
			profile.attack_branch = resume_checkpoint.attack_branch
			if not profile._commit(profile._snapshot()): failure = "Checkpoint fixture save failed"; return false
			var unlocks := UnlockProgress.new()
			unlocks.lifetime_levelups = int(resume_checkpoint.lifetime_levelups)
			unlocks._save_progress()
	isolation_root = expected
	return true

func _shop(hub, run_number: int, purchases: Array) -> void:
	await super._shop(hub, run_number + (1 if not resume_checkpoint.is_empty() else 0), purchases)

func _finish() -> void:
	if not resume_checkpoint.is_empty():
		journey["resume_checkpoint"] = resume_checkpoint
		journey["resume_note"] = "Runs1/2 here continue original runs2/3 from the preserved run1 after-shopping ledger; fixture-only reconstruction after host disconnect. No partial run2 unlock progress is reused. No bonus or clear was invented. The original run1 report remains separately preserved."
	super._finish()
