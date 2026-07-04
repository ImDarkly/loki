extends Node3D

const PLAYER_SCENE := preload("res://entities/player/player.tscn")


func _ready() -> void:
	if not GDSync.is_host():
		return
	_spawn_players()


func _spawn_players() -> void:
	for i in game_manager.players.size():
		var player := GDSync.multiplayer_instantiate(PLAYER_SCENE, self, true, [], true)
		player.spawn_index = i
