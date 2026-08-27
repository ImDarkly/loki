extends Node3D

var _coin_manager: CoinManager
var _quota_manager: Node3D
var _round_manager: Node3D
var _label: Label

func _ready() -> void:
	var local_main := get_node_or_null("main")
	if local_main and local_main.get_parent() == self:
		remove_child(local_main)
		get_tree().root.add_child(local_main)
		local_main.owner = null

	await get_tree().process_frame

	_coin_manager = get_node_or_null("/root/main/CoinManager") as CoinManager
	_quota_manager = get_node_or_null("/root/main/QuotaManager")
	_round_manager = get_node_or_null("/root/main/RoundManager")
	_label = get_node_or_null("HUD/Label") as Label

	var player := get_node_or_null("Players/Player") as Player
	if player and _round_manager:
		# ensure player sees round state if needed
		pass

	if _coin_manager:
		_coin_manager.shark_bait_cost = 0
		_coin_manager.fireplace_cost = 0

	if _round_manager:
		_round_manager.round_duration = 15.0
		var t: Timer = _round_manager.get_node_or_null("Timer") as Timer
		if t:
			t.stop()
			t.start(15.0)
		_round_manager.round_active = true
		_round_manager.fishing_active = true

	if _quota_manager and "shared_quota" in _quota_manager:
		_quota_manager.shared_quota = 3

	# Ensure NotificationLabel is visible for purchase toast
	var notif := get_node_or_null("/root/main/NotificationLabel")
	if notif and notif.has_method("show_message"):
		pass

	if _label:
		_label.text = "Dev Shop Flow — O open shop / C buy bait / F buy fireplace / B +5 coins / G +5 fish / R reset / T toggle fishing"

func _process(_delta: float) -> void:
	if _label == null:
		return
	if _coin_manager == null or _quota_manager == null or _round_manager == null:
		return
	var coins: int = _coin_manager.coins
	var fish: int = _quota_manager.shared_quota if "shared_quota" in _quota_manager else 0
	var bait_owned: bool = _coin_manager.is_shark_bait_owned() if _coin_manager.has_method("is_shark_bait_owned") else false
	var fire_owned: bool = _coin_manager.is_fireplace_owned() if _coin_manager.has_method("is_fireplace_owned") else false
	var bait_cost: int = _coin_manager.shark_bait_cost if "shark_bait_cost" in _coin_manager else 0
	var fire_cost: int = _coin_manager.fireplace_cost if "fireplace_cost" in _coin_manager else 0
	var timer_left: float = 0.0
	var fishing: bool = false
	if _round_manager:
		var t: Timer = _round_manager.get_node_or_null("Timer") as Timer
		if t:
			timer_left = t.time_left
		if "fishing_active" in _round_manager:
			fishing = _round_manager.fishing_active
	_label.text = "Coins:%d Fish:%d | Bait:%s (%d) %s | Fire:%s (%d) %s | Fishing:%s Timer:%.1fs\n[O] Open shop  [C] Buy bait  [F] Buy fireplace  [B] +5 coins  [G] +5 fish  [R] Reset  [T] Toggle fishing" % [
		coins, fish,
		"owned" if bait_owned else "not",
		bait_cost,
		"Owned" if bait_owned else ("Buy" if coins >= bait_cost else "%d coins" % bait_cost),
		"owned" if fire_owned else "not",
		fire_cost,
		"Owned" if fire_owned else ("Buy" if coins >= fire_cost else "%d coins" % fire_cost),
		str(fishing),
		timer_left
	]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_O:
				_open_shop()
			KEY_C:
				if _coin_manager:
					_coin_manager.request_buy_shark_bait()
			KEY_F:
				if _coin_manager:
					_coin_manager.request_buy_fireplace()
			KEY_B:
				if _coin_manager:
					_coin_manager.coins += 5
					_coin_manager._sync_coins.rpc(_coin_manager.coins) if _coin_manager.has_method("_sync_coins") else _coin_manager.coins_updated.emit(_coin_manager.coins)
			KEY_G:
				if _quota_manager and "shared_quota" in _quota_manager:
					_quota_manager.shared_quota += 5
					if _quota_manager.has_signal("quota_updated"):
						_quota_manager.quota_updated.emit(_quota_manager.shared_quota)
			KEY_R:
				_reset_shop()
			KEY_T:
				if _round_manager and "fishing_active" in _round_manager:
					_round_manager.fishing_active = not _round_manager.fishing_active
					if _round_manager.has_method("_sync_state_to_clients"):
						_round_manager._sync_state_to_clients()
			KEY_H:
				Engine.time_scale = 1.0 if Engine.time_scale > 1.5 else 2.0
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _open_shop() -> void:
	var existing := get_tree().root.get_node_or_null("ShopUI")
	if existing:
		return
	var shop := preload("res://ui/shop_ui.tscn").instantiate()
	get_tree().root.add_child(shop)

func _reset_shop() -> void:
	if _coin_manager:
		_coin_manager.coins = 0
		_coin_manager.shark_bait_owned = false
		_coin_manager.fireplace_owned = false
		_coin_manager._sync_coins.rpc(0)
		_coin_manager._sync_shark_bait.rpc(false)
		_coin_manager._sync_fireplace.rpc(false)
		_coin_manager.shark_bait_cost = 0
		_coin_manager.fireplace_cost = 0
	if _quota_manager and "shared_quota" in _quota_manager:
		_quota_manager.shared_quota = 3
	if _round_manager:
		_round_manager.round_duration = 15.0
		var t: Timer = _round_manager.get_node_or_null("Timer") as Timer
		if t:
			t.stop()
			t.start(15.0)
		_round_manager.fishing_active = true
		_round_manager.round_active = true
