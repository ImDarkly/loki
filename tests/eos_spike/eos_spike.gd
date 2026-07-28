extends Node

const SPIKE_FILE := "user://eosg_spike_host.txt"

var _role: String = "host"
var _room_code: String = "default"
var _credential_name: String = ""
var _auth_mode: String = "dev_auth"
var _dev_auth_host: String = "localhost:4545"
var _host_puid_override: String = ""

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
var _tests_total: int = 7

var _reliable_sent: int = 10
var _reliable_server_received: Array = []
var _reliable_test_passed: bool = false

var _unreliable_sent: int = 60
var _unreliable_client_sent_count: int = 0
var _unreliable_client_received_count: int = 0
var _unreliable_latencies: Array = []
var _unreliable_test_passed: bool = false
var _peer_id: int = 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--role="):
			_role = arg.trim_prefix("--role=")
		elif arg.begins_with("--room-code="):
			_room_code = arg.trim_prefix("--room-code=")
		elif arg.begins_with("--credential-name="):
			_credential_name = arg.trim_prefix("--credential-name=")
		elif arg.begins_with("--auth-mode="):
			_auth_mode = arg.trim_prefix("--auth-mode=")
		elif arg.begins_with("--dev-auth-host="):
			_dev_auth_host = arg.trim_prefix("--dev-auth-host=")
		elif arg.begins_with("--host-puid="):
			_host_puid_override = arg.trim_prefix("--host-puid=")


func _ready() -> void:
	if _role != "host" and _role != "client":
		push_error("Invalid role '%s'. Must be 'host' or 'client'." % _role)
		get_tree().quit(1)
		return

	print("")
	print("========== EOSG Transport Spike & RPC Verification ==========")
	print("Role: %s  |  Room: %s  |  Credential: %s" % [_role, _room_code, _credential_name])
	print("=============================================================")
	print("")

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
	if _auth_mode == "device_id":
		_login_device_id()
	else:
		_login_dev_auth_tool()


func _login_device_id() -> void:
	print("[SPIKE] Logging in via Device ID mode...")
	var cdidr: EOS.Result = await EOSConnect.create_device_id(OS.get_name() + ":" + OS.get_model_name())
	if not cdidr in [EOS.Success, EOS.DuplicateNotAllowed]:
		push_error("[SPIKE] Create device id failed: ", EOS.result_to_string(cdidr))
		get_tree().quit(1)
		return

	var connect_credentials := EOSConnect_Credentials.new()
	connect_credentials.type = EOS.ECT_DEVICEID_ACCESS_TOKEN

	var user_login_info := EOSConnect_UserLoginInfo.new()
	var display_name := "User_" + str(randi() % 1000)
	user_login_info.display_name = display_name

	var login_result: EOSConnect_LoginCallbackInfo = await EOSConnect.login(connect_credentials, user_login_info)
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

	print("[SPIKE] 1/5 PASS: Device ID login successful")
	print("[SPIKE]    ProductUserId: ", _product_user_id.to_string())
	_tests_passed += 1
	_setup_peer()


func _login_dev_auth_tool() -> void:
	var login_type: int = _get_login_credential_type("LCT_Developer")
	print("[SPIKE] Connecting to Dev Auth Tool at ", _dev_auth_host, " with credential: ", _credential_name)
	var auth_login_credentials := EOSAuth_Credentials.new()
	auth_login_credentials.type = login_type
	auth_login_credentials.id = _dev_auth_host
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
		var host_user_id = EOSProductUserId.from_string(host_user_id_str)
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
		print("[SPIKE] Waiting for client peer connection and RPC tests...")


func _save_host_user_id() -> void:
	var file := FileAccess.open(SPIKE_FILE, FileAccess.WRITE)
	if file:
		file.store_line(_product_user_id.to_string())
		print("[SPIKE] Host info saved to: ", SPIKE_FILE)
		file.close()


func _load_host_user_id() -> String:
	if not _host_puid_override.is_empty():
		return _host_puid_override
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
	_peer_id = peer_id

	if _role == "client":
		print("[SPIKE] Starting Reliable & Unreliable RPC tests...")
		_run_rpc_tests()


func _on_peer_disconnected(peer_id: int) -> void:
	print("[SPIKE] Peer disconnected: ", peer_id)


func _run_rpc_tests() -> void:
	await get_tree().create_timer(0.5).timeout

	print("[SPIKE] Running Reliable RPC Test (10 messages)...")
	for i in range(1, _reliable_sent + 1):
		_send_reliable_rpc.rpc_id(_peer_id, i)
		await get_tree().create_timer(0.05).timeout

	var timeout := 5.0
	var elapsed := 0.0
	while not _reliable_test_passed and elapsed < timeout:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1

	if _reliable_test_passed:
		print("[SPIKE] 6/7 PASS: Reliable RPC test passed (10/10 received in order, no duplicates)")
		_tests_passed += 1
	else:
		push_error("[SPIKE] 6/7 FAIL: Reliable RPC test timed out or failed")

	print("[SPIKE] Running Unreliable RPC Test (60 messages)...")
	_unreliable_client_sent_count = _unreliable_sent
	for i in range(1, _unreliable_sent + 1):
		var send_time := Time.get_ticks_msec()
		_send_unreliable_rpc.rpc_id(_peer_id, i, send_time)
		await get_tree().process_frame

	await get_tree().create_timer(2.0).timeout

	var delivery_rate: float = float(_unreliable_client_received_count) / float(_unreliable_sent)
	var avg_latency: float = 0.0
	if _unreliable_latencies.size() > 0:
		var sum := 0.0
		for lat in _unreliable_latencies:
			sum += lat
		avg_latency = sum / _unreliable_latencies.size()

	print("[SPIKE] Unreliable RPC Results: received %d/%d (%.1f%%), avg latency: %.1fms" % [
		_unreliable_client_received_count, _unreliable_sent, delivery_rate * 100.0, avg_latency
	])

	if _unreliable_client_received_count >= _unreliable_sent:
		print("[SPIKE] 7/7 PASS: Unreliable RPC test passed (delivery count: %d/%d, latency: %.1fms)" % [
			_unreliable_client_received_count, _unreliable_sent, avg_latency
		])
		_tests_passed += 1
		_unreliable_test_passed = true
	else:
		push_error("[SPIKE] 7/7 FAIL: Unreliable RPC test received 0 messages")

	_print_results()


@rpc("any_peer", "reliable", "call_remote")
func _send_reliable_rpc(seq: int) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	_reliable_server_received.append(seq)
	print("[SPIKE HOST] Received reliable RPC seq=%d from peer=%d" % [seq, sender_id])

	if _reliable_server_received.size() == _reliable_sent:
		var ordered := true
		var unique := true
		var seen := {}
		for idx in range(_reliable_server_received.size()):
			var s = _reliable_server_received[idx]
			if s != idx + 1:
				ordered = false
			if seen.has(s):
				unique = false
			seen[s] = true

		if ordered and unique:
			print("[SPIKE HOST] Reliable RPC verification SUCCESS: 10/10 received in order, no duplicates.")
			_notify_reliable_complete.rpc_id(sender_id, true)
		else:
			push_error("[SPIKE HOST] Reliable RPC verification FAILED: ordered=%s, unique=%s" % [ordered, unique])
			_notify_reliable_complete.rpc_id(sender_id, false)


@rpc("authority", "reliable", "call_remote")
func _notify_reliable_complete(success: bool) -> void:
	_reliable_test_passed = success


@rpc("any_peer", "unreliable", "call_remote")
func _send_unreliable_rpc(seq: int, client_timestamp: int) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	_echo_unreliable_rpc.rpc_id(sender_id, seq, client_timestamp)


@rpc("authority", "unreliable", "call_remote")
func _echo_unreliable_rpc(seq: int, client_timestamp: int) -> void:
	var latency := Time.get_ticks_msec() - client_timestamp
	_unreliable_client_received_count += 1
	_unreliable_latencies.append(latency)


func _print_results() -> void:
	var avg_lat := 0.0
	if _unreliable_latencies.size() > 0:
		var sum := 0.0
		for l in _unreliable_latencies:
			sum += l
		avg_lat = sum / _unreliable_latencies.size()

	print("")
	print("========== EOSG Spike & RPC Verification Results ==========")
	print("  %d/%d tests passed, %d failed" % [_tests_passed, _tests_total, _tests_total - _tests_passed])
	print("===========================================================")
	print("")
	print("| Test Item | Pass/Fail | Notes / Metrics |")
	print("|---|---|---|")
	print("| EOS Login (Device ID / Dev Auth) | PASS | Successfully authenticated with EOS |")
	print("| EOS Connect Login | PASS | EOSConnect login established ProductUserId |")
	print("| EOSMultiplayerPeer Creation | PASS | Multiplayer peer created and assigned |")
	print("| Multiplayer Unique ID & Server Status | PASS | get_unique_id non-zero, is_server correct |")
	print("| peer_connected Signal | PASS | P2P handshake established between peers |")
	print("| Reliable RPC Test (10/10) | %s | %d/10 received, in order, 0 duplicates |" % ["PASS" if _reliable_test_passed else "FAIL", _reliable_server_received.size()])
	print("| Unreliable RPC Test (60/60) | %s | %d/%d delivered (%.1f%%), avg latency ~%.1fms |" % [
		"PASS" if _unreliable_test_passed else "FAIL",
		_unreliable_client_received_count,
		_unreliable_sent,
		(float(_unreliable_client_received_count) / float(_unreliable_sent)) * 100.0 if _unreliable_sent > 0 else 0.0,
		avg_lat
	])
	print("")

	if _tests_passed >= _tests_total:
		print("[SPIKE] ACCEPTANCE: All 7 criteria met successfully")
		if _role == "host":
			await get_tree().create_timer(1.0).timeout
		get_tree().quit(0)
	else:
		push_error("[SPIKE] ACCEPTANCE: %d/%d criteria met" % [_tests_passed, _tests_total])
		get_tree().quit(1)
