extends Node3D

signal feedback_completed

@onready var catch_audio: AudioStreamPlayer = $CanvasLayer/CatchAudio
@onready var feedback_label: Label = $CanvasLayer/CatchFeedbackLabel
@onready var screen_flash: ColorRect = $CanvasLayer/ScreenFlash
@onready var escape_audio: AudioStreamPlayer = $CanvasLayer/EscapeAudio

var feedback_tween: Tween = null


func _ready() -> void:
	catch_audio.stream = _generate_ding_stream()
	escape_audio.stream = _generate_whoosh_stream()
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


func play_catch_escape() -> void:
	if feedback_tween and feedback_tween.is_valid():
		feedback_tween.kill()

	escape_audio.stop()
	escape_audio.play()

	feedback_tween = create_tween()
	feedback_tween.tween_interval(0.2)
	feedback_tween.tween_callback(_on_feedback_complete)


func _on_feedback_complete() -> void:
	feedback_label.visible = false
	screen_flash.modulate = Color(1, 1, 1, 0)
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


func _generate_whoosh_stream() -> AudioStreamWAV:
	var duration: float = 0.2
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
		var progress: float = float(i) / float(sample_count)

		var envelope: float = min(t / 0.005, 1.0) * max(0.0, 1.0 - max(t - 0.18, 0.0) / 0.02)

		var freq: float = lerp(1200.0, 100.0, progress)
		var tone: float = sin(t * TAU * freq) * 0.3

		var noise: float = randf_range(-1.0, 1.0) * 0.4

		var sample: float = (tone + noise) * envelope
		sample = clamp(sample, -1.0, 1.0)

		var s: int = clampi(int(sample * 16384), -32768, 32767)
		var offset: int = i * 2
		data[offset] = s & 0xFF
		data[offset + 1] = (s >> 8) & 0xFF

	wav.data = data
	return wav
