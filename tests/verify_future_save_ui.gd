extends SceneTree
var failures := 0
var checks := 0
var prefix := "user://verify_future_save_ui_%d" % Time.get_ticks_usec()
func _initialize():
 call_deferred("_run")
func _check(ok: bool, message: String):
 checks += 1
 if not ok:
  failures += 1
  printerr("FAIL: ", message)
func _run():
 var valid = RunProfile.new()._snapshot()
 valid.currency = 17
 var future = valid.duplicate(true)
 future.version = 7
 future.generation = 2
 future.currency = 101
 for suffix in ["_a.json", "_b.json"]:
  var file = FileAccess.open(prefix + suffix, FileAccess.WRITE)
  file.store_string(JSON.stringify(valid if suffix == "_a.json" else future))
  file.close()
 var bytes_a = FileAccess.get_file_as_bytes(prefix + "_a.json")
 var bytes_b = FileAccess.get_file_as_bytes(prefix + "_b.json")
 var hub = load("res://game/hub.tscn").instantiate()
 hub.profile_save_prefix = prefix
 hub.growth_save_prefix = prefix + "_unlocks"
 root.add_child(hub)
 await process_frame
 _check(hub.start_button.disabled, "real preparation departure button disabled")
 _check(hub.status_label.text.contains("업데이트") and not hub.status_label.text.contains("백업"), "real preparation explains update, not corrupt recovery")
 _check(hub.save_folder_button.visible, "existing save-folder action remains available")
 _check(hub.gear_action_button.disabled and hub.supply_buy_button.disabled and hub.reset_button.disabled, "preparation mutations disabled")
 var nodes = root.get_child_count()
 hub._depart()
 _check(root.get_child_count() == nodes, "programmatic departure callback stays blocked")
 hub.queue_free()
 await process_frame
 var region = load("res://game/hybrid_region.tscn").instantiate()
 region.profile_save_prefix = prefix
 region.growth_save_prefix = prefix + "_unlocks"
 root.add_child(region)
 await process_frame
 await process_frame
 _check(region.profile.load_error and region.run_ended and region.paused and paused, "direct region entry stops the run and simulation")
 _check(region.result_overlay.visible and region.result_text.text.contains("업데이트"), "direct entry shows update guidance")
 _check(region.replay_button.disabled and not region.retry_button.visible, "direct entry blocks replay and repair retry")
 _check(region.profile.generation == 0 and region.profile.currency == 0, "future data never appears as a successful award")
 _check(not region.profile.settle("ui-settle", "SUCCESS", 9), "real scene profile settlement blocked")
 paused = false
 region.queue_free()
 await process_frame
 _check(bytes_a == FileAccess.get_file_as_bytes(prefix + "_a.json") and bytes_b == FileAccess.get_file_as_bytes(prefix + "_b.json"), "both scene paths preserve exact slot bytes")
 for suffix in ["_a.json", "_b.json", "_unlocks_a.json", "_unlocks_b.json"]:
  DirAccess.remove_absolute(prefix + suffix)
 if failures == 0: print("Future save UI mount verification passed: ", checks, " checks; real preparation and direct-entry scenes")
 quit(1 if failures else 0)
