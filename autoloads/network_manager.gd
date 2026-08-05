extends Node

signal host_started(room_code: String)
signal connection_success()
signal connection_failed_signal()
signal connection_candidates(candidates: Array[HLobby])

# Must match the 4 spawn positions in player.gd; expanding beyond 4 needs new spawn points.
const LOBBY_MAX_MEMBERS := 4

var peer: MultiplayerPeer
var lobby: HLobby
var _eos_ready: bool = false


static func generate_room_code(rng: RandomNumberGenerator = null) -> int:
	if rng == null:
		rng = RandomNumberGenerator.new()
	return rng.randi_range(100000, 999999)

const REQUIRED_ENV_KEYS: Array[String] = [
	"PRODUCT_NAME", "PRODUCT_VERSION", "PRODUCT_ID", "SANDBOX_ID",
	"DEPLOYMENT_ID", "CLIENT_ID", "CLIENT_SECRET", "ENCRYPTION_KEY",
]


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


func _ensure_eos_ready_async() -> bool:
	if _eos_ready:
		return true
	if not await initialize_and_login_async():
		return false
	_eos_ready = true
	return true


func host_game() -> void:
	# Coroutine: awaits login, lobby, and peer setup even though callers fire-and-forget.
	if not await _ensure_eos_ready_async():
		return

	var room_code := str(generate_room_code())

	var opts := EOS.Lobby.CreateLobbyOptions.new()
	opts.bucket_id = room_code
	opts.max_lobby_members = LOBBY_MAX_MEMBERS
	opts.enable_rtc_room = false
	lobby = await HLobbies.create_lobby_async(opts)
	if not lobby:
		push_error("NetworkManager: EOS lobby creation failed")
		connection_failed_signal.emit()
		return

	var eos_peer := EOSGMultiplayerPeer.new()
	eos_peer.set_auto_accept_connection_requests(true)
	peer = eos_peer
	# Assumed: the EOSG peer channel is keyed by the same code as the lobby bucket_id.
	# Linkage is an open item in PRD Decision 3 (matches the EOSG spike).
	var err := eos_peer.create_server(room_code)
	if err != OK:
		push_error("NetworkManager: create_server failed — error %d" % err)
		await lobby.destroy_async()
		lobby = null
		peer = null
		connection_failed_signal.emit()
		return
	multiplayer.multiplayer_peer = peer
	host_started.emit(room_code)


func join_game(code: String) -> void:
	# Coroutine: awaits login, lobby search, lobby join, and peer setup even though callers fire-and-forget.
	if not await _ensure_eos_ready_async():
		return

	var lobbies: Array[HLobby] = await HLobbies.search_by_bucket_id_async(code)
	if lobbies == null or lobbies.is_empty():
		push_error("NetworkManager: no lobby found for code '%s'" % code)
		connection_failed_signal.emit()
		return
	if lobbies.size() > 1:
		connection_candidates.emit(lobbies)
		return

	_join_selected_lobby(code, lobbies[0])


func join_candidate(code: String, candidate: HLobby) -> void:
	if not await _ensure_eos_ready_async():
		return
	_join_selected_lobby(code, candidate)


func _join_selected_lobby(code: String, host_lobby: HLobby) -> void:
	var joined: HLobby = await HLobbies.join_async(host_lobby)
	if joined == null:
		push_error("NetworkManager: failed to join EOS lobby")
		connection_failed_signal.emit()
		return
	lobby = joined

	var eos_peer := EOSGMultiplayerPeer.new()
	eos_peer.set_auto_accept_connection_requests(true)
	peer = eos_peer
	var err := eos_peer.create_client(code, joined.owner_product_user_id)
	if err != OK:
		push_error("NetworkManager: create_client failed — error %d" % err)
		connection_failed_signal.emit()
		return
	multiplayer.multiplayer_peer = peer
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_async_connection_failed):
		multiplayer.connection_failed.connect(_on_async_connection_failed)


func close_lobby() -> bool:
	if lobby == null or not lobby.is_valid():
		return true
	var ok: bool
	if lobby.is_owner():
		ok = await lobby.destroy_async()
	else:
		ok = await lobby.leave_async()
	if not ok:
		push_error("NetworkManager: failed to close EOS lobby %s" % lobby.lobby_id)
	lobby = null
	return ok


func disconnect_from_game() -> void:
	if lobby and lobby.is_owner():
		close_lobby()
	if peer:
		peer.close()
		peer = null
	multiplayer.multiplayer_peer = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if lobby and lobby.is_owner():
			await close_lobby()
		get_tree().quit()


func _on_connected_to_server() -> void:
	connection_success.emit()


func _on_async_connection_failed() -> void:
	push_error("NetworkManager: async connection failed")
	connection_failed_signal.emit()
