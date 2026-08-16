extends Node

func _ready() -> void:
	print("PROOF[spawner-bare]: no network, one player via MultiplayerSpawner")
	var spawner := MultiplayerSpawner.new()
	spawner.name = "MultiplayerSpawner"
	spawner.spawn_path = get_path_to(self)
	add_child(spawner)
	spawner.spawn_function = _spawn_player
	# trigger spawn after add_child settles
	get_tree().create_timer(1.0).timeout.connect(_trigger)

func _spawn_player(_scene: PackedScene) -> Node:
	var player := (preload("res://entities/player/player.tscn") as PackedScene).instantiate()
	player.name = "Player_1"
	player.spawn_index = 0
	return player

func _trigger() -> void:
	print("PROOF[spawner-bare]: spawning")
	$MultiplayerSpawner.spawn()
	get_tree().create_timer(15.0).timeout.connect(_done)

func _done() -> void:
	print("PROOF[spawner-bare]: survived 15s")
	get_tree().quit()