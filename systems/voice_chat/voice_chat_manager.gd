extends Node

# GD-Sync's VoiceChat node creates audio buses dynamically and handles recording
# internally. The bus name it uses is not publicly documented — the VoiceChat docs
# state: "All required audio bus setup is handled automatically by the VoiceChat Node."
# Source: https://www.gd-sync.com/docs/custom-node-types (VoiceChat section)
#
# The Godot ecosystem convention for recording buses (used in Godot's official
# microphone recording demo and community VOIP plugins) is "Record".
# We use "VoiceChatRecord" as the mock bus name to match this convention while
# keeping it distinguishable from any future real recording bus.
#
# This manager provides a mock audio bus so VoiceChatManager can query
# AudioServer.get_bus_peak_volume_left_db() without GD-Sync installed.
const RECORDING_BUS_NAME := "VoiceChatRecord"

const NOISE_FLOOR_DB := -80.0

var _record_bus_idx: int = -1
var _mock_player: AudioStreamPlayer = null
var _playback: AudioStreamGeneratorPlayback = null
var _synthetic_db: float = NOISE_FLOOR_DB


func _ready() -> void:
	_ensure_recording_bus()
	_setup_mock_player()


func _ensure_recording_bus() -> void:
	var idx := AudioServer.get_bus_index(RECORDING_BUS_NAME)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, RECORDING_BUS_NAME)
	_record_bus_idx = idx


func _setup_mock_player() -> void:
	_mock_player = AudioStreamPlayer.new()
	_mock_player.name = "MockMicrophone"
	_mock_player.bus = RECORDING_BUS_NAME

	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 44100
	generator.buffer_length = 0.1
	_mock_player.stream = generator

	add_child(_mock_player)
	_mock_player.play()

	_playback = _mock_player.get_stream_playback()


func get_peak_volume_db() -> float:
	if _record_bus_idx == -1:
		return NOISE_FLOOR_DB
	var bus_peak := AudioServer.get_bus_peak_volume_left_db(_record_bus_idx, 0)
	return max(bus_peak, _synthetic_db)


func get_peak_volume_db_audio_server() -> float:
	if _record_bus_idx == -1:
		return NOISE_FLOOR_DB
	return AudioServer.get_bus_peak_volume_left_db(_record_bus_idx, 0)


func inject_synthetic_amplitude(db_value: float) -> void:
	_synthetic_db = db_value

	var mix_rate := 44100.0
	var sample_count := int(mix_rate * 0.01)

	if _playback == null or not _playback.can_push_buffer(sample_count):
		return

	var amplitude := db_to_linear(db_value)
	var frequency := 440.0
	var phase := 0.0
	var phase_increment := frequency / mix_rate * TAU

	var buffer := PackedVector2Array()
	buffer.resize(sample_count)

	for i in range(sample_count):
		var sample := sin(phase) * amplitude
		buffer[i] = Vector2(sample, sample)
		phase += phase_increment
		if phase >= TAU:
			phase -= TAU

	_playback.push_buffer(buffer)


func get_bus_index() -> int:
	return _record_bus_idx
