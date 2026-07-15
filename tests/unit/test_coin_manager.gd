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


func test_buy_upgrade_success_deducts_coins_and_marks_owned() -> void:
	coin_manager.coins = 20
	coin_manager.request_buy_upgrade("max_health")
	assert_eq(coin_manager.coins, 10, "Coins should decrease by upgrade cost")
	assert_true(coin_manager.max_health_upgrade_owned, "Upgrade should be marked owned")


func test_buy_rod_pull_speed_upgrade() -> void:
	coin_manager.coins = 20
	coin_manager.request_buy_upgrade("rod_pull_speed")
	assert_eq(coin_manager.coins, 10, "Coins should decrease by upgrade cost")
	assert_true(coin_manager.rod_pull_speed_upgrade_owned, "Upgrade should be marked owned")


func test_buy_upgrade_insufficient_coins_does_nothing() -> void:
	coin_manager.coins = 5
	coin_manager.request_buy_upgrade("max_health")
	assert_eq(coin_manager.coins, 5, "Coins should not change when insufficient")
	assert_false(coin_manager.max_health_upgrade_owned, "Upgrade should remain unowned")


func test_buy_upgrade_already_owned_does_nothing() -> void:
	coin_manager.coins = 20
	coin_manager.max_health_upgrade_owned = true
	coin_manager.request_buy_upgrade("max_health")
	assert_eq(coin_manager.coins, 20, "Coins should not change when already owned")


func test_buy_upgrade_unknown_name_does_nothing() -> void:
	coin_manager.coins = 20
	coin_manager.request_buy_upgrade("nonexistent")
	assert_eq(coin_manager.coins, 20, "Coins should not change for unknown upgrade")


func test_sell_all_emits_coins_updated() -> void:
	quota_manager.shared_quota = 3
	watch_signals(coin_manager)
	coin_manager.request_sell_all()
	assert_signal_emitted(coin_manager, "coins_updated")


func test_buy_upgrade_emits_upgrades_updated() -> void:
	coin_manager.coins = 20
	watch_signals(coin_manager)
	coin_manager.request_buy_upgrade("max_health")
	assert_signal_emitted(coin_manager, "upgrades_updated")


func test_buy_upgrade_emits_coins_updated() -> void:
	coin_manager.coins = 20
	watch_signals(coin_manager)
	coin_manager.request_buy_upgrade("max_health")
	assert_signal_emitted(coin_manager, "coins_updated")


func test_get_upgrade_cost() -> void:
	assert_eq(coin_manager.get_upgrade_cost("max_health"), coin_manager.max_health_upgrade_cost)
	assert_eq(coin_manager.get_upgrade_cost("rod_pull_speed"), coin_manager.rod_pull_speed_upgrade_cost)
	assert_eq(coin_manager.get_upgrade_cost("nonexistent"), -1)


func test_is_upgrade_owned() -> void:
	assert_false(coin_manager.is_upgrade_owned("max_health"))
	coin_manager.max_health_upgrade_owned = true
	assert_true(coin_manager.is_upgrade_owned("max_health"))
	assert_false(coin_manager.is_upgrade_owned("rod_pull_speed"))
	assert_false(coin_manager.is_upgrade_owned("nonexistent"))
