extends Node

signal host_started(ip: String)
signal connection_success()
signal connection_failed_signal()

const DEFAULT_PORT := 7777
const MAX_CLIENTS := 16

var peer: ENetMultiplayerPeer
var public_ip: String = ""
var local_ip: String = ""


func host_game(port: int = DEFAULT_PORT, is_eos: bool = false) -> void:
	if is_eos:
		# Use local IP for host. NetworkManager already has _find_local_ip()
		_find_local_ip()
		var host_ip := local_ip if not local_ip.is_empty() else "127.0.0.1"
		
		# room_code is returned by create_lobby; in a real app you'd display this to the host
		var room_code = await EOSLobbyManager.create_lobby(MAX_CLIENTS, host_ip, port)
		if room_code.is_empty():
			push_error("NetworkManager: EOS lobby creation failed")
			connection_failed_signal.emit()
			return
		print("EOS Lobby created with room code: ", room_code)
	
	peer = ENetMultiplayerPeer.new()
	# ... remainder of host_game logic (omitted for brevity, keep existing)
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		push_error("NetworkManager: create_server failed — error %d" % err)
		connection_failed_signal.emit()
		return
	multiplayer.multiplayer_peer = peer
	_fetch_public_ip()
	_find_local_ip()
	host_started.emit(local_ip)


func join_game(address: String, port: int = DEFAULT_PORT, is_eos: bool = false) -> void:
	var final_address := address
	var final_port := port
	
	if is_eos:
		# Discovery logic before join
		var lobby_info = await EOSLobbyManager.search_lobby(address) # address = room code
		if lobby_info.is_empty():
			push_error("NetworkManager: EOS lobby search failed")
			connection_failed_signal.emit()
			return
		final_address = lobby_info["HOST_IP"]
		final_port = int(lobby_info["HOST_PORT"])
	
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(final_address, final_port)
	# ... remainder of join_game logic (omitted for brevity, keep existing)
	if err != OK:
		push_error("NetworkManager: create_client failed — error %d" % err)
		connection_failed_signal.emit()
		return
	multiplayer.multiplayer_peer = peer
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_async_connection_failed):
		multiplayer.connection_failed.connect(_on_async_connection_failed)


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


func _on_connected_to_server() -> void:
	connection_success.emit()


func _on_async_connection_failed() -> void:
	push_error("NetworkManager: async connection failed")
	connection_failed_signal.emit()


func _find_local_ip() -> void:
	var addresses := IP.get_local_addresses()
	for addr in addresses:
		if addr.begins_with("192.168.") or addr.begins_with("10."):
			local_ip = addr
			return
	if addresses.size() > 0:
		local_ip = addresses[0]
