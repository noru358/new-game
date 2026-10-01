extends Node3D

const PreparationScene = preload("res://game/hub.tscn")
const WALK_SPEED := 3.8
const CAMP_LIMIT := 5.6
const INTERACT_RANGE := 2.35
var profile_save_prefix := "user://loop_conquest_profile"
var growth_save_prefix := "user://loop_conquest_1d_unlocks"

var player_visual: Node3D
var camera: Camera3D
var preparation: Control
var settings_panel: CanvasLayer
var settings_button: Button
var prompt: Label
var stations := [
	{"name": "출정", "position": Vector3(-3.5, 0.0, -1.5), "tab": 0, "color": Color("72d3c7")},
	{"name": "장비", "position": Vector3(3.4, 0.0, -1.4), "tab": 1, "color": Color("e4bc79")},
	{"name": "성장", "position": Vector3(0.0, 0.0, 3.3), "tab": 2, "color": Color("b7a8e5")},
]


func _ready() -> void:
	get_window().title = "Loop Conquest — 이동 야영지"
	_build_camp()
	_build_overlay()
	_update_prompt()


func _process(delta: float) -> void:
	if preparation.visible: return
	var input := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
	)
	if input.length_squared() > 0.0:
		input = input.normalized()
		var right := Vector3(camera.global_basis.x.x, 0.0, camera.global_basis.x.z).normalized()
		var forward := Vector3(-camera.global_basis.z.x, 0.0, -camera.global_basis.z.z).normalized()
		var direction := right * input.x + forward * input.y
		var next_position: Vector3 = player_visual.position + direction * WALK_SPEED * delta
		next_position.x = clampf(next_position.x, -CAMP_LIMIT, CAMP_LIMIT)
		next_position.z = clampf(next_position.z, -CAMP_LIMIT, CAMP_LIMIT)
		for station in stations:
			if Vector2(next_position.x - station.position.x, next_position.z - station.position.z).length() < 0.75:
				next_position = player_visual.position
				break
		player_visual.position = next_position
		player_visual.rotation.y = atan2(direction.x, direction.z)
	_update_prompt()


func _unhandled_key_input(event: InputEvent) -> void:
	if settings_panel != null and settings_panel.is_open(): return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE and preparation.visible:
		preparation.hide()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE:
		settings_panel.open(settings_button)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_E and not preparation.visible:
		var station := _nearest_station()
		if station.distance <= INTERACT_RANGE:
			preparation.open_section(station.tab)
			preparation.show()
			get_viewport().set_input_as_handled()
	_update_prompt()


func _nearest_station() -> Dictionary:
	var nearest := {"distance": INF, "name": "", "tab": 0}
	for station in stations:
		var distance: float = player_visual.position.distance_to(station.position)
		if distance < nearest.distance:
			nearest = {"distance": distance, "name": station.name, "tab": station.tab}
	return nearest


func _update_prompt() -> void:
	settings_button.visible = not preparation.visible
	if preparation.visible:
		prompt.hide()
		return
	prompt.show()
	var station := _nearest_station()
	prompt.text = "E · %s" % station.name if station.distance <= INTERACT_RANGE else "WASD 이동 · 시설에 접근"


func _build_camp() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("203745")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b8c6b5")
	settings.ambient_light_energy = 0.75
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_color = Color("ffe1ad")
	sun.light_energy = 1.25
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 16.0
	camera.position = Vector3(9.0, 11.0, 10.0)
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	_box(Vector3(0, -0.35, 0), Vector3(13.0, 0.7, 13.0), Color("526257"))
	_box(Vector3(0, -0.02, 0), Vector3(10.8, 0.08, 10.8), Color("899477"))
	for i in 5:
		_box(Vector3(-6.2 + i * 3.1, -0.55, -7.5), Vector3(3.0, 1.5 + float(i % 2), 2.5), Color("536067"))
		_box(Vector3(-6.2 + i * 3.1, -0.7, 7.4), Vector3(3.0, 1.6, 2.5), Color("465759"))
	_build_tent(Vector3(-4.4, 0.0, 3.7), Color("bd9c73"))
	_build_tent(Vector3(4.35, 0.0, 3.8), Color("b6a18a"))
	for x in [-0.48, 0.48]:
		_box(Vector3(x, 0.12, -3.55), Vector3(1.30, 0.16, 0.20), Color("4a3b31")).rotation.y = 0.58 if x < 0.0 else -0.58
	var fire := MeshInstance3D.new()
	var flame := SphereMesh.new()
	flame.radius = 0.28
	flame.height = 0.56
	fire.mesh = flame
	fire.material_override = _material(Color("ffad55"))
	fire.position = Vector3(0, 0.35, -3.55)
	add_child(fire)
	var fire_light := OmniLight3D.new()
	fire_light.position = fire.position + Vector3(0, 0.3, 0)
	fire_light.light_color = Color("ffba6e")
	fire_light.light_energy = 1.5
	fire_light.omni_range = 4.0
	add_child(fire_light)
	for station in stations:
		_build_station(station)
	player_visual = Node3D.new()
	player_visual.position = Vector3(0, 0, 0)
	add_child(player_visual)
	var mantle := _box(Vector3(0, 0.63, 0), Vector3(0.48, 0.95, 0.32), Color("e7c39b"), player_visual)
	mantle.name = "Traveler"
	_box(Vector3(0, 1.15, 0), Vector3(0.38, 0.38, 0.38), Color("f6d4a3"), player_visual)
	_box(Vector3(0, 0.69, 0.22), Vector3(0.32, 0.75, 0.12), Color("409d9a"), player_visual)


func _build_station(station: Dictionary) -> void:
	var center: Vector3 = station.position
	_box(center + Vector3(0, 0.35, 0), Vector3(1.35, 0.70, 0.9), Color("786751"))
	_box(center + Vector3(0, 0.75, 0), Vector3(1.55, 0.13, 1.05), Color("ae9671"))
	var glow := MeshInstance3D.new()
	var orb := SphereMesh.new()
	orb.radius = 0.17
	orb.height = 0.34
	glow.mesh = orb
	glow.material_override = _material(station.color)
	glow.position = center + Vector3(0, 1.10, 0)
	add_child(glow)
	var sign := Label3D.new()
	sign.text = station.name
	sign.font_size = 36
	sign.pixel_size = 0.013
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = center + Vector3(0, 1.63, 0)
	add_child(sign)


func _build_tent(center: Vector3, cloth: Color) -> void:
	var tent := MeshInstance3D.new()
	var roof := CylinderMesh.new()
	roof.top_radius = 0.08
	roof.bottom_radius = 1.25
	roof.height = 1.75
	roof.radial_segments = 4
	tent.mesh = roof
	tent.material_override = _material(cloth)
	tent.position = center + Vector3(0, 0.84, 0)
	tent.rotation.y = PI * 0.25
	add_child(tent)
	_box(center + Vector3(0, 0.02, 0), Vector3(2.15, 0.10, 2.15), Color("6b5b48"))


func _box(at: Vector3, dimensions: Vector3, color: Color, parent: Node3D = self) -> MeshInstance3D:
	var block := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	block.mesh = mesh
	block.material_override = _material(color)
	block.position = at
	parent.add_child(block)
	return block


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material


func _build_overlay() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	prompt = Label.new()
	prompt.position = Vector2(24, 20)
	prompt.add_theme_font_size_override("font_size", 20)
	prompt.add_theme_color_override("font_color", Color("fff0ca"))
	prompt.add_theme_color_override("font_shadow_color", Color.BLACK)
	canvas.add_child(prompt)
	preparation = PreparationScene.instantiate()
	preparation.embedded_in_camp = true
	preparation.profile_save_prefix = profile_save_prefix
	preparation.growth_save_prefix = growth_save_prefix
	canvas.add_child(preparation)
	preparation.hide()
	settings_panel = preload("res://game/play_settings_panel.gd").new()
	settings_panel.setup(self)
	settings_button = Button.new()
	settings_button.name = "PlaySettingsButton"
	settings_button.text = "설정  [Esc]"
	settings_button.position = Vector2(1112, 16)
	settings_button.size = Vector2(144, 44)
	settings_button.add_theme_font_size_override("font_size", 20)
	settings_button.pressed.connect(func(): settings_panel.open(settings_button))
	canvas.add_child(settings_button)
