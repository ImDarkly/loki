extends Node

signal host_started(ip: String)
signal connection_success()
signal connection_failed_signal()

const DEFAULT_PORT := 7777
const MAX_CLIENTS := 16

var peer: ENetMultiplayerPeer
var public_ip: String = ""
var local_ip: String = ""

const REQUIRED_ENV_KEYS: Array[String] = [
	"PRODUCT_NAME", "PRODUCT_VERSION", "PRODUCT_ID", "SANDBOX_ID",
	"DEPLOYMENT_ID", "CLIENT_ID", "CLIENT_SECRET", "ENCRYPTION_KEY",
]


# Call path is wired in a follow-up lobby slice (PRD eosg-networking-migration
# Decision 6); login must complete before host_game()/join_game().
func initialize_and_login_async() -> bool:
	var creds := _load_credentials()
	if creds == null:
		return false

	var setup_ok: bool = await HPlatform.setup_eos_async(creds)
	if not setup_ok:
		push_error("NetworkManager: EOS platform setup failed")
		connection_failed_signal.emit()
		return false

	var login_ok: bool = await HAuth.login_anonymous_async("User_" + str(randi() % 1000))
	if not login_ok:
		push_error("NetworkManager: EOS anonymous login failed")
		connection_failed_signal.emit()
		return false

	return true


func _load_credentials() -> HCredentials:
	var env_path: String = "res://.env"
	if not FileAccess.file_exists(env_path):
		env_path = "user://.env"
	if not FileAccess.file_exists(env_path):
		push_error("NetworkManager: .env not found")
		connection_failed_signal.emit()
		return null

	var cfg := ConfigFile.new()
	if cfg.load(env_path) != OK:
		push_error("NetworkManager: failed to load .env")
		connection_failed_signal.emit()
		return null

	for key in REQUIRED_ENV_KEYS:
		if not cfg.has_section_key("", key) or cfg.get_value("", key).is_empty():
			push_error("NetworkManager: missing or empty '%s' in .env" % key)
			connection_failed_signal.emit()
			return null

	var creds := HCredentials.new()
	creds.product_name = cfg.get_value("", "PRODUCT_NAME")
	creds.product_version = cfg.get_value("", "PRODUCT_VERSION")
	creds.product_id = cfg.get_value("", "PRODUCT_ID")
	creds.sandbox_id = cfg.get_value("", "SANDBOX_ID")
	creds.deployment_id = cfg.get_value("", "DEPLOYMENT_ID")
	creds.client_id = cfg.get_value("", "CLIENT_ID")
	creds.client_secret = cfg.get_value("", "CLIENT_SECRET")
	creds.encryption_key = cfg.get_value("", "ENCRYPTION_KEY")
	return creds


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
