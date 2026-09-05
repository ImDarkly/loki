class_name SharkBaitManager extends Node3D

signal shark_bait_placed(position: Vector3)
signal bait_fill_updated(count: int, cost: int)

const SHARK_BAIT_SCENE: PackedScene = preload("res://entities/shark_bait.tscn")

@export var fill_cost: int = 3:
	set(value):
		fill_cost = maxi(value, 1)

var is_placed: bool = false
var placed_position: Vector3 = Vector3.ZERO
var bait_fill_count: int = 0
var _bait_instance: Node3D = null


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)


func _exit_tree() -> void:
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)


func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	if is_placed:
		_sync_placed.rpc_id(id, placed_position)
	if bait_fill_count != 0:
		_sync_fill.rpc_id(id, bait_fill_count)


@rpc("any_peer", "call_local", "reliable")
func request_place_shark_bait(position: Vector3) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var coin_manager := get_node_or_null("/root/main/CoinManager")
	if coin_manager == null:
		coin_manager = get_node_or_null("../CoinManager")
	if coin_manager == null:
		coin_manager = get_tree().root.get_node_or_null("main/CoinManager")
	if coin_manager == null:
		coin_manager = get_tree().root.find_child("CoinManager", true, false)
	if coin_manager == null or not coin_manager.is_shark_bait_owned():
		return
	if is_placed:
		return
	if not position.is_finite():
		return
	if MapConfig.is_within_radius(position, MapConfig.MAP_CENTER, MapConfig.ISLAND_RADIUS):
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if multiplayer.has_multiplayer_peer() and sender_id == 0:
		sender_id = multiplayer.get_unique_id()
	var player := _find_player_by_sender_id(sender_id)
	if player == null and not multiplayer.has_multiplayer_peer():
		player = _find_carrying_player_fallback()
	if player == null and not multiplayer.has_multiplayer_peer():
		var container := _get_players_container()
		if container:
			for child in container.get_children():
				if child is Player or child.name.begins_with("Player_") or "is_carrying" in child or "holding_shark_bait" in child:
					player = child
					break
	if player == null or not is_instance_valid(player):
		return
	var dist := Vector2(player.global_position.x - position.x, player.global_position.z - position.z).length()
	if dist > 4.0 or dist < 0.0:
		return
	placed_position = Vector3(position.x, 0, position.z)
	is_placed = true
	if multiplayer.has_multiplayer_peer():
		_sync_placed.rpc(placed_position)
	else:
		_sync_placed(placed_position)
	if player and player.has_method("clear_holding_shark_bait"):
		player.clear_holding_shark_bait()
	elif player and "holding_shark_bait" in player:
		player.holding_shark_bait = false


@rpc("authority", "call_local", "reliable")
func _sync_placed(position: Vector3) -> void:
	is_placed = true
	placed_position = position
	_ensure_bait_instance()
	if _bait_instance:
		_bait_instance.global_position = placed_position
	shark_bait_placed.emit(position)


@rpc("any_peer", "call_local", "reliable")
func request_deposit_shark_bait() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if not is_placed:
		return
	if bait_fill_count >= fill_cost:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if multiplayer.has_multiplayer_peer() and sender_id == 0:
		sender_id = multiplayer.get_unique_id()
	var player := _find_player_by_sender_id(sender_id)
	if player == null and not multiplayer.has_multiplayer_peer():
		player = _find_carrying_player_fallback()
	if player == null or not ("is_carrying" in player) or not player.is_carrying:
		return
	if is_placed and is_instance_valid(player):
		var dist := Vector2(player.global_position.x - placed_position.x, player.global_position.z - placed_position.z).length()
		if dist > 4.0:
			return
	bait_fill_count += 1
	if multiplayer.has_multiplayer_peer():
		_sync_fill.rpc(bait_fill_count)
	else:
		_sync_fill(bait_fill_count)
	if player.has_method("_clear_carry"):
		player._clear_carry()
	elif "is_carrying" in player:
		player.is_carrying = false


@rpc("authority", "call_local", "reliable")
func _sync_fill(count: int) -> void:
	bait_fill_count = clampi(count, 0, fill_cost)
	bait_fill_updated.emit(bait_fill_count, fill_cost)


func consume_by_shark() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	bait_fill_count = 0
	if multiplayer.has_multiplayer_peer():
		_sync_fill.rpc(0)
	else:
		_sync_fill(0)


func reset_for_restart() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	is_placed = false
	placed_position = Vector3.ZERO
	bait_fill_count = 0
	if is_instance_valid(_bait_instance):
		_bait_instance.queue_free()
		_bait_instance = null
	bait_fill_updated.emit(bait_fill_count, fill_cost)
	if multiplayer.has_multiplayer_peer():
		_sync_reset.rpc()
	else:
		_sync_reset()


@rpc("authority", "call_local", "reliable")
func _sync_reset() -> void:
	is_placed = false
	placed_position = Vector3.ZERO
	bait_fill_count = 0
	if is_instance_valid(_bait_instance):
		_bait_instance.queue_free()
		_bait_instance = null
	bait_fill_updated.emit(bait_fill_count, fill_cost)


func _get_players_container() -> Node:
	var container := get_node_or_null("/root/main/Players")
	if container != null:
		return container
	container = get_node_or_null("../Players")
	if container != null:
		return container
	container = get_node_or_null("../../Players")
	if container != null:
		return container
	return get_tree().root.find_child("Players", true, false)


func _find_player_by_sender_id(sender_id: int) -> Node:
	var players_container := _get_players_container()
	if players_container == null:
		return null
	for child in players_container.get_children():
		if not (child is Player) and not child.name.begins_with("Player_") and not ("is_carrying" in child or "holding_shark_bait" in child):
			continue
		if child.get_multiplayer_authority() == sender_id:
			return child
		if child.name == "Player_%d" % sender_id:
			return child
		if not multiplayer.has_multiplayer_peer():
			return child
	return null


func _find_carrying_player_fallback() -> Node:
	var players_container := _get_players_container()
	if players_container == null:
		return null
	for child in players_container.get_children():
		if not (child is Player) and not child.name.begins_with("Player_") and not ("is_carrying" in child or "holding_shark_bait" in child):
			continue
		if "is_carrying" in child and child.is_carrying:
			return child
		if not multiplayer.has_multiplayer_peer():
			return child
	return null


func _ensure_bait_instance() -> void:
	if is_instance_valid(_bait_instance):
		return
	_bait_instance = SHARK_BAIT_SCENE.instantiate() as Node3D
	if _bait_instance == null:
		return
	add_child(_bait_instance)
	_bait_instance.global_position = placed_position



