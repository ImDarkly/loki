extends GutTest

var _network: Node


func before_each() -> void:
	var scene := load("res://systems/voice_chat/eos_voice_network.tscn")
	_network = autofree(scene.instantiate())
	add_child(_network)


func test_instantiation_audio_player3d_resolves() -> void:
	var player := _network.get_node_or_null("AudioStreamPlayer3D") as AudioStreamPlayer3D
	assert_not_null(player, "AudioStreamPlayer3D node should exist")


func test_audio_player3d_has_generator_stream() -> void:
	var player := _network.get_node_or_null("AudioStreamPlayer3D") as AudioStreamPlayer3D
	assert_not_null(player.stream, "AudioStreamPlayer3D should have a stream after _ready")
	assert_true(is_instance_of(player.stream, AudioStreamGenerator), "Stream should be AudioStreamGenerator")


func test_audio_player3d_defaults() -> void:
	var player := _network.get_node_or_null("AudioStreamPlayer3D") as AudioStreamPlayer3D
	assert_eq(player.volume_db, 24.0, "volume_db should default to 24.0")
	assert_eq(player.unit_size, 8.0, "unit_size should default to 8.0")
	assert_eq(player.max_distance, 0.0, "max_distance should default to 0.0 (no cutoff)")
	assert_eq(player.attenuation_model, 1, "attenuation_model should be Inverse (1)")


func test_playback_resolves_after_ready() -> void:
	assert_not_null(_network._playback, "Generator playback should be created in _ready")


func test_no_room_no_subscription() -> void:
	await get_tree().process_frame
	assert_false(_network._configured, "Setup should not complete without a lobby rtc room name")
	assert_false(_network._configured_authoritative, "Authority flag should stay false before config")


func test_frames_to_push_data_mono() -> void:
	var frames: Array = [0, 32767, -32768, 16384]
	var out: PackedVector2Array = _network._frames_to_push_data(frames, 1)
	assert_eq(out.size(), 4, "Mono input produces one frame per sample")
	assert_eq(out[0], Vector2.ZERO, "0 -> (0,0)")
	assert_eq(out[1], Vector2(32767.0 / 32768.0, 32767.0 / 32768.0), "32767 maps to ~1.0")
	assert_eq(out[2], Vector2(-1.0, -1.0), "-32768 maps to -1.0")


func test_frames_to_push_data_stereo() -> void:
	var frames: Array = [0, 32767, -32768, 16384]
	var out: PackedVector2Array = _network._frames_to_push_data(frames, 2)
	assert_eq(out.size(), 2, "Stereo interleaved input produces half the frame count")
	assert_eq(out[0], Vector2(0.0, 32767.0 / 32768.0), "First pair (L=0, R=32767)")
	assert_eq(out[1], Vector2(-1.0, 16384.0 / 32768.0), "Second pair (L=-32768, R=16384)")


func test_captured_to_send_frames_pads_with_silence() -> void:
	var captured := PackedVector2Array([Vector2(0.5, 0.5)])
	var frames: PackedInt32Array = _network._captured_to_send_frames(captured, 4)
	assert_eq(frames.size(), 4, "Output size should match requested count")
	assert_eq(frames[0], 16384, "Mono mix of 0.5 scales to 16384 (int16)")
	assert_eq(frames[3], 0, "Missing frames pad with silence")
