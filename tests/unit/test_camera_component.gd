extends GutTest

var _camera_comp: CameraComponent
var _player: Player

func before_each() -> void:
	_player = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	_player.name = "Player"
	add_child(_player)
	_camera_comp = _player.get_node("CameraComponent") as CameraComponent

func after_each() -> void:
	if _player and is_instance_valid(_player):
		_player.free()
	_player = null

func test_camera_component_setup() -> void:
	assert_not_null(_camera_comp, "CameraComponent should exist on player")
	assert_eq(_camera_comp.mouse_sensitivity, 0.002, "default mouse_sensitivity should be 0.002")

func test_cycle_spectate_target_empty() -> void:
	_camera_comp.cycle_spectate_target()
	assert_null(_camera_comp._spectate_target, "spectate target should be null when no other players")
