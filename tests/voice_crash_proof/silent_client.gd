extends Node

const PORT := 46469

func _ready() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client("127.0.0.1", PORT)
	print("PROOF[silent-client]: client err=", err)
	multiplayer.multiplayer_peer = peer
	get_tree().create_timer(40.0).timeout.connect(_on_watchdog)


func _on_watchdog() -> void:
	print("PROOF[silent-client]: 40s watchdog, quitting")
	get_tree().quit()