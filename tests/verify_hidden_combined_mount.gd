extends SceneTree
## Verify actual mounting; never install a missing helper from the fixture.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)
func _run() -> void:
	for name in ["hybrid_region", "temple_circuit_run", "jungle_south_circuit", "deep_wetland_run"]:
		var prefix := "user://combined_mount_%s_%d" % [name, Time.get_ticks_usec()]
		var profile := RunProfile.new()
		profile.save_prefix = prefix + "_profile"
		check(profile.settle("fixture-temple-access", "SUCCESS", 0, RunProfile.TEMPLE_REGION), "isolated temple access")
		check(profile.settle("fixture-jungle-access", "SUCCESS", 0, RunProfile.JUNGLE_REGION), "isolated jungle access")
		var scene = load("res://game/" + name + ".tscn").instantiate()
		scene.profile_save_prefix = profile.save_prefix
		scene.growth_save_prefix = prefix + "_growth"
		root.add_child(scene)
		for i in 2: await process_frame
		scene.set_physics_process(false)
		scene.simulation.process_mode = Node.PROCESS_MODE_DISABLED
		var section = scene.temple_section
		check(scene.BOSS_TIME == 240.0, name + " keeps 240-second clock")
		if name == "deep_wetland_run":
			# Even prior discoveries cannot make an inherited fake hidden marker.
			scene.profile.discovered_places.append("TEMPLE_GARDEN")
			scene.profile.discovered_places.append("JUNGLE_GROTTO")
			check(section.hidden_visual_root == null and section.main_entry_root == null and section.exit_label == null, "wetland has no hidden visual roots")
			check(section.discovery_marker().is_empty(), "wetland prior discoveries do not create a fake marker")
			section._refresh_hidden_labels()
			section.tick(0.0)
			scene.minimap._draw()
			check(not section.in_garden and scene.garden_terrain_mesh == null, "wetland null guards preserve main field")
		else:
			check(section.discovery_marker().is_empty(), name + " undiscovered entrance has no marker")
			if name in ["hybrid_region", "temple_circuit_run"]:
				check(section.hidden_visual_root.get_node_or_null("TempleGardenCourtyard") != null, name + " actual courtyard helper")
				check(section.main_entry_root.get_node_or_null("TempleGardenCloisterHint") != null and section.main_entry_root.get_child_count() == 1, name + " entry helper replaces old bush loop")
				if name == "temple_circuit_run":
					var threshold_floors: Array = scene.terrain.floor_areas.filter(func(record): return record.get("discovery_id", "") == "TEMPLE_GARDEN" and not section.field_area.encloses(record.area))
					check(threshold_floors.size() == 1 and threshold_floors[0].height == 0.5 and threshold_floors[0].area == section.layout.ENTRY_TRIGGER.grow(30.0), "circuit threshold is exactly 0.5 at active entry")
			section.enter_garden()
			check(section.in_garden and section.hidden_visual_root.visible and not section.main_entry_root.visible, name + " roots switch on actual entry")
			check(section.discovery_marker().point == section.layout.ALTAR, name + " hidden marker uses actual layout")
			section.leave_garden()
			check(not section.in_garden and not section.hidden_visual_root.visible and section.main_entry_root.visible, name + " roots switch on actual return")
			check(section.discovery_marker().point == section.layout.ENTRY_TRIGGER.get_center(), name + " return marker uses actual entrance")
		scene.queue_free()
		paused = false
		await process_frame
	print("COMBINED_MOUNT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
