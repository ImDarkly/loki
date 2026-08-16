extends Node

const PORT := 46465

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = "host"
	if "client" in args:
		mode = "client"

	var main_scene_path := "res://scenes/main.tscn"

	if mode == "host":
		var peer := ENetMultiplayerPeer.new()
		var err := peer.create_server(PORT, 4)
		print("PROOF[host]: server err=", err)
		multiplayer.multiplayer_peer = peer
		game_manager.add_player(1, "Host")
		multiplayer.peer_connected.connect(_on_host_peer_connected)
		# When client is in and ready, start the real game flow.
	else:
		var peer := ENetMultiplayerPeer.new()
		var err := peer.create_client("127.0.0.1", PORT)
		print("PROOF[client]: client err=", err)
		multiplayer.multiplayer_peer = peer
		multiplayer.connected_to_server.connect(_on_client_connected)

	get_tree().create_timer(40.0).timeout.connect(func(): print("PROOF: 40s watchdog, quitting"); get_tree().quit())

func _on_host_peer_connected(id: int) -> void:
	print("PROOF[host]: client ", id, " connected, adding player, starting game in 0.5s")
	game_manager.add_player(id, "Player_%d" % id)
	await get_tree().create_timer(0.5).timeout
	game_manager.start_game()

func _on_client_connected() -> void:
	print("PROOF[client]: connected to host")
	game_manager._submit_username.rpc_id(1, "Client")