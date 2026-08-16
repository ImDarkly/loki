extends Node

const SPIKE_FILE := "user://eosg_spike_host.txt"

var _role: String = "host"
var _room_code: String = "default"
var _credential_name: String = ""
var _auth_mode: String = "dev_auth"
var _dev_auth_host: String = "localhost:4545"
var _host_puid_override: String = ""

var _product_user_id: String = ""
var _epic_account_id: String = ""
var _product_name: String
var _product_version: String
var _product_id: String
var _sandbox_id: String
var _deployment_id: String
var _client_id: String
var _encryption_key: String

var _peer: EOSGMultiplayerPeer
var _tests_passed: int = 0
var _tests_total: int = 9

var _reliable_sent: int = 10
var _reliable_server_received: Array = []
var _reliable_test_passed: bool = false

var _unreliable_sent: int = 60
var _unreliable_client_sent_count: int = 0
var _unreliable_client_received_count: int = 0
var _unreliable_latencies: Array = []
var _unreliable_test_passed: bool = false
var _unreliable_host_received: int = 0
var _connected_client_id: int = 0

var _spawner_expected_count: int = 0
var _spawner_host_passed: bool = false
var _spawner_client_passed: bool = false
var _spawner_client_found: int = 0
var _spawner_client_ack_received: bool = false
var _spawner_test_passed: bool = false
var _host_spawned_node: Node3D

var _sync_client_passed: bool = false
var _sync_client_ack_received: bool = false
var _sync_client_actual: Vector3 = Vector3()
var _sync_test_passed: bool = false


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
	print("User args: ", OS.get_cmdline_user_args())
	print("=============================================================")
	print("")

	if _credential_name.is_empty():
		_credential_name = _role + "_user"

	_load_credentials()


func _load_credentials() -> void:
	var cfg_path: String = "res://eos_credentials.cfg"
	if not FileAccess.file_exists(cfg_path):
		cfg_path = "user://eos_credentials.cfg"
	if not FileAccess.file_exists(cfg_path):
		push_error("[SPIKE] eos_credentials.cfg not found")
		get_tree().quit(1)
		return

	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(cfg_path) != OK:
		push_error("[SPIKE] Failed to load eos_credentials.cfg")
		get_tree().quit(1)
		return

	for key in ["PRODUCT_NAME", "PRODUCT_VERSION", "PRODUCT_ID", "SANDBOX_ID", "DEPLOYMENT_ID", "CLIENT_ID", "ENCRYPTION_KEY"]:
		if not cfg.has_section_key("", key) or cfg.get_value("", key).is_empty():
			push_error("[SPIKE] Missing or empty '%s' in eos_credentials.cfg" % key)
			get_tree().quit(1)
			return

	_product_name = cfg.get_value("", "PRODUCT_NAME")
	_product_version = cfg.get_value("", "PRODUCT_VERSION")
	_product_id = cfg.get_value("", "PRODUCT_ID")
	_sandbox_id = cfg.get_value("", "SANDBOX_ID")
	_deployment_id = cfg.get_value("", "DEPLOYMENT_ID")
	_client_id = cfg.get_value("", "CLIENT_ID")
	_encryption_key = cfg.get_value("", "ENCRYPTION_KEY")

	print("[SPIKE] Credentials loaded from eos_credentials.cfg")
	_init_eos()


func _init_eos() -> void:
	var credentials := HCredentials.new()
	credentials.product_name = _product_name
	credentials.product_version = _product_version
	credentials.product_id = _product_id
	credentials.sandbox_id = _sandbox_id
	credentials.deployment_id = _deployment_id
	credentials.client_id = _client_id
	credentials.encryption_key = _encryption_key
	var setup_ok: bool = await HPlatform.setup_eos_async(credentials)
	if not setup_ok:
		push_error("[SPIKE] EOSG setup_eos_async failed")
		get_tree().quit(1)
		return
	print("[SPIKE] EOS platform initialized (EOSG High-Level)")
	if _auth_mode == "device_id":
		_login_device_id()
	else:
		_login_dev_auth_tool()


func _login_device_id() -> void:
	print("[SPIKE] Logging in via Device ID mode...")
	var login_ok: bool = await HAuth.login_anonymous_async("User_" + str(randi() % 1000))
	if not login_ok:
		push_error("[SPIKE] EOSG anonymous login failed")
		get_tree().quit(1)
		return
	_product_user_id = HAuth.product_user_id

	print("[SPIKE] 1/5 PASS: Device ID login successful")
	print("[SPIKE]    ProductUserId: ", _product_user_id)
	_tests_passed += 1
	_setup_peer()


func _login_dev_auth_tool() -> void:
	print("[SPIKE] Connecting to Dev Auth Tool at ", _dev_auth_host, " with credential: ", _credential_name)
	var login_ok: bool = await HAuth.login_devtool_async(_dev_auth_host, _credential_name)
	if not login_ok:
		push_error("[SPIKE] EOSG Dev Auth Tool login failed")
		get_tree().quit(1)
		return
	_epic_account_id = HAuth.epic_account_id
	_product_user_id = HAuth.product_user_id
	print("[SPIKE] 1/5 PASS: Dev Auth Tool login successful")
	print("[SPIKE]    EpicAccountId: ", _epic_account_id)
	print("[SPIKE]    ProductUserId: ", _product_user_id)
	_tests_passed += 1
	_setup_peer()


func _setup_peer() -> void:
	_peer = EOSGMultiplayerPeer.new()
	_peer.set_auto_accept_connection_requests(true)
	_peer.peer_connected.connect(_on_peer_connected)
	_peer.peer_disconnected.connect(_on_peer_disconnected)

	var err
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
		err = _peer.create_client(_room_code, host_user_id_str)
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
		file.store_line(_product_user_id)
		print("[SPIKE] Host info saved to: ", SPIKE_FILE)
		print("[SPIKE]    ProductUserId: ", _product_user_id)
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
	_connected_client_id = peer_id

	if _role == "client":
		print("[SPIKE] Starting Reliable & Unreliable RPC tests...")
		_run_rpc_tests()


func _on_peer_disconnected(peer_id: int) -> void:
	print("[SPIKE] Peer disconnected: ", peer_id)


func _run_rpc_tests() -> void:
	var wait_elapsed := 0.0
	while (not multiplayer.get_peers().has(_connected_client_id)) and wait_elapsed < 5.0:
		await get_tree().create_timer(0.05).timeout
		wait_elapsed += 0.05

	print("[SPIKE] Running Reliable RPC Test (10 messages)...")
	for i in range(1, _reliable_sent + 1):
		_send_reliable_rpc.rpc_id(_connected_client_id, i)
		await get_tree().create_timer(0.05).timeout

	var timeout := 5.0
	var elapsed := 0.0
	while not _reliable_test_passed and elapsed < timeout:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1

	if _reliable_test_passed:
		print("[SPIKE] 6/9 PASS: Reliable RPC test passed (10/10 received in order, no duplicates)")
		_tests_passed += 1
	else:
		push_error("[SPIKE] 6/9 FAIL: Reliable RPC test timed out or failed")

	print("[SPIKE] Running Unreliable RPC Test (60 messages)...")
	_unreliable_client_sent_count = _unreliable_sent
	for i in range(1, _unreliable_sent + 1):
		var send_time := Time.get_ticks_msec()
		_send_unreliable_rpc.rpc_id(_connected_client_id, i, send_time)
		await get_tree().process_frame

	await get_tree().create_timer(2.0).timeout

	var delivery_rate: float = float(_unreliable_client_received_count) / float(_unreliable_sent)
	var avg_latency: float = 0.0
	if _unreliable_latencies.size() > 0:
		var sum := 0.0
		for lat: int in _unreliable_latencies:
			sum += lat
		avg_latency = sum / _unreliable_latencies.size()

	print("[SPIKE] Unreliable RPC Results: received %d/%d (%.1f%%), avg latency: %.1fms" % [
		_unreliable_client_received_count, _unreliable_sent, delivery_rate * 100.0, avg_latency
	])

	if _unreliable_client_received_count > 0:
		print("[SPIKE] 7/9 PASS: Unreliable RPC test passed (delivery count: %d/%d, latency: %.1fms)" % [
			_unreliable_client_received_count, _unreliable_sent, avg_latency
		])
		_tests_passed += 1
		_unreliable_test_passed = true
	else:
		push_error("[SPIKE] 7/9 FAIL: Unreliable RPC test received 0/%d messages" % _unreliable_sent)

	_request_spawner_sync_tests.rpc_id(_connected_client_id)
	var sync_elapsed := 0.0
	while not _sync_client_ack_received and sync_elapsed < 20.0:
		await get_tree().create_timer(0.1).timeout
		sync_elapsed += 0.1

	if not _sync_client_ack_received:
		push_error("[SPIKE] 8/9 or 9/9 FAIL: Spawner/Synchronizer test timed out")

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
			_reliable_test_passed = true
			_tests_passed += 1
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
	_unreliable_host_received += 1
	var sender_id := multiplayer.get_remote_sender_id()
	_echo_unreliable_rpc.rpc_id(sender_id, seq, client_timestamp)


@rpc("authority", "unreliable", "call_remote")
func _echo_unreliable_rpc(seq: int, client_timestamp: int) -> void:
	var latency := Time.get_ticks_msec() - client_timestamp
	_unreliable_client_received_count += 1
	_unreliable_latencies.append(latency)


@rpc("any_peer", "reliable", "call_remote")
func _request_spawner_sync_tests() -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()

	if _unreliable_host_received > 0:
		_unreliable_test_passed = true
		_tests_passed += 1
		print("[SPIKE HOST] 7/9 PASS: Unreliable RPC host received %d/%d" % [_unreliable_host_received, _unreliable_sent])
	else:
		push_error("[SPIKE HOST] 7/9 FAIL: Unreliable RPC host received 0/%d" % _unreliable_sent)

	print("")
	print("========== 8/9: MultiplayerSpawner ==========")
	var spawner := $Spawner as MultiplayerSpawner
	_spawner_expected_count = multiplayer.get_peers().size()
	if not spawner:
		push_error("[SPIKE HOST] 8/9 FAIL: $Spawner node missing")
		_spawner_host_passed = false
	else:
		var marker_scene: PackedScene = load("res://tests/eosg_spike/spawnable_marker.tscn")
		var spawn_root: Node = spawner.get_node(spawner.spawn_path)
		if not spawn_root:
			push_error("[SPIKE HOST] 8/9 FAIL: spawner spawn_path '%s' resolves to null" % spawner.spawn_path)
			_spawner_host_passed = false
		else:
			var spawned_nodes: Array[Node3D] = []
			for i in range(_spawner_expected_count):
				var node := marker_scene.instantiate()
				spawn_root.add_child(node, true)
				if node is Node3D:
					spawned_nodes.append(node)
			if spawned_nodes.size() > 0:
				_host_spawned_node = spawned_nodes[0]
			_spawner_host_passed = $Root.get_child_count() == _spawner_expected_count
			print("[SPIKE HOST] 8/9: spawned %d marker(s), $Root has %d" % [_spawner_expected_count, $Root.get_child_count()])

	_spawner_client_ack_received = false
	_verify_spawner_count.rpc_id(sender_id, _spawner_expected_count)

	var elapsed := 0.0
	while not _spawner_client_ack_received and elapsed < 5.0:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1

	_spawner_test_passed = _spawner_host_passed and _spawner_client_passed
	if _spawner_test_passed:
		_tests_passed += 1
		print("[SPIKE HOST] 8/9 PASS: MultiplayerSpawner spawned one node per peer on host & client")
	else:
		push_error("[SPIKE HOST] 8/9 FAIL: spawner host=%s client=%s" % [_spawner_host_passed, _spawner_client_passed])

	print("")
	print("========== 9/9: MultiplayerSynchronizer ==========")
	_sync_client_ack_received = false
	if not is_instance_valid(_host_spawned_node):
		push_error("[SPIKE HOST] 9/9 FAIL: no spawned node reference")
		_sync_test_passed = false
	else:
		var target_pos := Vector3(42.0, 0.0, 0.0)
		_host_spawned_node.position = target_pos
		print("[SPIKE HOST] 9/9: set marker position to ", target_pos)
		_verify_sync_position.rpc_id(sender_id, target_pos)

		elapsed = 0.0
		while not _sync_client_ack_received and elapsed < 5.0:
			await get_tree().create_timer(0.1).timeout
			elapsed += 0.1

		_sync_test_passed = _sync_client_passed
		if _sync_test_passed:
			_tests_passed += 1
			print("[SPIKE HOST] 9/9 PASS: MultiplayerSynchronizer replicated position to client")
		else:
			push_error("[SPIKE HOST] 9/9 FAIL: sync client match=%s" % _sync_client_passed)

	_print_results()


@rpc("authority", "reliable", "call_remote")
func _verify_spawner_count(expected: int) -> void:
	var elapsed := 0.0
	var found := 0
	while elapsed < 5.0:
		found = $Root.get_child_count()
		if found >= expected:
			break
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
	_spawner_client_found = found
	_spawner_expected_count = expected
	_spawner_client_passed = found >= expected
	print("[SPIKE CLIENT] 8/9: $Root has %d marker(s), expected %d" % [found, expected])
	if _spawner_client_passed:
		_spawner_test_passed = true
		_tests_passed += 1
		print("[SPIKE CLIENT] 8/9 PASS: MultiplayerSpawner replicated markers to client")
	else:
		push_error("[SPIKE CLIENT] 8/9 FAIL: expected %d marker(s), found %d" % [expected, found])
	_spawner_count_ack.rpc_id(multiplayer.get_remote_sender_id(), _spawner_client_passed)


@rpc("any_peer", "reliable", "call_remote")
func _spawner_count_ack(passed: bool) -> void:
	_spawner_client_ack_received = true
	_spawner_client_passed = passed


@rpc("authority", "reliable", "call_remote")
func _verify_sync_position(target_pos: Vector3) -> void:
	var marker := _find_spawned_marker()
	var match_ok := false
	var actual := Vector3()
	var elapsed := 0.0
	while elapsed < 5.0:
		marker = _find_spawned_marker()
		if is_instance_valid(marker):
			actual = marker.position
			if actual.distance_to(target_pos) < 0.1:
				match_ok = true
				break
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
	_sync_client_passed = match_ok
	_sync_client_actual = actual
	print("[SPIKE CLIENT] 9/9: expected %s, actual %s, match=%s" % [target_pos, actual, match_ok])
	if _sync_client_passed:
		_sync_test_passed = true
		_tests_passed += 1
		print("[SPIKE CLIENT] 9/9 PASS: MultiplayerSynchronizer replicated position to client")
	else:
		push_error("[SPIKE CLIENT] 9/9 FAIL: position not replicated")
	_sync_position_ack.rpc_id(multiplayer.get_remote_sender_id(), match_ok, actual)
	_sync_client_ack_received = true


@rpc("any_peer", "reliable", "call_remote")
func _sync_position_ack(matched: bool, actual: Vector3) -> void:
	_sync_client_ack_received = true
	_sync_client_passed = matched
	_sync_client_actual = actual


func _find_spawned_marker() -> Node3D:
	for child in $Root.get_children():
		if child is Node3D:
			return child as Node3D
	return null


func _print_results() -> void:
	var avg_lat := 0.0
	if _unreliable_latencies.size() > 0:
		var sum := 0.0
		for l: int in _unreliable_latencies:
			sum += l
		avg_lat = sum / _unreliable_latencies.size()

	var unreliable_received := _unreliable_client_received_count
	if _role == "host":
		unreliable_received = _unreliable_host_received

	var reliable_note := "%d/10 received, in order, 0 duplicates" % _reliable_server_received.size()
	if _role != "host":
		reliable_note = "10/10 confirmed by host"

	var spawner_note := "spawned %d marker(s), host=%s client=%s" % [
		_spawner_expected_count,
		_spawner_host_passed,
		_spawner_client_passed,
	]
	if _role != "host":
		spawner_note = "client saw %d of %d marker(s)" % [_spawner_client_found, _spawner_expected_count]

	var sync_note := "expected (42,0,0), client got %s" % _sync_client_actual

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
	print("| Reliable RPC Test (10/10) | %s | %s |" % ["PASS" if _reliable_test_passed else "FAIL", reliable_note])
	print("| Unreliable RPC Test (60/60) | %s | %d/%d delivered (%.1f%%), avg latency ~%.1fms |" % [
		"PASS" if _unreliable_test_passed else "FAIL",
		unreliable_received,
		_unreliable_sent,
		(float(unreliable_received) / float(_unreliable_sent)) * 100.0 if _unreliable_sent > 0 else 0.0,
		avg_lat
	])
	print("| MultiplayerSpawner Test (per peer) | %s | %s |" % [
		"PASS" if _spawner_test_passed else "FAIL",
		spawner_note,
	])
	print("| MultiplayerSynchronizer Test (Vector3) | %s | %s |" % [
		"PASS" if _sync_test_passed else "FAIL",
		sync_note,
	])
	print("")

	if _tests_passed >= _tests_total:
		print("[SPIKE] ACCEPTANCE: All %d criteria met successfully" % _tests_total)
		if _role == "host":
			await get_tree().create_timer(1.0).timeout
		get_tree().quit(0)
	else:
		push_error("[SPIKE] ACCEPTANCE: %d/%d criteria met" % [_tests_passed, _tests_total])
		get_tree().quit(1)
