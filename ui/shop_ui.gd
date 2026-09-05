extends PanelContainer

@export var shop_items: Array[ShopItemData] = []

@onready var fish_label: Label = $MarginContainer/VBoxContainer/FishLabel
@onready var coin_label: Label = $MarginContainer/VBoxContainer/CoinLabel
@onready var close_button: Button = $MarginContainer/VBoxContainer/CloseButton
@onready var sell_all_button: Button = $MarginContainer/VBoxContainer/SellAllButton
@onready var shop_items_container: VBoxContainer = $MarginContainer/VBoxContainer/ShopItemsContainer
@onready var quota_manager: Node3D = get_node_or_null("/root/main/QuotaManager")
@onready var coin_manager: CoinManager = get_node_or_null("/root/main/CoinManager")

var _row_buttons: Dictionary = {}


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	close_button.pressed.connect(close_shop)

	if not quota_manager:
		quota_manager = get_node_or_null("/root/main/QuotaManager")
	if not coin_manager:
		coin_manager = get_node_or_null("/root/main/CoinManager")

	if not quota_manager or not coin_manager:
		push_warning("ShopUI: QuotaManager or CoinManager not found")

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_CUBIC)

	var gm := get_node_or_null("/root/game_manager")
	if gm:
		gm.shop_toggled.emit(true)

	_rebuild_shop_rows()
	_update_ui()
	if quota_manager and quota_manager.has_signal("quota_updated"):
		quota_manager.quota_updated.connect(_update_ui)
	if coin_manager:
		if coin_manager.has_signal("coins_updated"):
			coin_manager.coins_updated.connect(_update_ui)
		if coin_manager.has_signal("fireplace_updated"):
			coin_manager.fireplace_updated.connect(_update_ui)
		if coin_manager.has_signal("shark_bait_updated"):
			coin_manager.shark_bait_updated.connect(_update_ui)

	sell_all_button.pressed.connect(_on_sell_all_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_shop()


func close_shop() -> void:
	get_node("/root/game_manager").shop_toggled.emit(false)

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(func():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		queue_free()
	)


func _on_sell_all_pressed() -> void:
	if not coin_manager:
		return
	if multiplayer.has_multiplayer_peer():
		coin_manager.request_sell_all.rpc()
	else:
		coin_manager.request_sell_all()


func _on_buy_pressed(item: ShopItemData) -> void:
	if not coin_manager or not item:
		return
	var item_id := StringName(str(item.owned_flag_property).trim_suffix("_owned"))
	if multiplayer.has_multiplayer_peer():
		coin_manager.request_buy_item.rpc(item_id)
	else:
		coin_manager.request_buy_item(item_id)


func _get_shop_items() -> Array:
	if coin_manager and not coin_manager.shop_items.is_empty():
		return coin_manager.shop_items
	return shop_items


func _get_shop_item(flag_prop: StringName) -> ShopItemData:
	for item in _get_shop_items():
		if item and item.owned_flag_property == flag_prop:
			return item
	return null


func _is_owned(item: ShopItemData) -> bool:
	if not coin_manager or not item:
		return false
	match item.owned_flag_property:
		&"fireplace_owned":
			return coin_manager.is_fireplace_owned()
		&"shark_bait_owned":
			return coin_manager.is_shark_bait_owned()
	return false


func _rebuild_shop_rows() -> void:
	if not shop_items_container:
		return
	for child in shop_items_container.get_children():
		shop_items_container.remove_child(child)
		child.queue_free()
	_row_buttons.clear()
	var items := _get_shop_items()
	for item in items:
		if item == null:
			continue
		var row := VBoxContainer.new()
		row.name = "ShopRow_" + str(item.owned_flag_property)
		var top := HBoxContainer.new()
		top.name = "TopRow"
		top.add_theme_constant_override("separation", 8)
		var title := Label.new()
		title.name = "TitleLabel"
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.text = "%s — %d coins" % [item.item_name, item.cost]
		var buy := Button.new()
		buy.name = "BuyButton"
		buy.pressed.connect(_on_buy_pressed.bind(item))
		top.add_child(title)
		top.add_child(buy)
		var desc := Label.new()
		desc.name = "DescLabel"
		desc.text = item.description
		desc.modulate.a = 0.8
		desc.add_theme_font_size_override("font_size", 11)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(top)
		row.add_child(desc)
		shop_items_container.add_child(row)
		_row_buttons[item.owned_flag_property] = buy
	var coins: int = coin_manager.coins if coin_manager else 0
	for item in items:
		if item and _row_buttons.has(item.owned_flag_property):
			_update_row(item, _row_buttons[item.owned_flag_property], coins)


func _update_ui(_val: int = 0) -> void:
	if not quota_manager or not coin_manager:
		return
	var fish: int = quota_manager.shared_quota
	var coins: int = coin_manager.coins
	fish_label.text = "Stored Fish: " + str(fish)
	coin_label.text = "Coins: " + str(coins)
	sell_all_button.disabled = fish <= 0

	var items := _get_shop_items()
	if _shop_items_changed(items):
		_rebuild_shop_rows()
	else:
		_refresh_shop_rows(items, coins)


func _shop_items_changed(items: Array) -> bool:
	var flags: Array = []
	for item in items:
		if item == null:
			continue
		flags.append(item.owned_flag_property)
	if flags.size() != _row_buttons.size():
		return true
	for flag in flags:
		if not _row_buttons.has(flag):
			return true
	return false


func _refresh_shop_rows(items: Array, coins: int) -> void:
	for item in items:
		if item == null:
			continue
		if not _row_buttons.has(item.owned_flag_property):
			continue
		var button: Button = _row_buttons[item.owned_flag_property]
		if not is_instance_valid(button):
			continue
		var row := shop_items_container.get_node_or_null("ShopRow_" + str(item.owned_flag_property))
		if row:
			var title := row.get_node_or_null("TopRow/TitleLabel") as Label
			if title:
				title.text = "%s — %d coins" % [item.item_name, item.cost]
			var desc := row.get_node_or_null("DescLabel") as Label
			if desc:
				desc.text = item.description
		_update_row(item, button, coins)


func _update_row(item: ShopItemData, button: Button, coins: int) -> void:
	if _is_owned(item):
		button.text = "Owned"
		button.disabled = true
	elif coins >= item.cost:
		button.text = "Buy"
		button.disabled = false
	else:
		button.text = str(item.cost) + " coins"
		button.disabled = true
