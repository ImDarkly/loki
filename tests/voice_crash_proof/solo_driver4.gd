extends Node

const MAIN := preload("res://scenes/main.tscn")

func _ready() -> void:
	var main := MAIN.instantiate()
	call_deferred("add_child", main)
	get_tree().create_timer(1.5).timeout.connect(_add_and_spawn)
	get_tree().create_timer(40.0).timeout.connect(_watchdog)

func _add_and_spawn() -> void:
	game_manager.add_player(1, "Host")
	print("PROOF[solo1c]: spawning exactly ONE player under main/Players")
	game_manager.spawn_manager.trigger_spawn()

func _watchdog() -> void:
	print("PROOF[solo1c]: 40s watchdog, quitting")
	get_tree().quit()