extends Node

const MAIN := preload("res://scenes/main.tscn")

func _ready() -> void:
	game_manager.add_player(1, "Host")
	print("PROOF[solo1p]: mounting main.tscn, NO network, ONE player")
	var main := MAIN.instantiate()
	call_deferred("add_child", main)
	get_tree().create_timer(2.0).timeout.connect(_trigger_spawn)
	get_tree().create_timer(40.0).timeout.connect(func(): print("PROOF[solo1p]: 40s watchdog, quitting"); get_tree().quit())

func _trigger_spawn() -> void:
	print("PROOF[solo1p]: triggering spawn (1 player)")
	game_manager.spawn_manager.trigger_spawn()