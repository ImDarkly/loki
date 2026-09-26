extends Node

const MAIN := preload("res://scenes/main.tscn")

func _ready() -> void:
	var main := MAIN.instantiate()
	main.set_script(null)
	call_deferred("add_child", main)
	get_tree().create_timer(1.0).timeout.connect(_add_and_spawn)
	get_tree().create_timer(30.0).timeout.connect(_watchdog)

func _add_and_spawn() -> void:
	game_manager.add_player(1, "Host")
	print("PROOF[bare-main]: main.tscn WITHOUT world_setup script (strip runs) - spawning 1 player")
	game_manager.spawn_manager.trigger_spawn()

func _watchdog() -> void:
	print("PROOF[bare-main]: 30s watchdog, quitting")
	get_tree().quit()