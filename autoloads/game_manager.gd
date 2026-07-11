extends Node

signal player_list_changed()
signal all_players_loaded()

var players: Array = []
var local_player_id: int = -1

var _players_dict: Dictionary[int, String] = {}
var _player_order: Array[int] = []
var _players_ready: int = 0

@export var spawn_manager: Node3D


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed_reset)
	multiplayer.server_disconnected.connect(_on_disconnected)


func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	add_player(id, "Player_%d" % id)
	_broadcast_player_list()


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	remove_player(id)
	_broadcast_player_list()


func _on_connected_to_server() -> void:
	local_player_id = multiplayer.get_unique_id()


func _on_connection_failed_reset() -> void:
	push_error("GameManager: Connection failed")
	_on_disconnected()


func _on_disconnected() -> void:
	NetworkManager.disconnect_from_game()
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")


@rpc("any_peer", "reliable")
func _submit_username(name: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender in _player_order:
		_players_dict[sender] = name
		_rebuild_players()
		_broadcast_player_list()


func add_player(id: int, name: String) -> void:
	if id in _player_order:
		return
	_players_dict[id] = name
	_player_order.append(id)
	_rebuild_players()


func remove_player(id: int) -> void:
	if not id in _player_order:
		return
	_players_dict.erase(id)
	_player_order.erase(id)
	_rebuild_players()


func _rebuild_players() -> void:
	players = []
	for i in _player_order.size():
		var cid := _player_order[i]
		players.append({
			"id": cid,
			"username": _players_dict.get(cid, "Player_%d" % cid),
			"join_order": i
		})
	player_list_changed.emit()


func _broadcast_player_list() -> void:
	if not multiplayer.is_server():
		return
	var data: Array[Dictionary] = []
	for p in players:
		data.append({"id": p.id, "username": p.username, "join_order": p.join_order})
	_sync_players.rpc(data)


@rpc("authority", "reliable", "call_local")
func _sync_players(data: Array) -> void:
	if multiplayer.is_server():
		return
	_players_dict.clear()
	_player_order.clear()
	players = []
	for entry in data:
		var pid: int = entry["id"]
		_players_dict[pid] = entry["username"]
		_player_order.append(pid)
		players.append({"id": pid, "username": entry["username"], "join_order": entry["join_order"]})
	player_list_changed.emit()


func is_server() -> bool:
	return multiplayer.is_server()


func start_game() -> void:
	if not multiplayer.is_server():
		return
	var path := "res://scenes/main.tscn"
	load_scene.rpc(path)
	get_tree().change_scene_to_file(path)


@rpc("authority", "call_local", "reliable")
func load_scene(path: String) -> void:
	if multiplayer.is_server():
		return
	get_tree().change_scene_to_file(path)


func _on_scene_loaded() -> void:
	if not multiplayer.is_server():
		_report_scene_loaded.rpc_id(1)
		return
	_players_ready += 1
	if _players_ready >= _player_order.size():
		_players_ready = 0
		if spawn_manager:
			spawn_manager.trigger_spawn()
		all_players_loaded.emit()


@rpc("any_peer", "reliable")
func _report_scene_loaded() -> void:
	if not multiplayer.is_server():
		return
	_players_ready += 1
	if _players_ready >= _player_order.size():
		_players_ready = 0
		if spawn_manager:
			spawn_manager.trigger_spawn()
		all_players_loaded.emit()
