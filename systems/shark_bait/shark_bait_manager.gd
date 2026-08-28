class_name SharkBaitManager extends Node3D

signal shark_bait_placed(position: Vector3)

const SHARK_BAIT_SCENE: PackedScene = preload("res://entities/shark_bait.tscn")

var is_placed: bool = false
var placed_position: Vector3 = Vector3.ZERO
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


@rpc("any_peer", "call_local", "reliable")
func request_place_shark_bait(position: Vector3) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var coin_manager := get_node_or_null("/root/main/CoinManager")
	if coin_manager == null or not coin_manager.is_shark_bait_owned():
		return
	if is_placed:
		return
	if not position.is_finite():
		return
	if MapConfig.is_within_radius(position, MapConfig.MAP_CENTER, MapConfig.ISLAND_RADIUS):
		return
	placed_position = Vector3(position.x, 0, position.z)
	is_placed = true
	_sync_placed.rpc(placed_position)


@rpc("authority", "call_local", "reliable")
func _sync_placed(position: Vector3) -> void:
	is_placed = true
	placed_position = position
	_ensure_bait_instance()
	if _bait_instance:
		_bait_instance.global_position = placed_position
	shark_bait_placed.emit(position)


func _ensure_bait_instance() -> void:
	if is_instance_valid(_bait_instance):
		return
	_bait_instance = SHARK_BAIT_SCENE.instantiate() as Node3D
	if _bait_instance == null:
		return
	add_child(_bait_instance)
	_bait_instance.global_position = placed_position


func reset_for_restart() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	is_placed = false
	placed_position = Vector3.ZERO
	if is_instance_valid(_bait_instance):
		_bait_instance.queue_free()
		_bait_instance = null
