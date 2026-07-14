class_name CoinManager extends Node3D

signal coins_updated(value: int)

var coins: int = 0

@rpc("authority", "call_local", "reliable")
func _sync_coins(value: int) -> void:
    coins = value
    coins_updated.emit(value)

func add_coins(amount: int) -> void:
    if not multiplayer.is_server():
        return
    coins += amount
    _sync_coins.rpc(coins)

func get_coins() -> int:
    return coins

func spend_coins(amount: int) -> bool:
    if not multiplayer.is_server():
        return false
    if coins >= amount:
        coins -= amount
        _sync_coins.rpc(coins)
        return true
    return false
