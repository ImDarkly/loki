extends GutTest

var manager: Node3D
var quota_manager: Node3D
var _main: Node3D
func _as_server() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(0, 1)
	multiplayer.multiplayer_peer = peer


func before_each() -> void:
	_main = Node3D.new()
	_main.name = "main"
	get_tree().root.add_child(_main)

	var scene: PackedScene = load("res://systems/coin_manager/coin_manager.tscn")
	manager = scene.instantiate()
	_main.add_child(manager)

	quota_manager = Node3D.new()
	quota_manager.name = "QuotaManager"
	quota_manager.set_script(load("res://systems/quota/quota_manager.gd"))
	_main.add_child(quota_manager)
	quota_manager.shared_quota = 0
	await get_tree().process_frame


func after_each() -> void:
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer != null:
		peer.close()
	multiplayer.multiplayer_peer = null
	if is_instance_valid(_main):
		_main.free()


func test_sell_all_converts_fish_to_coins() -> void:
	_as_server()
	quota_manager.shared_quota = 10
	manager.coins_per_fish = 2

	manager.sell_all()

	assert_eq(manager.coins, 20, "10 fish * 2 coins/fish = 20 coins")
	assert_eq(quota_manager.shared_quota, 0, "shared_quota should be zeroed after sell")


func test_sell_all_zeroes_quota() -> void:
	_as_server()
	quota_manager.shared_quota = 5

	manager.sell_all()

	assert_eq(quota_manager.shared_quota, 0, "shared_quota should be 0 after sell")


func test_sell_all_noop_when_no_fish() -> void:
	_as_server()
	quota_manager.shared_quota = 0
	manager.coins = 10

	manager.sell_all()

	assert_eq(manager.coins, 10, "coins should remain unchanged")
	assert_eq(quota_manager.shared_quota, 0, "shared_quota should stay 0")


func test_buy_upgrade_deducts_coins() -> void:
	_as_server()
	manager.coins = 50

	manager.buy_upgrade("extra_rod")

	assert_eq(manager.coins, 40, "50 - 10 = 40 coins remaining")
	assert_eq(manager._upgrades.get("extra_rod", false), true, "extra_rod should be owned")


func test_buy_upgrade_rejects_insufficient_coins() -> void:
	_as_server()
	manager.coins = 5

	manager.buy_upgrade("extra_rod")

	assert_eq(manager.coins, 5, "coins should not change")
	assert_eq(manager._upgrades.get("extra_rod", false), false, "extra_rod should not be owned")


func test_buy_upgrade_rejects_already_owned() -> void:
	_as_server()
	manager.coins = 50
	manager._upgrades["extra_rod"] = true

	manager.buy_upgrade("extra_rod")

	assert_eq(manager.coins, 50, "coins should not change")
	assert_eq(manager._upgrades.get("extra_rod", false), true, "extra_rod should remain owned")


func test_buy_upgrade_rejects_unknown_upgrade() -> void:
	_as_server()
	manager.coins = 50

	manager.buy_upgrade("nonexistent")

	assert_eq(manager.coins, 50, "coins should not change for unknown upgrade")


func test_non_server_does_not_change_coins() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", 12345)
	multiplayer.multiplayer_peer = peer
	quota_manager.shared_quota = 10
	manager.coins = 0

	manager.sell_all()

	assert_eq(manager.coins, 0, "non-host should not modify local coins directly")
