extends Node

signal player_list_changed()

var players: Array = []
var local_player_id: int = -1

var _players_dict: Dictionary[int, String] = {}
var _player_order: Array[int] = []


func _ready() -> void:
	GDSync.connected.connect(_on_connected)
	GDSync.connection_failed.connect(_on_connection_failed)
	GDSync.disconnected.connect(_on_disconnected)
	GDSync.lobby_joined.connect(_on_lobby_joined)
	GDSync.client_joined.connect(_on_client_joined)
	GDSync.client_left.connect(_on_client_left)

	GDSync.start_multiplayer()


func _on_connected() -> void:
	local_player_id = GDSync.get_client_id()


func _on_connection_failed(error: int) -> void:
	push_error("GameManager: Connection failed: ", error)


func _on_disconnected() -> void:
	players = []
	_players_dict.clear()
	_player_order.clear()
	local_player_id = -1
	GDSync.change_scene("res://scenes/lobby.tscn")


func _on_lobby_joined(_lobby_name: String) -> void:
	var all_clients := GDSync.lobby_get_all_clients()
	for cid in all_clients:
		add_player(cid, "Player_%d" % cid)


func _on_client_joined(client_id: int) -> void:
	add_player(client_id, "Player_%d" % client_id)


func _on_client_left(client_id: int) -> void:
	remove_player(client_id)


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


func is_host() -> bool:
	return GDSync.is_host()


func start_game() -> void:
	if not GDSync.is_host():
		return
	GDSync.change_scene("res://scenes/main.tscn")
