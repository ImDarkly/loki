class_name CoinManager extends Node3D

signal coins_updated(value: int)
signal fireplace_updated()

@export var coins_per_fish: int = 1
@export var fireplace_cost: int = 15

var coins: int = 0
var fireplace_owned: bool = false


@rpc("authority", "call_local", "reliable")
func _sync_coins(value: int) -> void:
	coins = value
	coins_updated.emit(value)


@rpc("any_peer", "call_local", "reliable")
func request_buy_fireplace() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if fireplace_owned or coins < fireplace_cost:
		return
	coins -= fireplace_cost
	fireplace_owned = true
	_sync_coins.rpc(coins)
	_sync_fireplace.rpc(true)


@rpc("authority", "call_local", "reliable")
func _sync_fireplace(owned: bool) -> void:
	fireplace_owned = owned
	fireplace_updated.emit()


func is_fireplace_owned() -> bool:
	return fireplace_owned


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
