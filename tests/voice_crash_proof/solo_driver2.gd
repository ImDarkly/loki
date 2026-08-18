extends Node

const MAIN := preload("res://scenes/main.tscn")

func _ready() -> void:
	game_manager.add_player(1, "Host")
	game_manager.add_player(2, "Player_2")
	print("PROOF[solo2]: mounting main.tscn, NO network peer")
	var main := MAIN.instantiate()
	call_deferred("add_child", main)
	get_tree().create_timer(2.0).timeout.connect(_trigger_spawn)
	get_tree().create_timer(40.0).timeout.connect(func(): print("PROOF[solo2]: 40s watchdog, quitting"); get_tree().quit())

func _trigger_spawn() -> void:
	print("PROOF[solo2]: triggering spawn, no network")
	game_manager.spawn_manager.trigger_spawn()