extends Node

const SPIKE_FILE := "user://eosg_spike_host.txt"

var _role: String = "host"
var _room_code: String = "default"
var _credential_name: String = ""

var _product_user_id
var _epic_account_id
var _product_name: String
var _product_version: String
var _product_id: String
var _sandbox_id: String
var _deployment_id: String
var _client_id: String
var _client_secret: String
var _encryption_key: String

var _peer: EOSMultiplayerPeer
var _tests_passed: int = 0
var _tests_total: int = 5


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--role="):
			_role = arg.trim_prefix("--role=")
		elif arg.begins_with("--room-code="):
			_room_code = arg.trim_prefix("--room-code=")
		elif arg.begins_with("--credential-name="):
			_credential_name = arg.trim_prefix("--credential-name=")

	if _role != "host" and _role != "client":
		push_error("Invalid role '%s'. Must be 'host' or 'client'." % _role)
		get_tree().quit(1)


func _ready() -> void:
	print("")
	print("========== EOSG Transport Spike ==========")
	print("Role: %s  |  Room: %s  |  Credential: %s" % [_role, _room_code, _credential_name])
	print("User args: ", OS.get_cmdline_user_args())
	print("==========================================")
	print("")

	if _credential_name.is_empty():
		_credential_name = _role + "_user"

	_load_credentials()


func _load_credentials() -> void:
	var env_path: String = "res://.env"
	if not FileAccess.file_exists(env_path):
		env_path = "user://.env"
	if not FileAccess.file_exists(env_path):
		push_error("[SPIKE] .env not found")
		get_tree().quit(1)
		return

	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(env_path) != OK:
		push_error("[SPIKE] Failed to load .env")
		get_tree().quit(1)
		return

	for key in ["PRODUCT_NAME", "PRODUCT_VERSION", "PRODUCT_ID", "SANDBOX_ID", "DEPLOYMENT_ID", "CLIENT_ID", "CLIENT_SECRET", "ENCRYPTION_KEY"]:
		if not cfg.has_section_key("", key) or cfg.get_value("", key).is_empty():
			push_error("[SPIKE] Missing or empty '%s' in .env" % key)
			get_tree().quit(1)
			return

	_product_name = cfg.get_value("", "PRODUCT_NAME")
	_product_version = cfg.get_value("", "PRODUCT_VERSION")
	_product_id = cfg.get_value("", "PRODUCT_ID")
	_sandbox_id = cfg.get_value("", "SANDBOX_ID")
	_deployment_id = cfg.get_value("", "DEPLOYMENT_ID")
	_client_id = cfg.get_value("", "CLIENT_ID")
	_client_secret = cfg.get_value("", "CLIENT_SECRET")
	_encryption_key = cfg.get_value("", "ENCRYPTION_KEY")

	print("[SPIKE] Credentials loaded from .env")
	_init_eos()


func _init_eos() -> void:
	var init_options := EOSInitializeOptions.new()
	init_options.product_name = _product_name
	init_options.product_version = _product_version
	var result_code: EOS.Result = EOS.initialize(init_options)
	if result_code != EOS.Success and result_code != EOS.AlreadyConfigured:
		push_error("[SPIKE] EOS.initialize failed: ", EOS.result_to_string(result_code))
		get_tree().quit(1)
		return
	_create_platform()


func _create_platform() -> void:
	var create_options := EOSPlatform_Options.new()
	create_options.product_id = _product_id
	create_options.sandbox_id = _sandbox_id
	create_options.deployment_id = _deployment_id
	create_options.client_credentials = EOSPlatform_ClientCredentials.new()
	create_options.client_credentials.client_id = _client_id
	create_options.client_credentials.client_secret = _client_secret
	create_options.rtc_options = EOSPlatform_RTCOptions.new()
	create_options.encryption_key = _encryption_key
	if OS.get_name() == "Windows":
		create_options.flags |= EOSPlatform.PF_DISABLE_OVERLAY
	else:
		create_options.flags = EOSPlatform.PF_DISABLE_OVERLAY
	EOSPlatform.platform_create(create_options)
	print("[SPIKE] EOS platform initialized")
	_login_dev_auth_tool()


func _login_dev_auth_tool() -> void:
	var enum_names: PackedStringArray = ClassDB.class_get_enum_constants(&"EOSAuth", &"LoginCredentialType")
	print("[SPIKE] EOSAuth LoginCredentialType enums: ", enum_names)
	var login_type: int = _get_login_credential_type("LCT_Developer")
	print("[SPIKE] Connecting to Dev Auth Tool at localhost:4545 with credential: ", _credential_name)
	var auth_login_credentials := EOSAuth_Credentials.new()
	auth_login_credentials.type = login_type
	auth_login_credentials.id = "localhost:4545"
	auth_login_credentials.token = _credential_name

	var auth_login_result: EOSAuth_LoginCallbackInfo = await EOSAuth.login(
		auth_login_credentials,
		EOSAuth.AS_BasicProfile | EOSAuth.AS_FriendsList | EOSAuth.AS_Presence,
		0
	)

	if auth_login_result.result_code != EOS.Success:
		push_error("[SPIKE] Dev Auth Tool login failed: ", EOS.result_to_string(auth_login_result.result_code))
		get_tree().quit(1)
		return

	_epic_account_id = auth_login_result.local_user_id
	print("[SPIKE] 1/5 PASS: Dev Auth Tool login successful")
	print("[SPIKE]    EpicAccountId: ", _epic_account_id)
	_tests_passed += 1
	_connect_login()


func _get_login_credential_type(name: String) -> int:
	return ClassDB.class_get_integer_constant(&"EOSAuth", name)


func _connect_login() -> void:
	var token := EOSAuth.copy_id_token(_epic_account_id)
	if not is_instance_valid(token):
		push_error("[SPIKE] Failed to copy ID token: ", EOS.result_to_string(EOS.get_last_result_code()))
		get_tree().quit(1)
		return

	var connect_credentials := EOSConnect_Credentials.new()
	connect_credentials.type = EOS.ECT_EPIC_ID_TOKEN
	connect_credentials.token = token.json_web_token

	var login_result: EOSConnect_LoginCallbackInfo = await EOSConnect.login(connect_credentials, EOSConnect_UserLoginInfo.new())
	if login_result.result_code == EOS.InvalidUser:
		var create_result: EOSConnect_CreateUserCallbackInfo = await EOSConnect.create_user(login_result.continuance_token)
		if create_result.result_code != EOS.Success:
			push_error("[SPIKE] EOSConnect create_user failed: ", EOS.result_to_string(create_result.result_code))
			get_tree().quit(1)
			return
		_product_user_id = create_result.local_user_id
	elif login_result.result_code != EOS.Success:
		push_error("[SPIKE] EOSConnect login failed: ", EOS.result_to_string(login_result.result_code))
		get_tree().quit(1)
		return
	else:
		_product_user_id = login_result.local_user_id

	print("[SPIKE] EOSConnect login successful")
	_setup_peer()


func _setup_peer() -> void:
	_peer = EOSMultiplayerPeer.new()
	_peer.set_auto_accept_connection_requests(true)
	_peer.peer_connected.connect(_on_peer_connected)
	_peer.peer_disconnected.connect(_on_peer_disconnected)

	var err: Error
	if _role == "host":
		err = _peer.create_server(_room_code)
		if err != OK:
			push_error("[SPIKE] create_server failed: ", err)
			get_tree().quit(1)
			return
		multiplayer.multiplayer_peer = _peer
		_save_host_user_id()
		print("[SPIKE] 2/5 PASS: Server created on socket: ", _room_code)
		_tests_passed += 1
	else:
		var host_user_id_str = _load_host_user_id()
		if host_user_id_str.is_empty():
			push_error("[SPIKE] No host user ID file. Start host first.")
			get_tree().quit(1)
			return
		print("[SPIKE] Loaded host ProductUserId string from file: ", host_user_id_str)
		var host_user_id = EOSProductUserId.from_string(host_user_id_str)
		print("[SPIKE] Parsed host EOSProductUserId valid: ", host_user_id.is_valid())
		err = _peer.create_client(_room_code, host_user_id)
		if err != OK:
			push_error("[SPIKE] create_client failed: ", err)
			get_tree().quit(1)
			return
		multiplayer.multiplayer_peer = _peer
		print("[SPIKE] 2/5 PASS: Client connecting to host")
		_tests_passed += 1

	_verify_acceptance_criteria()


func _verify_acceptance_criteria() -> void:
	var uid := multiplayer.get_unique_id()
	if uid != 0:
		_tests_passed += 1
		print("[SPIKE] 3/5 PASS: get_unique_id = %d (non-zero)" % uid)
	else:
		push_error("[SPIKE] 3/5 FAIL: get_unique_id is 0")

	var is_srv := multiplayer.is_server()
	if _role == "host":
		if is_srv:
			_tests_passed += 1
			print("[SPIKE] 4/5 PASS: is_server = true for host")
		else:
			push_error("[SPIKE] 4/5 FAIL: host expected is_server=true, got false")
	else:
		if not is_srv:
			_tests_passed += 1
			print("[SPIKE] 4/5 PASS: is_server = false for client")
		else:
			push_error("[SPIKE] 4/5 FAIL: client expected is_server=false, got true")

	if _role == "host":
		print("[SPIKE] Waiting for client peer connection...")


func _save_host_user_id() -> void:
	var file := FileAccess.open(SPIKE_FILE, FileAccess.WRITE)
	if file:
		file.store_line(_product_user_id.to_string())
		print("[SPIKE] Host info saved to: ", SPIKE_FILE)
		print("[SPIKE]    ProductUserId: ", _product_user_id.to_string())
		file.close()


func _load_host_user_id():
	if not FileAccess.file_exists(SPIKE_FILE):
		return ""
	var file := FileAccess.open(SPIKE_FILE, FileAccess.READ)
	if not file:
		return ""
	var line := file.get_line()
	file.close()
	return line.strip_edges()


func _on_peer_connected(peer_id: int) -> void:
	print("[SPIKE] 5/5 PASS: peer_connected signal fired (peer_id=%d)" % peer_id)
	_tests_passed += 1
	_print_results()


func _on_peer_disconnected(peer_id: int) -> void:
	print("[SPIKE] Peer disconnected: ", peer_id)


func _print_results() -> void:
	print("")
	print("========== EOSG Spike Results ==========")
	print("  %d/%d tests passed, %d failed" % [_tests_passed, _tests_total, _tests_total - _tests_passed])
	print("========================================")
	print("")
	print("  unique_id (self): %d" % multiplayer.get_unique_id())
	print("  is_server: %s" % multiplayer.is_server())
	print("  role: %s" % _role)
	print("  room: %s" % _room_code)
	print("")
	print("ROLLBACK/ABORT CRITERIA:")
	print("  If later EOSG verification slices stall (~2 days no concrete progress")
	print("  on a specific failing item), abort EOSG migration:")
	print("  1. Shelve feat/eosg-transport-spike")
	print("  2. Restore GD-EOS as production transport")
	print("  3. Fix remaining GD-EOS gaps (MultiplayerSpawner, peer_connection_closed)")
	print("  Fallback: checkout feat/eos-transport-spike for working GD-EOS transport")
	print("")

	if _tests_passed == _tests_total:
		print("[SPIKE] ACCEPTANCE: All 5 criteria met")
		get_tree().quit(0)
	else:
		push_error("[SPIKE] ACCEPTANCE: %d/%d criteria met" % [_tests_passed, _tests_total])
		get_tree().quit(1)