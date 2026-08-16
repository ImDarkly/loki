extends Node

const PORT := 46467

func _ready() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, 4)
	print("PROOF[solo]: server err=", err)
	multiplayer.multiplayer_peer = peer
	game_manager.add_player(1, "Host")
	game_manager.add_player(9999, "Player_9999")
	get_tree().create_timer(1.0).timeout.connect(_start_game_scene)
	get_tree().create_timer(40.0).timeout.connect(func(): print("PROOF[solo]: 40s watchdog, quitting"); get_tree().quit())

func _start_game_scene() -> void:
	print("PROOF[solo]: loading main.tscn with 2 local players (no second process)")
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	get_tree().create_timer(2.0).timeout.connect(_trigger_spawn)

func _trigger_spawn() -> void:
	print("PROOF[solo]: triggering spawn")
	game_manager.spawn_manager.trigger_spawn()