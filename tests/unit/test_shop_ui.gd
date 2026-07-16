extends GutTest

var shop_ui: PanelContainer
var coin_manager: CoinManager
var quota_manager: Node3D
var _main: Node3D


func before_each() -> void:
	_main = Node3D.new()
	_main.name = "main"
	get_node("/root").add_child(_main)

	coin_manager = load("res://systems/quota/coin_manager.tscn").instantiate()
	coin_manager.name = "CoinManager"
	_main.add_child(coin_manager)

	quota_manager = load("res://systems/quota/quota_manager.tscn").instantiate()
	quota_manager.name = "QuotaManager"
	_main.add_child(quota_manager)

	shop_ui = load("res://ui/shop_ui.tscn").instantiate()
	add_child(shop_ui)
	await get_tree().process_frame


func after_each() -> void:
	if _main and is_instance_valid(_main):
		_main.free()
	_main = null


func _get_sell_all_button() -> Button:
	return shop_ui.get_node("MarginContainer/VBoxContainer/SellAllButton") as Button


func _get_max_health_buy_button() -> Button:
	return shop_ui.get_node("MarginContainer/VBoxContainer/MaxHealthRow/MaxHealthBuyButton") as Button


func _get_rod_speed_buy_button() -> Button:
	return shop_ui.get_node("MarginContainer/VBoxContainer/RodSpeedRow/RodSpeedBuyButton") as Button


func _get_coin_label() -> Label:
	return shop_ui.get_node("MarginContainer/VBoxContainer/CoinLabel") as Label


func _get_fish_label() -> Label:
	return shop_ui.get_node("MarginContainer/VBoxContainer/FishLabel") as Label


func _get_max_health_label() -> Label:
	return shop_ui.get_node("MarginContainer/VBoxContainer/MaxHealthRow/MaxHealthLabel") as Label


func test_buy_button_shows_buy_when_affordable() -> void:
	coin_manager.coins = 20
	coin_manager.max_health_upgrade_owned = false
	shop_ui._update_ui()
	assert_eq(_get_max_health_buy_button().text, "Buy")
	assert_false(_get_max_health_buy_button().disabled)


func test_buy_button_shows_owned_when_purchased() -> void:
	coin_manager.coins = 20
	coin_manager.max_health_upgrade_owned = true
	shop_ui._update_ui()
	assert_eq(_get_max_health_buy_button().text, "Owned")
	assert_true(_get_max_health_buy_button().disabled)


func test_buy_button_disabled_when_insufficient_coins() -> void:
	coin_manager.coins = 0
	coin_manager.max_health_upgrade_owned = false
	shop_ui._update_ui()
	assert_true(_get_max_health_buy_button().disabled, "Buy button should be disabled")
	assert_ne(_get_max_health_buy_button().text, "Buy", "Should not show Buy text")
	assert_ne(_get_max_health_buy_button().text, "Owned", "Should not show Owned text")


func test_rod_speed_button_shows_buy_when_affordable() -> void:
	coin_manager.coins = 20
	coin_manager.rod_pull_speed_upgrade_owned = false
	shop_ui._update_ui()
	assert_eq(_get_rod_speed_buy_button().text, "Buy")
	assert_false(_get_rod_speed_buy_button().disabled)


func test_rod_speed_button_shows_owned_when_purchased() -> void:
	coin_manager.coins = 20
	coin_manager.rod_pull_speed_upgrade_owned = true
	shop_ui._update_ui()
	assert_eq(_get_rod_speed_buy_button().text, "Owned")
	assert_true(_get_rod_speed_buy_button().disabled)


func test_successful_buy_updates_coin_label() -> void:
	coin_manager.coins = 20
	shop_ui._update_ui()
	assert_true(_get_coin_label().text.contains("20"), "Coin label should show 20 before buy")
	coin_manager.request_buy_upgrade("max_health")
	shop_ui._update_ui()
	assert_true(_get_coin_label().text.contains("10"), "Coin label should show 10 after buy")


func test_failed_buy_does_not_change_coin_label() -> void:
	coin_manager.coins = 5
	shop_ui._update_ui()
	var before = _get_coin_label().text
	coin_manager.request_buy_upgrade("max_health")
	shop_ui._update_ui()
	assert_eq(_get_coin_label().text, before, "Coin label should not change when buy fails")


func test_sell_all_updates_fish_and_coin_labels() -> void:
	quota_manager.shared_quota = 3
	coin_manager.coins = 0
	shop_ui._update_ui()
	assert_true(_get_fish_label().text.contains("3"))
	assert_true(_get_coin_label().text.contains("0"))
	coin_manager.request_sell_all()
	shop_ui._update_ui()
	assert_true(_get_fish_label().text.contains("0"), "Fish label should show 0 after sell")
	assert_true(_get_coin_label().text.contains("3"), "Coin label should show 3 after sell")


func test_sell_all_button_disabled_when_no_fish() -> void:
	quota_manager.shared_quota = 0
	shop_ui._update_ui()
	assert_true(_get_sell_all_button().disabled, "Sell All should be disabled when no fish")


func test_sell_all_button_enabled_when_fish_available() -> void:
	quota_manager.shared_quota = 1
	shop_ui._update_ui()
	assert_false(_get_sell_all_button().disabled, "Sell All should be enabled when fish > 0")


func test_upgrade_label_shows_name_and_cost() -> void:
	coin_manager.max_health_upgrade_cost = 15
	shop_ui._update_ui()
	var text = _get_max_health_label().text
	assert_true(text.contains("Max Health"), "Label should contain upgrade name")
	assert_true(text.contains("15"), "Label should contain cost")
