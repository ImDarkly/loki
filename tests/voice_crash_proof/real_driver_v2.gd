extends Node

const PORT := 46466

func _ready() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, 4)
	print("PROOF[host-v2]: server err=", err)
	multiplayer.multiplayer_peer = peer
	game_manager.add_player(1, "Host")
	multiplayer.peer_connected.connect(_on_host_peer_connected)
	get_tree().create_timer(40.0).timeout.connect(func(): print("PROOF[host-v2]: 40s watchdog, quitting"); get_tree().quit())

func _on_host_peer_connected(id: int) -> void:
	print("PROOF[host-v2]: client ", id, " connected (silent), starting game in 0.5s")
	game_manager.add_player(id, "Player_%d" % id)
	await get_tree().create_timer(0.5).timeout
	game_manager.start_game()