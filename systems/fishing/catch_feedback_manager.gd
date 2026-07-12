extends Node3D

signal feedback_completed

@onready var catch_audio: AudioStreamPlayer = $CanvasLayer/CatchAudio
@onready var feedback_label: Label = $CanvasLayer/CatchFeedbackLabel
@onready var screen_flash: ColorRect = $CanvasLayer/ScreenFlash

var feedback_tween: Tween = null
var _default_feedback_text: String = ""


func _ready() -> void:
	catch_audio.stream = _generate_ding_stream()
	_default_feedback_text = feedback_label.text
	feedback_label.visible = false
	screen_flash.modulate = Color(1, 1, 1, 0)


func play_catch_success() -> void:
	if feedback_tween and feedback_tween.is_valid():
		feedback_tween.kill()

	feedback_label.visible = true
	feedback_label.modulate = Color(1, 1, 1, 1)

	catch_audio.stop()
	catch_audio.play()

	screen_flash.modulate = Color(1, 1, 1, 0.5)

	feedback_tween = create_tween()
	feedback_tween.tween_property(screen_flash, "modulate", Color(1, 1, 1, 0), 0.1)
	feedback_tween.tween_interval(1.9)
	feedback_tween.tween_callback(_on_feedback_complete)


func play_dead_zone_feedback() -> void:
	if feedback_tween and feedback_tween.is_valid():
		feedback_tween.kill()

	screen_flash.modulate = Color(1, 1, 1, 0)
	feedback_label.text = "Nothing's biting..."
	feedback_label.visible = true
	feedback_label.modulate = Color(1, 1, 1, 1)

	feedback_tween = create_tween()
	feedback_tween.tween_interval(2.0)
	feedback_tween.tween_callback(_on_feedback_complete)


func _on_feedback_complete() -> void:
	feedback_label.visible = false
	feedback_label.text = _default_feedback_text
	feedback_completed.emit()


func _generate_ding_stream() -> AudioStreamWAV:
	var duration: float = 0.05
	var sample_rate: int = 44100
	var sample_count: int = int(duration * sample_rate)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false

	var data := PackedByteArray()
	data.resize(sample_count * 2)

	for i in range(sample_count):
		var t: float = float(i) / float(sample_rate)

		var envelope: float = exp(-t * 60.0)

		var fund: float = sin(t * TAU * 880.0) * 0.5
		var harm1: float = sin(t * TAU * 1760.0) * 0.25
		var harm2: float = sin(t * TAU * 2640.0) * 0.125

		var sample: float = (fund + harm1 + harm2) * envelope
		sample = clamp(sample, -1.0, 1.0)

		var s: int = clampi(int(sample * 16384), -32768, 32767)
		var offset: int = i * 2
		data[offset] = s & 0xFF
		data[offset + 1] = (s >> 8) & 0xFF

	wav.data = data
	return wav
