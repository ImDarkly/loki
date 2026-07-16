class_name CoinManager extends Node3D

signal coins_updated(value: int)
signal upgrades_updated()

@export var coins_per_fish: int = 1
@export var max_health_upgrade_cost: int = 10
@export var rod_pull_speed_upgrade_cost: int = 10

var coins: int = 0
var max_health_upgrade_owned: bool = false
var rod_pull_speed_upgrade_owned: bool = false

@rpc("authority", "call_local", "reliable")
func _sync_coins(value: int) -> void:
	coins = value
	coins_updated.emit(value)


@rpc("authority", "call_local", "reliable")
func _sync_upgrades(max_health_owned: bool, rod_pull_speed_owned: bool) -> void:
	max_health_upgrade_owned = max_health_owned
	rod_pull_speed_upgrade_owned = rod_pull_speed_owned
	upgrades_updated.emit()


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


@rpc("any_peer", "call_local", "reliable")
func request_buy_upgrade(upgrade_name: String) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var cost = get_upgrade_cost(upgrade_name)
	if cost < 0:
		return
	if is_upgrade_owned(upgrade_name):
		return
	if coins < cost:
		return
	coins -= cost
	_set_upgrade_owned(upgrade_name, true)
	_sync_coins.rpc(coins)
	_sync_upgrades.rpc(max_health_upgrade_owned, rod_pull_speed_upgrade_owned)


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


func get_upgrade_cost(upgrade_name: String) -> int:
	match upgrade_name:
		"max_health":
			return max_health_upgrade_cost
		"rod_pull_speed":
			return rod_pull_speed_upgrade_cost
	return -1


func is_upgrade_owned(upgrade_name: String) -> bool:
	match upgrade_name:
		"max_health":
			return max_health_upgrade_owned
		"rod_pull_speed":
			return rod_pull_speed_upgrade_owned
	return false


func _set_upgrade_owned(upgrade_name: String, owned: bool) -> void:
	match upgrade_name:
		"max_health":
			max_health_upgrade_owned = owned
		"rod_pull_speed":
			rod_pull_speed_upgrade_owned = owned
