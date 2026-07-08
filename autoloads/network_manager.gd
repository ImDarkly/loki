extends Node

signal host_started(ip: String)
signal connection_success()
signal connection_failed_signal()

const DEFAULT_PORT := 7777
const MAX_CLIENTS := 16

var peer: ENetMultiplayerPeer
var public_ip: String = ""
var local_ip: String = ""


func host_game(port: int = DEFAULT_PORT) -> void:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		push_error("NetworkManager: create_server failed — error %d" % err)
		connection_failed_signal.emit()
		return
	multiplayer.multiplayer_peer = peer
	_fetch_public_ip()
	_find_local_ip()
	host_started.emit(local_ip)


func join_game(address: String, port: int = DEFAULT_PORT) -> void:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		push_error("NetworkManager: create_client failed — error %d" % err)
		connection_failed_signal.emit()
		return
	multiplayer.multiplayer_peer = peer


func disconnect_from_game() -> void:
	if peer:
		peer.close()
		peer = null
	multiplayer.multiplayer_peer = null
	public_ip = ""
	local_ip = ""


func _fetch_public_ip() -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_ip_fetched.bind(http))
	http.request("https://api.ipify.org")


func _on_ip_fetched(result: int, _code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	if result == HTTPRequest.RESULT_SUCCESS:
		public_ip = body.get_string_from_utf8().strip_edges()
	http.queue_free()


func _find_local_ip() -> void:
	var addresses := IP.get_local_addresses()
	for addr in addresses:
		if addr.begins_with("192.168.") or addr.begins_with("10."):
			local_ip = addr
			return
	if addresses.size() > 0:
		local_ip = addresses[0]
