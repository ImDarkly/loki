extends Node

signal yelling_state_changed(is_yelling: bool)

@export var voice_bus_name: String = "GDRecord"
@export var amplitude_threshold_on: float = -12.0
@export var amplitude_threshold_off: float = -14.0

var is_yelling: bool = false

var _bus_index: int = -1
var _bus_error_logged: bool = false


func _process(_delta: float) -> void:
	if _bus_index == -1:
		var idx := AudioServer.get_bus_index(voice_bus_name)
		if idx == -1:
			if not _bus_error_logged:
				push_warning("Voice chat bus not found. Voice yelling disabled.")
				_bus_error_logged = true
			return
		_bus_index = idx

	_update_yelling_state(_get_peak_volume_db())


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
