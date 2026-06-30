extends Node

@export var voice_bus_name: String = "VoiceChatRecordingBus"

var _bus_index: int = -1
var _bus_error_logged: bool = false


func _ready() -> void:
	pass


func _process(_delta: float) -> void:
	if _bus_index != -1:
		return

	var idx := AudioServer.get_bus_index(voice_bus_name)
	if idx == -1:
		if not _bus_error_logged:
			push_warning("Voice chat bus not found. Voice yelling disabled.")
			_bus_error_logged = true
		return

	_bus_index = idx
