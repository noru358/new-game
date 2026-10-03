extends "res://game/hybrid_region.gd"
## Development scene only. Existing attack transforms/flash remain inherited;
## all states use idle art until the parent approves animation scope.
const FennecIdle = preload("res://game/fennec_idle_adapter.gd")

func _ready() -> void:
	if not OS.get_user_data_dir().contains("FennecIdle-"):
		push_error("Fennec development preview requires isolated UUID userdata")
		get_tree().quit(2)
		return
	super._ready()
	FennecIdle.configure(actors[player].get_node("Body"))

func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(player) and actors.has(player):
		FennecIdle.update(actors[player].get_node("Body"), player.facing, camera)
