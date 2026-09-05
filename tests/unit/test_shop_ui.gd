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


func _get_shop_row(flag: StringName) -> VBoxContainer:
	return shop_ui.get_node_or_null("MarginContainer/VBoxContainer/ShopItemsContainer/ShopRow_" + str(flag)) as VBoxContainer


func _get_row_buy_button(flag: StringName) -> Button:
	var row := _get_shop_row(flag)
	if row == null:
		return null
	return row.get_node_or_null("TopRow/BuyButton") as Button


func _get_row_title_label(flag: StringName) -> Label:
	var row := _get_shop_row(flag)
	if row == null:
		return null
	return row.get_node_or_null("TopRow/TitleLabel") as Label


func _get_row_desc_label(flag: StringName) -> Label:
	var row := _get_shop_row(flag)
	if row == null:
		return null
	return row.get_node_or_null("DescLabel") as Label


func _get_fireplace_buy_button() -> Button:
	return _get_row_buy_button(&"fireplace_owned")


func _get_fireplace_label() -> Label:
	return _get_row_title_label(&"fireplace_owned")


func _set_owned(flag: StringName, owned: bool) -> void:
	match flag:
		&"fireplace_owned":
			coin_manager.fireplace_owned = owned
		&"shark_bait_owned":
			coin_manager.shark_bait_owned = owned


func test_shop_ui_has_no_upgrade_rows() -> void:
	assert_null(shop_ui.get_node_or_null("MarginContainer/VBoxContainer/MaxHealthRow"),
		"MaxHealthRow should not exist")
	assert_null(shop_ui.get_node_or_null("MarginContainer/VBoxContainer/RodSpeedRow"),
		"RodSpeedRow should not exist")


func test_hardcoded_rows_removed() -> void:
	assert_null(shop_ui.get_node_or_null("MarginContainer/VBoxContainer/FireplaceRow"),
		"FireplaceRow should not exist")
	assert_null(shop_ui.get_node_or_null("MarginContainer/VBoxContainer/SharkBaitRow"),
		"SharkBaitRow should not exist")


func test_shop_has_one_row_per_shop_item() -> void:
	var container := shop_ui.get_node("MarginContainer/VBoxContainer/ShopItemsContainer") as VBoxContainer
	assert_eq(container.get_child_count(), coin_manager.shop_items.size())
	for item in coin_manager.shop_items:
		assert_not_null(_get_shop_row(item.owned_flag_property),
			"Missing row for " + str(item.owned_flag_property))


func test_each_row_has_inline_description() -> void:
	for item in coin_manager.shop_items:
		var desc := _get_row_desc_label(item.owned_flag_property)
		assert_not_null(desc, "Missing desc for " + str(item.owned_flag_property))
		assert_eq(desc.text, item.description)
		assert_true(desc.visible)


func test_row_descriptions_match_prd_copy() -> void:
	assert_eq(_get_row_desc_label(&"fireplace_owned").text, "Sit here to heal over time.")
	assert_eq(_get_row_desc_label(&"shark_bait_owned").text,
		"Fill with fish to distract the shark and save your health.")


func test_buy_button_state_matrix() -> void:
	var flags: Array[StringName] = [&"fireplace_owned", &"shark_bait_owned"]
	for flag in flags:
		_set_owned(flag, true)
		coin_manager.coins = 20
		shop_ui._update_ui()
		assert_eq(_get_row_buy_button(flag).text, "Owned")
		assert_true(_get_row_buy_button(flag).disabled)

		_set_owned(flag, false)
		coin_manager.coins = 999
		shop_ui._update_ui()
		assert_eq(_get_row_buy_button(flag).text, "Buy")
		assert_false(_get_row_buy_button(flag).disabled)

		_set_owned(flag, false)
		coin_manager.coins = 0
		shop_ui._update_ui()
		assert_true(_get_row_buy_button(flag).disabled)
		assert_ne(_get_row_buy_button(flag).text, "Buy")
		assert_ne(_get_row_buy_button(flag).text, "Owned")


func test_fireplace_buy_button_shows_buy_when_affordable() -> void:
	coin_manager.coins = 20
	coin_manager.fireplace_owned = false
	shop_ui._update_ui()
	assert_eq(_get_fireplace_buy_button().text, "Buy")
	assert_false(_get_fireplace_buy_button().disabled)


func test_fireplace_buy_button_shows_owned_when_purchased() -> void:
	coin_manager.coins = 20
	coin_manager.fireplace_owned = true
	shop_ui._update_ui()
	assert_eq(_get_fireplace_buy_button().text, "Owned")
	assert_true(_get_fireplace_buy_button().disabled)


func test_fireplace_buy_button_disabled_when_insufficient_coins() -> void:
	coin_manager.coins = 0
	coin_manager.fireplace_owned = false
	shop_ui._update_ui()
	assert_true(_get_fireplace_buy_button().disabled, "Buy button should be disabled")
	assert_ne(_get_fireplace_buy_button().text, "Buy", "Should not show Buy text")
	assert_ne(_get_fireplace_buy_button().text, "Owned", "Should not show Owned text")


func test_fireplace_label_shows_name_and_cost() -> void:
	var item = shop_ui._get_shop_item(&"fireplace_owned")
	if item:
		item.cost = 15
	shop_ui._update_ui()
	var text = _get_fireplace_label().text
	assert_true(text.contains("Fireplace"), "Label should contain fireplace name")
	assert_true(text.contains("15"), "Label should contain cost")


func test_successful_fireplace_buy_updates_coin_label() -> void:
	coin_manager.coins = 20
	shop_ui._update_ui()
	assert_true(_get_coin_label().text.contains("20"), "Coin label should show 20 before buy")
	_get_fireplace_buy_button().pressed.emit()
	shop_ui._update_ui()
	assert_true(_get_coin_label().text.contains("5"), "Coin label should show 5 after buy")
	assert_true(coin_manager.is_fireplace_owned(), "Fireplace should be owned after buy")


func test_failed_fireplace_buy_does_not_change_coin_label() -> void:
	coin_manager.coins = 5
	shop_ui._update_ui()
	var before = _get_coin_label().text
	_get_fireplace_buy_button().pressed.emit()
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
