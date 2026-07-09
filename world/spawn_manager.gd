extends Node3D

const PLAYER_SCENE := preload("res://entities/player/player.tscn")

@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	game_manager._on_scene_loaded()


func trigger_spawn() -> void:
	if not multiplayer.is_server():
		return
	for i in game_manager.players.size():
		var player := spawner.spawn() as Player
		var peer_id := game_manager.players[i].id
		player.name = "Player_%d" % peer_id
		player.spawn_index = i


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	var node := get_node_or_null("Player_%d" % id)
	if node:
		node.queue_free()