extends Node

const PORT := 46468

func _ready() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, 4)
	print("PROOF[host-v3]: server err=", err)
	multiplayer.multiplayer_peer = peer
	game_manager.add_player(1, "Host")
	multiplayer.peer_connected.connect(_on_host_peer_connected)
	get_tree().create_timer(40.0).timeout.connect(func(): print("PROOF[host-v3]: 40s watchdog, quitting"); get_tree().quit())

func _on_host_peer_connected(id: int) -> void:
	print("PROOF[host-v3]: client ", id, " connected, adding player, loading game LOCALLY only")
	game_manager.add_player(id, "Player_%d" % id)
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	await get_tree().create_timer(2.0).timeout
	print("PROOF[host-v3]: triggering spawn (2 local players, silent remote client)")
	game_manager.spawn_manager.trigger_spawn()