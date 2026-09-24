extends Node

const PORT := 46469
const MAIN := preload("res://scenes/main.tscn")

func _ready() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, 4)
	print("PROOF[host-v4]: server err=", err)
	multiplayer.multiplayer_peer = peer
	game_manager.add_player(1, "Host")
	multiplayer.peer_connected.connect(_on_host_peer_connected)
	get_tree().create_timer(40.0).timeout.connect(func(): print("PROOF[host-v4]: 40s watchdog, quitting"); get_tree().quit())

func _on_host_peer_connected(id: int) -> void:
	print("PROOF[host-v4]: client ", id, " connected, adding player, mounting main.tscn locally")
	game_manager.add_player(id, "Player_%d" % id)
	await get_tree().create_timer(0.5).timeout
	var main := MAIN.instantiate()
	get_tree().root.add_child(main)
	await get_tree().create_timer(2.0).timeout
	print("PROOF[host-v4]: triggering spawn")
	game_manager.spawn_manager.trigger_spawn()