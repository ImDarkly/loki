extends Node

signal yelling_state_changed(is_yelling: bool)
signal mic_level_updated(level_db: float)

@export var voice_bus_name: String = "GDRecord"
@export var amplitude_threshold_on: float = -6.0
@export var amplitude_threshold_off: float = -8.0
@export var auto_create_bus: bool = true
@export var preferred_input_device: String = ""

var is_yelling: bool = false

var _bus_index: int = -1
var _bus_error_logged: bool = false
var _mic_error_logged: bool = false


func _process(_delta: float) -> void:
	if _bus_index == -1:
		_bus_index = AudioServer.get_bus_index(voice_bus_name)
		if _bus_index == -1:
			if auto_create_bus:
				_auto_create_bus()
			else:
				if not _bus_error_logged:
					push_warning("Voice chat bus not found. Voice yelling disabled.")
					_bus_error_logged = true
				return
		if _bus_index == -1:
			return

	var peak := _get_peak_volume_db()
	_update_yelling_state(peak)
	mic_level_updated.emit(peak)


func _create_mic_stream() -> AudioStreamMicrophone:
	return AudioStreamMicrophone.new()


func _auto_create_bus() -> void:
	if preferred_input_device != "":
		var devices := AudioServer.get_input_device_list()
		if preferred_input_device in devices:
			AudioServer.input_device = preferred_input_device
		else:
			push_warning("Preferred input device not found: %s" % preferred_input_device)
			AudioServer.input_device = "Default"
	else:
		AudioServer.input_device = "Default"

	AudioServer.add_bus()
	var null_idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(null_idx, "DevNull")
	AudioServer.set_bus_volume_db(null_idx, -INF)

	AudioServer.add_bus()
	var rec_idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(rec_idx, voice_bus_name)
	AudioServer.set_bus_send(rec_idx, "DevNull")

	var capture := AudioEffectCapture.new()
	AudioServer.add_bus_effect(rec_idx, capture, 0)

	var mic := _create_mic_stream()
	if not is_instance_valid(mic):
		if not _mic_error_logged:
			push_warning("Voice chat microphone unavailable. Voice yelling disabled.")
			_mic_error_logged = true
		_bus_index = rec_idx
		return

	var mic_player := AudioStreamPlayer.new()
	mic_player.stream = mic
	mic_player.bus = voice_bus_name
	mic_player.name = "MicrophoneInput"
	add_child(mic_player)
	mic_player.play()

	_bus_index = rec_idx


func _get_peak_volume_db() -> float:
	if _bus_index < 0 or _bus_index >= AudioServer.bus_count:
		return -INF
	return AudioServer.get_bus_peak_volume_left_db(_bus_index, 0)


func _update_yelling_state(amplitude: float) -> void:
	var previous := is_yelling

	if not is_yelling and amplitude >= amplitude_threshold_on:
		is_yelling = true
	elif is_yelling and amplitude < amplitude_threshold_off:
		is_yelling = false

	if is_yelling != previous:
		yelling_state_changed.emit(is_yelling)
