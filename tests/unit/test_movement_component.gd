extends GutTest

var _movement: MovementComponent
var _player: Player

func before_each() -> void:
	_player = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	_player.name = "Player"
	add_child(_player)
	_movement = _player.get_node("MovementComponent") as MovementComponent

func after_each() -> void:
	if _player and is_instance_valid(_player):
		_player.free()
	_player = null

func test_movement_component_setup() -> void:
	assert_not_null(_movement, "MovementComponent should exist on player")
	assert_eq(_movement.walk_speed, 5.0, "default walk_speed should be 5.0")

func test_current_max_speed() -> void:
	assert_eq(_movement._current_max_speed(), 5.0, "should return walk speed by default")
