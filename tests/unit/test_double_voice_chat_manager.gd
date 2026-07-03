extends "res://systems/voice_chat/voice_chat_manager.gd"

var mic_should_fail: bool = true
var warning_count: int = 0


func _has_input_devices() -> bool:
	return not mic_should_fail


func _report_mic_unavailable() -> void:
	warning_count += 1
	_mic_error_logged = true
