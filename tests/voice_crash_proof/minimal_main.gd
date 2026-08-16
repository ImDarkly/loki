extends Node

const MAIN := preload("res://scenes/main.tscn")

func _ready() -> void:
	game_manager.add_player(1, "Host")
	create_timer(1.0).timeout.connect(_mount_minimal)

func _mount_minimal() -> void:
	var main := MAIN.instantiate()
	for c in main.get_children():
		if c.name != "Players":
			main.remove_child(c)
			c.free()
	main.name = "main"
	var players := main.get_node("Players")
	var old_spawner := players.get_node_or_null("MultiplayerSpawner")
	if old_spawner:
		players.remove_child(old_spawner)
		var new_spawner := MultiplayerSpawner.new()
		new_spawner.name = "MultiplayerSpawner"
		new_spawner.spawn_path = players.get_path_to(players)
		players.add_child(new_spawner)
	players.spawn_function = _spawn_player
	players.multiplayer.peer_disconnected.connect(players._on_peer_disconnected)
	call_deferred("add_child", main)
	create_timer(2.0).timeout.connect(_trigger)

func _spawn_player(_scene: PackedScene) -> Node:
	var player := (preload("res://entities/player/player.tscn") as PackedScene).instantiate()
	player.name = "Player_1"
	player.spawn_index = 0
	return player

func _trigger() -> void:
	print("PROOF[minimal]: spawning 1 player under main/Players")
	game_manager.spawn_manager.trigger_spawn()
	create_timer(15.0).timeout.connect(func(): print("PROOF[minimal]: survived 15s"); get_tree().quit())