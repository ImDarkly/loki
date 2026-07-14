extends Node3D

signal coins_updated(value: int)

@export var coins_per_fish: int = 1
@export var upgrade_costs: Dictionary = {"extra_rod": 10, "big_net": 25}

var coins: int = 0
var _upgrades: Dictionary = {}


@rpc("any_peer", "call_remote", "reliable")
func sell_all() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var qm := get_node_or_null("/root/main/QuotaManager")
	if not qm:
		return
	var fish_count: int = qm.shared_quota
	if fish_count <= 0:
		return
	coins += fish_count * coins_per_fish
	qm.apply_penalty(fish_count)
	if multiplayer.has_multiplayer_peer():
		_sync_coins.rpc(coins)


@rpc("any_peer", "call_remote", "reliable")
func buy_upgrade(upgrade_name: String) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if _upgrades.get(upgrade_name, false):
		return
	var cost: int = upgrade_costs.get(upgrade_name, -1)
	if cost < 0 or coins < cost:
		return
	coins -= cost
	_upgrades[upgrade_name] = true
	if multiplayer.has_multiplayer_peer():
		_sync_coins.rpc(coins)


@rpc("authority", "call_local", "reliable")
func _sync_coins(value: int) -> void:
	coins = value
	coins_updated.emit(value)
