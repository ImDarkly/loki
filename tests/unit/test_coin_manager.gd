extends GutTest

var coin_manager: CoinManager
var quota_manager: Node3D


func before_each() -> void:
	coin_manager = autofree(load("res://systems/quota/coin_manager.tscn").instantiate())
	add_child(coin_manager)
	await get_tree().process_frame

	var main = Node3D.new()
	main.name = "main"
	get_node("/root").add_child(main)

	quota_manager = load("res://systems/quota/quota_manager.tscn").instantiate()
	quota_manager.name = "QuotaManager"
	main.add_child(quota_manager)
	await get_tree().process_frame


func after_each() -> void:
	var main = get_node_or_null("/root/main")
	if main:
		main.queue_free()


func test_sell_all_converts_fish_to_coins() -> void:
	quota_manager.shared_quota = 5
	coin_manager.request_sell_all()
	assert_eq(coin_manager.coins, 5, "Coins should equal fish count * coins_per_fish")
	assert_eq(quota_manager.shared_quota, 0, "Shared quota should be zero after sell")


func test_sell_all_with_zero_fish_does_nothing() -> void:
	quota_manager.shared_quota = 0
	coin_manager.request_sell_all()
	assert_eq(coin_manager.coins, 0, "Coins should remain 0 when no fish to sell")


func test_sell_all_multiplies_by_coins_per_fish() -> void:
	coin_manager.coins_per_fish = 3
	quota_manager.shared_quota = 4
	coin_manager.request_sell_all()
	assert_eq(coin_manager.coins, 12, "Coins should equal fish * coins_per_fish")


func test_sell_all_emits_coins_updated() -> void:
	quota_manager.shared_quota = 3
	watch_signals(coin_manager)
	coin_manager.request_sell_all()
	assert_signal_emitted(coin_manager, "coins_updated")
