extends "res://systems/voice_chat/voice_chat_manager.gd"

var mic_should_fail: bool = true


func _create_mic_stream() -> AudioStreamMicrophone:
	return null if mic_should_fail else AudioStreamMicrophone.new()
