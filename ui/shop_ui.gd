extends PanelContainer

@onready var fish_label = $MarginContainer/VBoxContainer/FishLabel
@onready var coin_label = $MarginContainer/VBoxContainer/CoinLabel
@onready var close_button = $MarginContainer/VBoxContainer/CloseButton
@onready var quota_manager = get_node("/root/main/QuotaManager")
@onready var coin_manager = get_node("/root/main/CoinManager")

func _ready():
	# Setup fade in
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_CUBIC)
	
	# Capture mouse
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Notify shop is open
	get_node("/root/game_manager").shop_toggled.emit(true)
	
	_update_ui()
	if quota_manager.has_signal("quota_updated"):
		quota_manager.quota_updated.connect(_update_ui)
	if coin_manager.has_signal("coins_updated"):
		coin_manager.coins_updated.connect(_update_ui)
	
	close_button.pressed.connect(close_shop)


func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		close_shop()

func close_shop():
	# Notify shop is closed
	get_node("/root/game_manager").shop_toggled.emit(false)
	
	# Fade out
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(func():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		queue_free()
	)


func _update_ui(_val = 0):
	var fish = quota_manager.shared_quota
	var coins = coin_manager.get_coins()
	fish_label.text = "Stored Fish: " + str(fish)
	coin_label.text = "Coins: " + str(coins)
