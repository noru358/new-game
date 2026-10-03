extends "res://tests/capture_temple_place_sequence.gd"
## Bounded surface comparison on the real production scene/camera/input path.
const Finish = preload("res://game/temple_surface_sample.gd")
func _initialize() -> void:
	root.mode = Window.MODE_WINDOWED
	super._initialize()
func _samples() -> Array:
	return [
		{"name":"03-west-stairs","point":Vector2(1650,2275)},
		{"name":"04-open-court","point":Vector2(2450,2100)},
		{"name":"06-cloister","point":Vector2(1450,1350)},
		{"name":"08-gallery-turn","point":Vector2(1650,910)},
		{"name":"09-sanctuary-reveal","point":Vector2(2650,1000)},
		{"name":"10-human-door","point":Vector2(2800,460)},
	]
func _walk(goal: Vector2) -> void:
	Finish.install(scene)
	await super._walk(goal)
