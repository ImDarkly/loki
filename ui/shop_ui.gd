extends Control

@onready var fish_label = $VBoxContainer/FishLabel
@onready var coin_label = $VBoxContainer/CoinLabel
@onready var quota_manager = get_node("/root/main/QuotaManager")
@onready var coin_manager = get_node("/root/main/CoinManager") # Assumed path

func _ready():
    _update_ui()
    # Assuming managers have signals for updates
    if quota_manager.has_signal("quota_changed"):
        quota_manager.quota_changed.connect(_update_ui)
    # Assuming CoinManager exists

func _update_ui():
    var fish = quota_manager.get_total_quota() # Hypothetical method
    var coins = coin_manager.get_coins() # Hypothetical method
    fish_label.text = "Stored Fish: " + str(fish)
    coin_label.text = "Coins: " + str(coins)
