extends RefCounted
## Machine-local preferences. Never reads or writes progression/profile slots.
## Master gain multiplies the authored relative volume of every sound player.

const DEFAULT_PATH := "user://play_settings.cfg"
const VERSION := 1

var config_path := DEFAULT_PATH
var volume_percent := 100.0
var muted := false
var fullscreen := false
var last_load_error := OK
var last_save_error := OK
var window: Window
var _windowed_size := Vector2i.ZERO
var _windowed_position := Vector2i.ZERO
var _have_windowed_geometry := false


func setup(target_window: Window) -> void:
	window = target_window
	_read_runtime()
	load_preferences()


func _master_bus() -> int:
	return AudioServer.get_bus_index("Master")


func _read_runtime() -> void:
	var bus := _master_bus()
	if bus >= 0:
		volume_percent = clampf(db_to_linear(AudioServer.get_bus_volume_db(bus)) * 100.0, 0.0, 100.0)
		muted = AudioServer.is_bus_mute(bus)
	fullscreen = window.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]
	_remember_windowed_geometry()


func load_preferences() -> void:
	var config := ConfigFile.new()
	last_load_error = config.load(config_path)
	if last_load_error != OK:
		return # Missing/corrupt preferences preserve the current engine defaults.
	var version: Variant = config.get_value("settings", "version", null)
	if not version is int or version != VERSION:
		return
	var volume: Variant = config.get_value("audio", "master_volume", null)
	var mute: Variant = config.get_value("audio", "muted", null)
	var has_volume := (volume is float or volume is int) and is_finite(float(volume)) and float(volume) >= 0.0 and float(volume) <= 100.0
	var has_mute := mute is bool
	if has_volume: volume_percent = float(volume)
	if has_mute: muted = mute
	if has_volume or has_mute: _apply_audio()
	var mode: Variant = config.get_value("display", "mode", null)
	if mode is String and mode in ["windowed", "fullscreen"]:
		set_fullscreen(mode == "fullscreen")


func set_volume(value: float) -> void:
	if not is_finite(value): return
	volume_percent = clampf(value, 0.0, 100.0)
	_apply_audio()


func set_muted(value: bool) -> void:
	muted = value
	_apply_audio()


func _apply_audio() -> void:
	var bus := _master_bus()
	if bus < 0: return
	# Avoid -INF at zero; the Master mute flag guarantees actual silence.
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume_percent / 100.0, 0.0001)))
	AudioServer.set_bus_mute(bus, muted or volume_percent <= 0.0)


func _remember_windowed_geometry() -> void:
	if window.mode == Window.MODE_WINDOWED:
		_windowed_size = window.size
		_windowed_position = window.position
		_have_windowed_geometry = true


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	if value:
		_remember_windowed_geometry()
		if window.mode not in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]:
			window.mode = Window.MODE_FULLSCREEN
	elif window.mode != Window.MODE_WINDOWED:
		window.mode = Window.MODE_WINDOWED
		if _have_windowed_geometry:
			window.size = _windowed_size
			window.position = _windowed_position


func save_preferences() -> Error:
	var config := ConfigFile.new()
	config.set_value("settings", "version", VERSION)
	config.set_value("audio", "master_volume", volume_percent)
	config.set_value("audio", "muted", muted)
	config.set_value("display", "mode", "fullscreen" if fullscreen else "windowed")
	# Keep the previous usable file if a write fails.
	last_save_error = config.save(config_path + ".tmp")
	if last_save_error == OK:
		last_save_error = DirAccess.rename_absolute(config_path + ".tmp", config_path)
	return last_save_error
