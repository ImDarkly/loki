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


func _get_coin_label() -> Label:
	return shop_ui.get_node("MarginContainer/VBoxContainer/CoinLabel") as Label


func _get_fish_label() -> Label:
	return shop_ui.get_node("MarginContainer/VBoxContainer/FishLabel") as Label


func test_shop_ui_has_no_upgrade_rows() -> void:
	assert_null(shop_ui.get_node_or_null("MarginContainer/VBoxContainer/MaxHealthRow"),
		"MaxHealthRow should not exist")
	assert_null(shop_ui.get_node_or_null("MarginContainer/VBoxContainer/RodSpeedRow"),
		"RodSpeedRow should not exist")


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
