extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
	var prefix := "user://qa_wetland_profile_%d" % Time.get_ticks_usec()
	var profile := RunProfile.new()
	profile.save_prefix = prefix
	check(RunProfile.SAVE_VERSION==7,"extensible owned-id schema stays version seven")
	check(not profile.region_available(RunProfile.WETLAND_REGION),"wetland initially locked")
	check(not profile.settle("blocked","SUCCESS",100,RunProfile.WETLAND_REGION) and profile.currency==0,"locked settlement cannot mint currency")
	check(profile.settle("temple","SUCCESS",100,RunProfile.TEMPLE_REGION),"temple clear")
	check(not profile.region_available(RunProfile.WETLAND_REGION),"temple alone does not open third region")
	check(profile.settle("jungle","SUCCESS",100,RunProfile.JUNGLE_REGION),"jungle clear")
	check(profile.region_available(RunProfile.WETLAND_REGION),"jungle opens wetland")
	var before := profile.currency
	check(profile.settle("wetland","SUCCESS",100,RunProfile.WETLAND_REGION),"wetland settlement saved")
	check(profile.wetland_owned and profile.currency==before+150,"existing first-clear reward policy")
	check(profile.settle("wetland","SUCCESS",100,RunProfile.WETLAND_REGION) and profile.currency==before+150,"first-clear receipt idempotent")
	check(profile.settle("wetland-repeat","SUCCESS",100,RunProfile.WETLAND_REGION),"reclear settlement")
	check(profile.currency==before+270,"reclear never repeats first-clear bonus")
	check(RunProfile.REGION_MODS[RunProfile.WETLAND_REGION].has(profile.last_mod_award),"reclear grants an existing supported option")
	check("습지" in RunProfile.affix_source(profile.last_mod_award),"option source reflects third region")
	var old = preload("res://tests/fixtures/run_profile_v7_before_wetland.gd").new()
	old.save_prefix=prefix
	old.load_state()
	check(not old.load_error and old.currency==profile.currency,"actual old v7 reader accepts new owned id")
	check(old.owned_outpost_ids.has(RunProfile.WETLAND_REGION),"old reader retains wetland id")
	check(old.buy_growth("VITALITY"),"actual old client writes an ordinary purchase")
	var reopened:=RunProfile.new()
	reopened.save_prefix=prefix
	reopened.load_state()
	check(not reopened.load_error and reopened.wetland_owned,"new reader preserves progress after old-client write")
	check(reopened.currency==profile.currency-20 and reopened.growth_ranks.VITALITY==1,"purchase and currency survive round trip")
	var folder:=DirAccess.open("user://")
	for file in folder.get_files():
		if file.begins_with(prefix.trim_prefix("user://")): folder.remove(file)
	print("Wetland profile compatibility: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
func check(ok:bool,note:String)->void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",note)
