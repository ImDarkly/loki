extends GutTest

var _network: Node


func before_each() -> void:
	var scene := load("res://systems/voice_chat/voice_chat_network.tscn")
	_network = autofree(scene.instantiate())
	add_child(_network)


func test_instantiation_audio_player3d_resolves() -> void:
	var player := _network.get_node_or_null("AudioStreamPlayer3D") as AudioStreamPlayer3D
	assert_not_null(player, "AudioStreamPlayer3D node should exist")


func test_audio_player3d_has_opus_stream() -> void:
	var player := _network.get_node_or_null("AudioStreamPlayer3D") as AudioStreamPlayer3D
	assert_not_null(player.stream, "AudioStreamPlayer3D should have a stream after _enter_tree")
	assert_true(is_instance_of(player.stream, AudioStreamOpus), "Stream should be AudioStreamOpus")


func test_two_voip_speaker_resolves() -> void:
	var speaker := _network.get_node_or_null("AudioStreamPlayer3D/TwoVoipSpeaker")
	assert_not_null(speaker, "TwoVoipSpeaker child should exist under AudioStreamPlayer3D")


func test_audio_player3d_defaults() -> void:
	var player := _network.get_node_or_null("AudioStreamPlayer3D") as AudioStreamPlayer3D
	assert_eq(player.volume_db, 24.0, "volume_db should default to 24.0")
	assert_eq(player.unit_size, 8.0, "unit_size should default to 8.0")
	assert_eq(player.max_distance, 25.0, "max_distance should default to 25.0")
	assert_eq(player.attenuation_model, 0, "attenuation_model should be Inverse (0)")
