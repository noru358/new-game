extends "res://game/jungle_pass.gd"
## Standalone mount for this lane. Production mount belongs to integration.
const RiverSentries = preload("res://tests/jungle_river_sentries.gd")
var fixture_trial_enabled := true

func _spawn_route_sentries(route: String, at_crest: bool) -> void:
	RiverSentries.schedule(self, route, at_crest, fixture_trial_enabled)
