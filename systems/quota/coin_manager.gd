class_name CoinManager extends Node3D

signal coins_updated(value: int)
signal fireplace_updated()
signal shark_bait_updated()

@export var coins_per_fish: int = 1
@export var shop_items: Array[ShopItemData] = []

var coins: int = 0
var fireplace_owned: bool = false
var shark_bait_owned: bool = false


func _ready() -> void:
	if shop_items.is_empty():
		var fp = load("res://systems/quota/items/fireplace.tres") as ShopItemData
		var sb = load("res://systems/quota/items/shark_bait.tres") as ShopItemData
		if fp:
			shop_items.append(fp)
		if sb:
			shop_items.append(sb)

	var dbg = get_node_or_null("/root/DebugOverlay")
	if dbg:
		dbg.register_system(name, self)


func get_debug_state() -> Dictionary:
	return {
		"coins": coins,
		"fireplace_owned": fireplace_owned,
		"shark_bait_owned": shark_bait_owned
	}


func get_debug_actions() -> Array[Dictionary]:
	return [
		{"id": "add_coins_10", "label": "+10 Coins"},
		{"id": "remove_coins_10", "label": "-10 Coins"},
		{"id": "toggle_fireplace", "label": "Toggle Fireplace"},
		{"id": "toggle_shark_bait", "label": "Toggle Shark Bait"}
	]


func debug_action(action_id: String) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	match action_id:
		"add_coins_10":
			_debug_add_coins_10()
		"remove_coins_10":
			_debug_remove_coins_10()
		"toggle_fireplace":
			_debug_toggle_fireplace()
		"toggle_shark_bait":
			_debug_toggle_shark_bait()


func _debug_add_coins_10() -> void:
	coins += 10
	_sync_coins.rpc(coins)


func _debug_remove_coins_10() -> void:
	coins = max(0, coins - 10)
	_sync_coins.rpc(coins)


func _debug_toggle_fireplace() -> void:
	fireplace_owned = not fireplace_owned
	_sync_fireplace.rpc(fireplace_owned)


func _debug_toggle_shark_bait() -> void:
	shark_bait_owned = not shark_bait_owned
	_sync_shark_bait.rpc(shark_bait_owned)


@rpc("authority", "call_local", "reliable")
func _sync_coins(value: int) -> void:
	coins = value
	coins_updated.emit(value)


func _find_item(item_id: StringName) -> ShopItemData:
	var id_str = str(item_id).to_lower().strip_edges()
	for item in shop_items:
		if not item:
			continue
		var name_str = item.item_name.to_lower().strip_edges().replace(" ", "_")
		var flag_str = str(item.owned_flag_property).to_lower().strip_edges()
		var short_flag = flag_str.trim_suffix("_owned")
		if id_str == name_str or id_str == flag_str or id_str == short_flag or id_str + "_owned" == flag_str:
			return item
	return null


@rpc("any_peer", "call_local", "reliable")
func request_buy_item(item_id: StringName) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var item := _find_item(item_id)
	if not item:
		return
	var owned: bool = false
	match item.owned_flag_property:
		&"fireplace_owned":
			owned = fireplace_owned
		&"shark_bait_owned":
			owned = shark_bait_owned
		_:
			return

	if owned or coins < item.cost:
		return

	coins -= item.cost
	_sync_coins.rpc(coins)

	var buyer_id := multiplayer.get_remote_sender_id()
	if buyer_id == 0:
		buyer_id = multiplayer.get_unique_id()

	match item.owned_flag_property:
		&"fireplace_owned":
			fireplace_owned = true
			_sync_fireplace.rpc(true)
			_notify_fireplace_bought.rpc(buyer_id, _buyer_name(buyer_id))
		&"shark_bait_owned":
			shark_bait_owned = true
			_sync_shark_bait.rpc(true)
			_notify_shark_bait_bought.rpc(buyer_id, _buyer_name(buyer_id))
		_:
			return


@rpc("any_peer", "call_local", "reliable")
func request_buy_fireplace() -> void:
	request_buy_item(&"fireplace")


@rpc("authority", "call_local", "reliable")
func _sync_fireplace(owned: bool) -> void:
	fireplace_owned = owned
	fireplace_updated.emit()


@rpc("authority", "call_local", "reliable")
func _sync_shark_bait(owned: bool) -> void:
	shark_bait_owned = owned
	shark_bait_updated.emit()


@rpc("authority", "call_local", "reliable")
func _notify_fireplace_bought(buyer_id: int, buyer_name: String) -> void:
	var notif := get_node_or_null("/root/main/NotificationLabel") as NotificationLabel
	if not notif:
		return
	notif.show_message("%s bought the Fireplace! Team can now sit by the fire to heal" % buyer_name)


@rpc("authority", "call_local", "reliable")
func _notify_shark_bait_bought(buyer_id: int, buyer_name: String) -> void:
	var notif := get_node_or_null("/root/main/NotificationLabel") as NotificationLabel
	if not notif:
		return
	notif.show_message("%s bought Shark Bait! Team can now distract the shark" % buyer_name)


func _buyer_name(peer_id: int) -> String:
	var gm := get_node_or_null("/root/game_manager")
	if gm:
		for p in gm.players:
			if p.id == peer_id:
				return p.username
	return "Player_%d" % peer_id


func is_fireplace_owned() -> bool:
	return fireplace_owned


func is_shark_bait_owned() -> bool:
	return shark_bait_owned


@rpc("any_peer", "call_local", "reliable")
func request_buy_shark_bait() -> void:
	request_buy_item(&"shark_bait")


@rpc("any_peer", "call_local", "reliable")
func request_sell_all() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var qm = get_node_or_null("/root/main/QuotaManager")
	if not qm:
		return
	var fish = qm.shared_quota
	if fish <= 0:
		return
	var earned = fish * coins_per_fish
	qm.apply_penalty(fish)
	coins += earned
	_sync_coins.rpc(coins)


func add_coins(amount: int) -> void:
	if amount <= 0 or not multiplayer.is_server():
		return
	coins += amount
	_sync_coins.rpc(coins)


func get_coins() -> int:
	return coins


func spend_coins(amount: int) -> bool:
	if amount <= 0 or not multiplayer.is_server():
		return false
	if coins >= amount:
		coins -= amount
		_sync_coins.rpc(coins)
		return true
	return false
