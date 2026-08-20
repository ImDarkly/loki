class_name HealthComponent extends Node

signal health_changed(old_value: int, new_value: int)
signal died

@export var max_health: int = 5

var current_health: int = max_health


func _ready() -> void:
	current_health = max_health


func take_damage(amount: int) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	_apply_damage(amount)
	var owner_id := _get_owner_id()
	if multiplayer.has_multiplayer_peer():
		_broadcast_take_damage.rpc(owner_id, amount)


func _apply_damage(amount: int) -> void:
	if amount <= 0:
		return
	var was_alive := current_health > 0
	var old := current_health
	current_health = max(0, current_health - amount)
	health_changed.emit(old, current_health)
	if was_alive and current_health == 0:
		died.emit()


@rpc("any_peer", "reliable", "call_remote")
func _broadcast_take_damage(target_owner_id: int, amount: int) -> void:
	if multiplayer.get_unique_id() != target_owner_id:
		return
	_apply_damage(amount)


func reset_to_max() -> void:
	var old := current_health
	current_health = max_health
	health_changed.emit(old, current_health)


func is_alive() -> bool:
	return current_health > 0


func _get_owner_id() -> int:
	if not multiplayer.has_multiplayer_peer():
		return 0
	var parent := get_parent()
	if parent == null:
		return multiplayer.get_unique_id()
	var pname := parent.name
	if pname.begins_with("Player_"):
		var id_str := pname.trim_prefix("Player_")
		if id_str.is_valid_int():
			return int(id_str)
	return multiplayer.get_unique_id()
