extends GutTest

var _net_sync: NetworkSyncComponent
var _player: Player

func before_each() -> void:
	_player = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	_player.name = "Player"
	add_child(_player)
	_net_sync = _player.get_node("NetworkSyncComponent") as NetworkSyncComponent

func after_each() -> void:
	if _player and is_instance_valid(_player):
		_player.free()
	_player = null

func test_network_sync_component_setup() -> void:
	assert_not_null(_net_sync, "NetworkSyncComponent should exist on player")

func test_sync_yelling() -> void:
	_net_sync.sync_yelling(true)
	assert_true(_player.is_yelling, "is_yelling should update via NetworkSyncComponent")
	_net_sync.sync_yelling(false)
	assert_false(_player.is_yelling, "is_yelling should update via NetworkSyncComponent")
