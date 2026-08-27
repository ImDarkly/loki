extends PanelContainer

@onready var fish_label: Label = $MarginContainer/VBoxContainer/FishLabel
@onready var coin_label: Label = $MarginContainer/VBoxContainer/CoinLabel
@onready var close_button: Button = $MarginContainer/VBoxContainer/CloseButton
@onready var sell_all_button: Button = $MarginContainer/VBoxContainer/SellAllButton
@onready var fireplace_label: Label = $MarginContainer/VBoxContainer/FireplaceRow/FireplaceLabel
@onready var fireplace_buy_button: Button = $MarginContainer/VBoxContainer/FireplaceRow/FireplaceBuyButton
@onready var shark_bait_label: Label = $MarginContainer/VBoxContainer/SharkBaitRow/SharkBaitLabel
@onready var shark_bait_buy_button: Button = $MarginContainer/VBoxContainer/SharkBaitRow/SharkBaitBuyButton
@onready var quota_manager: Node3D = get_node_or_null("/root/main/QuotaManager")
@onready var coin_manager: CoinManager = get_node_or_null("/root/main/CoinManager")

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
	fireplace_buy_button.pressed.connect(_on_buy_fireplace_pressed)
	shark_bait_buy_button.pressed.connect(_on_buy_shark_bait_pressed)


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
	coin_manager.request_sell_all.rpc()


func _on_buy_fireplace_pressed() -> void:
	if not coin_manager:
		return
	coin_manager.request_buy_fireplace.rpc()


func _on_buy_shark_bait_pressed() -> void:
	if not coin_manager:
		return
	coin_manager.request_buy_shark_bait.rpc()


func _update_ui(_val: int = 0) -> void:
	if not quota_manager or not coin_manager:
		return
	var fish: int = quota_manager.shared_quota
	var coins: int = coin_manager.coins
	fish_label.text = "Stored Fish: " + str(fish)
	coin_label.text = "Coins: " + str(coins)
	sell_all_button.disabled = fish <= 0

	_update_fireplace_button(coins)
	_update_shark_bait_button(coins)


func _update_fireplace_button(coins: int) -> void:
	var cost: int = coin_manager.fireplace_cost
	fireplace_label.text = "Fireplace — " + str(cost) + " coins"

	if coin_manager.is_fireplace_owned():
		fireplace_buy_button.text = "Owned"
		fireplace_buy_button.disabled = true
	elif coins >= cost:
		fireplace_buy_button.text = "Buy"
		fireplace_buy_button.disabled = false
	else:
		fireplace_buy_button.text = str(cost) + " coins"
		fireplace_buy_button.disabled = true


func _update_shark_bait_button(coins: int) -> void:
	var cost: int = coin_manager.shark_bait_cost
	shark_bait_label.text = "Shark Bait — " + str(cost) + " coins"

	if coin_manager.is_shark_bait_owned():
		shark_bait_buy_button.text = "Owned"
		shark_bait_buy_button.disabled = true
	elif coins >= cost:
		shark_bait_buy_button.text = "Buy"
		shark_bait_buy_button.disabled = false
	else:
		shark_bait_buy_button.text = str(cost) + " coins"
		shark_bait_buy_button.disabled = true
