extends Node

signal player_list_changed()

const PLAYER_LIST_KEY := "player_list"

var players: Array = []
var local_player_id: int = -1

var _tracked_ids: Array = []


func _ready() -> void:
	GDSync.connected.connect(_on_connected)
	GDSync.connection_failed.connect(_on_connection_failed)
	GDSync.disconnected.connect(_on_disconnected)
	GDSync.lobby_joined.connect(_on_lobby_joined)
	GDSync.client_joined.connect(_on_client_joined)
	GDSync.client_left.connect(_on_client_left)
	GDSync.lobby_data_changed.connect(_on_lobby_data_changed)

	GDSync.start_multiplayer()


func _on_connected() -> void:
	local_player_id = GDSync.get_client_id()
	GDSync.player_set_username("Player_%d" % local_player_id)


func _on_connection_failed(error: int) -> void:
	push_error("GameManager: Connection failed: ", error)


func _on_disconnected() -> void:
	players = []
	_tracked_ids.clear()
	local_player_id = -1
	GDSync.change_scene("res://scenes/lobby.tscn")


func _on_lobby_joined(_lobby_name: String) -> void:
	if GDSync.is_host():
		_add_to_tracked(local_player_id)
		_publish_tracked_list()
	_rebuild_from_lobby_data()


func _on_client_joined(client_id: int) -> void:
	if GDSync.is_host():
		_add_to_tracked(client_id)
		_publish_tracked_list()
	_rebuild_from_lobby_data()


func _on_client_left(client_id: int) -> void:
	if GDSync.is_host():
		_tracked_ids.erase(client_id)
		_publish_tracked_list()
	_rebuild_from_lobby_data()


func _on_lobby_data_changed(key: String, _value) -> void:
	if key == PLAYER_LIST_KEY:
		_rebuild_from_lobby_data()


func _publish_tracked_list() -> void:
	GDSync.lobby_set_data(PLAYER_LIST_KEY, _tracked_ids.duplicate())


func _add_to_tracked(client_id: int) -> void:
	if not client_id in _tracked_ids:
		_tracked_ids.append(client_id)


func _rebuild_from_lobby_data() -> void:
	var list = GDSync.lobby_get_data(PLAYER_LIST_KEY, [])
	if list.is_empty() and local_player_id != -1:
		list = [local_player_id]
	if list.is_empty():
		return
	_update_players(list)


func _update_players(client_ids: Array) -> void:
	players = []
	for i in client_ids.size():
		var cid = client_ids[i]
		var username = GDSync.player_get_username(cid, "Player_%d" % cid)
		players.append({
			"id": cid,
			"username": username,
			"join_order": i
		})
	player_list_changed.emit()


func is_host() -> bool:
	return GDSync.is_host()


func start_game() -> void:
	if not GDSync.is_host():
		return
	GDSync.change_scene("res://scenes/main.tscn")
