extends Node3D

const PLAYER_SCENE := preload("res://entities/player/player.tscn")

func _ready() -> void:
	var p := PLAYER_SCENE.instantiate()
	p.name = "Player_1"
	add_child(p)
	var vcn := p.get_node("VoiceChatNetwork")
	assert(vcn != null, "VoiceChatNetwork node should exist")
	var player := vcn.get_node("AudioStreamPlayer3D")
	assert(player != null, "AudioStreamPlayer3D should exist")
	var gen: AudioStreamGenerator = player.stream
	assert(gen != null, "Generator stream should be assigned")
	player.play()
	print("PROOF DIRECT: EOS voice node wired, watching 5s")
	get_tree().create_timer(5.0).timeout.connect(_done)

func _done() -> void:
	print("PROOF DIRECT: survived 5s, quitting cleanly")
	get_tree().quit(0)