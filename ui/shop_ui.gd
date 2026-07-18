extends PanelContainer

@onready var fish_label = $MarginContainer/VBoxContainer/FishLabel
@onready var coin_label = $MarginContainer/VBoxContainer/CoinLabel
@onready var close_button = $MarginContainer/VBoxContainer/CloseButton
@onready var sell_all_button = $MarginContainer/VBoxContainer/SellAllButton
@onready var max_health_buy_button = $MarginContainer/VBoxContainer/MaxHealthRow/MaxHealthBuyButton
@onready var rod_speed_buy_button = $MarginContainer/VBoxContainer/RodSpeedRow/RodSpeedBuyButton
@onready var max_health_label = $MarginContainer/VBoxContainer/MaxHealthRow/MaxHealthLabel
@onready var rod_speed_label = $MarginContainer/VBoxContainer/RodSpeedRow/RodSpeedLabel
@onready var quota_manager = get_node_or_null("/root/main/QuotaManager")
@onready var coin_manager = get_node_or_null("/root/main/CoinManager")

func _ready() -> void:
	close_button.pressed.connect(close_shop)

	if not quota_manager or not coin_manager:
		push_warning("ShopUI: QuotaManager or CoinManager not found")
		return
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_CUBIC)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	get_node("/root/game_manager").shop_toggled.emit(true)

	_update_ui()
	if quota_manager.has_signal("quota_updated"):
		quota_manager.quota_updated.connect(_update_ui)
	if coin_manager.has_signal("coins_updated"):
		coin_manager.coins_updated.connect(_update_ui)
	if coin_manager.has_signal("upgrades_updated"):
		coin_manager.upgrades_updated.connect(_update_ui)

	sell_all_button.pressed.connect(_on_sell_all_pressed)
	max_health_buy_button.pressed.connect(_on_buy_upgrade_pressed.bind("max_health"))
	rod_speed_buy_button.pressed.connect(_on_buy_upgrade_pressed.bind("rod_pull_speed"))


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


func _on_buy_upgrade_pressed(upgrade_name: String) -> void:
	if not coin_manager:
		return
	coin_manager.request_buy_upgrade.rpc(upgrade_name)


func _update_ui(_val: int = 0) -> void:
	if not quota_manager or not coin_manager:
		return
	var fish: int = quota_manager.shared_quota
	var coins: int = coin_manager.coins
	fish_label.text = "Stored Fish: " + str(fish)
	coin_label.text = "Coins: " + str(coins)
	sell_all_button.disabled = fish <= 0

	_update_upgrade_button("max_health", max_health_label, max_health_buy_button, coins)
	_update_upgrade_button("rod_pull_speed", rod_speed_label, rod_speed_buy_button, coins)


func _update_upgrade_button(upgrade_name: String, label: Label, button: Button, coins: int) -> void:
	var cost: int = coin_manager.get_upgrade_cost(upgrade_name)
	var owned = coin_manager.is_upgrade_owned(upgrade_name)

	var display_name: String = "+Max Health" if upgrade_name == "max_health" else "+Rod Pull Speed"
	label.text = display_name + " — " + str(cost) + " coins"

	if owned:
		button.text = "Owned"
		button.disabled = true
	elif coins >= cost:
		button.text = "Buy"
		button.disabled = false
	else:
		button.text = str(cost) + " coins"
		button.disabled = true
