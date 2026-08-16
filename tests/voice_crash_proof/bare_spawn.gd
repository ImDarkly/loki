extends Node

const PLAYER_SCENE := preload("res://entities/player/player.tscn")

func _ready() -> void:
	print("PROOF[bare]: spawning 1 player via spawn_function-style path, no main.tscn")
	var player := PLAYER_SCENE.instantiate()
	player.name = "Player_1"
	player.spawn_index = 0
	add_child(player)
	get_tree().create_timer(15.0).timeout.connect(_done)


func _done() -> void:
	print("PROOF[bare]: survived 15s")
	get_tree().quit()