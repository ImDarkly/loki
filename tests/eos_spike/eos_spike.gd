extends Node

const SOCKET_ID := "LokiSpikeSocket"
const ROOM_CODE_CHARS := "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
const ROOM_CODE_LENGTH := 6

enum Role { NONE, HOST, CLIENT }

var _role: int = Role.NONE
var _room_code: String = ""

var _peer: EOSMultiplayerPeer
var _lobby_id: String = ""
var _client_peer_id: int = 0
var _is_host: bool = false
var _connected: bool = false
var _test_results: Array[Dictionary] = []

var _item2_pongs: int = 0
var _item3_received: Array[int] = []
var _item3_times: Array[float] = []
var _item3_host_result: Dictionary = {}
var _item3_done: bool = false
var _host_spawned_node: Node3D
var _item4_host_done: bool = false
var _item5_host_done: bool = false


func _ready() -> void:
	_parse_args()
	EOSManager.eos_ready.connect(_on_eos_ready)
	EOSManager.eos_failed.connect(_on_eos_failed)
	EOSManager.initialize()


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			var val := arg.trim_prefix("--role=")
			match val:
				"host":
					_role = Role.HOST
					_is_host = true
				"client":
					_role = Role.CLIENT
		elif arg.begins_with("--room-code="):
			_room_code = arg.trim_prefix("--room-code=")


func _generate_room_code() -> String:
	var code := ""
	for i in range(ROOM_CODE_LENGTH):
		code += ROOM_CODE_CHARS[randi() % ROOM_CODE_CHARS.length()]
	return code


func _on_eos_ready() -> void:
	match _role:
		Role.HOST:
			_run_host()
		Role.CLIENT:
			_run_client()
		_:
			_run_single()


func _on_eos_failed(reason: String) -> void:
	push_error("[SPIKE] EOS init failed: ", reason)
	get_tree().quit(1)


# ========== Single-peer mode (original init-only test) ==========
func _run_single() -> void:
	_peer = EOSMultiplayerPeer.new()
	var err: Error = _peer.create_mesh(SOCKET_ID)
	if err != OK:
		push_error("[SPIKE] create_mesh failed: ", err)
		get_tree().quit(1)
		return

	multiplayer.multiplayer_peer = _peer
	print("[SPIKE] Single-peer mode — EOS init, create_mesh, peer assignment OK")
	print("    get_unique_id: ", _peer.get_unique_id())
	print("    get_connection_status: ", _peer.get_connection_status())
	print("    socket_id: ", _peer.get_socket_id())
	print("")
	print("NOTE: For two-peer testing, use --role=host and --role=client --room-code=XXXXXX")
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()


# ========== Host setup ==========
func _run_host() -> void:
	print("[HOST] Creating EOS lobby for peer discovery...")

	var create_opts := EOSLobby_CreateLobbyOptions.new()
	create_opts.local_user_id = EOSManager.product_user_id
	create_opts.max_lobby_members = 4
	create_opts.permission_level = EOSLobby.LPL_PUBLICADVERTISED
	create_opts.bucket_id = "SpikeBucket"
	var create_result: EOSLobby_CreateLobbyCallbackInfo = await EOSLobby.create_lobby(create_opts)
	if create_result.result_code != EOS.Success:
		push_error("[HOST] Lobby create failed: ", EOS.result_to_string(create_result.result_code))
		get_tree().quit(1)
		return

	_lobby_id = create_result.lobby_id
	_room_code = _generate_room_code()

	var mod := EOSLobby.update_lobby_modification(EOSManager.product_user_id, _lobby_id)
	if not is_instance_valid(mod):
		push_error("[HOST] update_lobby_modification failed")
		get_tree().quit(1)
		return

	var attr := EOSLobby_AttributeData.new()
	attr.key = "ROOM_CODE"
	attr.value = _room_code
	mod.add_attribute(attr, EOSLobby.LAT_PUBLIC)
	var update_result: EOSLobby_UpdateLobbyCallbackInfo = await EOSLobby.update_lobby(mod)
	if update_result.result_code != EOS.Success:
		push_error("[HOST] Lobby attribute update failed")
		get_tree().quit(1)
		return

	print("[HOST] Lobby created. Room code: ", _room_code)
	print("[HOST] Lobby ID: ", _lobby_id)
	print("")
	print("TO LAUNCH CLIENT:")
	print('  --role=client --room-code=%s' % _room_code)
	print("")

	_peer = EOSMultiplayerPeer.new()
	EOSP2P.set_relay_control(EOSP2P.RC_ForceRelays)
	var err: Error = _peer.create_server(SOCKET_ID)
	if err != OK:
		push_error("[HOST] create_server failed: ", err)
		get_tree().quit(1)
		return

	multiplayer.multiplayer_peer = _peer
	multiplayer.peer_connected.connect(_on_host_peer_connected)
	print("[HOST] EOSMultiplayerPeer server listening on socket: ", SOCKET_ID)
	print("[HOST] is_server: ", multiplayer.is_server())
	print("[HOST] unique_id: ", _peer.get_unique_id())
	print("[HOST] Waiting for client connection...")


# ========== Client setup ==========
func _run_client() -> void:
	if _room_code.is_empty():
		push_error("[CLIENT] --room-code=XXXXXX is required for client mode")
		get_tree().quit(1)
		return

	print("[CLIENT] Searching for lobby with room code: ", _room_code)

	var search := EOSLobby.create_lobby_search(5)
	if not is_instance_valid(search):
		push_error("[CLIENT] create_lobby_search failed")
		get_tree().quit(1)
		return

	var param := EOSLobby_AttributeData.new()
	param.key = "ROOM_CODE"
	param.value = _room_code
	search.set_parameter(param, EOS.CO_EQUAL)

	var find_result: EOS.Result = await search.find(EOSManager.product_user_id)
	if find_result != EOS.Success or search.get_search_result_count() == 0:
		push_error("[CLIENT] Lobby not found for room code: ", _room_code)
		get_tree().quit(1)
		return

	var details := search.copy_search_result_by_index(0)
	if not is_instance_valid(details):
		push_error("[CLIENT] Failed to copy lobby details")
		get_tree().quit(1)
		return

	var info := details.copy_info()
	_lobby_id = info.lobby_id

	var join_opts := EOSLobby_JoinLobbyOptions.new()
	join_opts.lobby_details = details
	join_opts.local_user_id = EOSManager.product_user_id
	var join_result: EOSLobby_JoinLobbyCallbackInfo = await EOSLobby.join_lobby(join_opts)
	if join_result.result_code != EOS.Success:
		push_error("[CLIENT] Join lobby failed: ", EOS.result_to_string(join_result.result_code))
		get_tree().quit(1)
		return

	var host_puid := details.get_lobby_owner()
	if not is_instance_valid(host_puid):
		push_error("[CLIENT] Failed to get lobby owner PUID")
		get_tree().quit(1)
		return

	print("[CLIENT] Joined lobby: ", _lobby_id)
	print("[CLIENT] Host PUID acquired")

	_peer = EOSMultiplayerPeer.new()
	EOSP2P.set_relay_control(EOSP2P.RC_ForceRelays)
	var err: Error = _peer.create_client(SOCKET_ID, host_puid)
	if err != OK:
		push_error("[CLIENT] create_client failed: ", err)
		get_tree().quit(1)
		return

	multiplayer.multiplayer_peer = _peer
	print("[CLIENT] EOSMultiplayerPeer client connecting to host...")
	print("[CLIENT] unique_id: ", _peer.get_unique_id())

	multiplayer.peer_connected.connect(_on_client_peer_connected)
	_make_connection_timeout(15.0)


func _make_connection_timeout(seconds: float) -> void:
	var t := get_tree().create_timer(seconds)
	t.timeout.connect(func():
		if not _connected:
			var status := _peer.get_connection_status()
			var status_str := "unknown"
			match status:
				0: status_str = "CONNECTION_DISCONNECTED"
				1: status_str = "CONNECTION_CONNECTING"
				2: status_str = "CONNECTION_CONNECTED"
			push_error("[CLIENT] Connection timeout — no peer_connected within %.0fs" % seconds)
			push_error("[CLIENT]   connection_status: %s (%d)" % [status_str, status])
			push_error("[CLIENT]   unique_id: %d" % _peer.get_unique_id())
			push_error("[CLIENT]   socket_id: %s" % _peer.get_socket_id())
			get_tree().quit(1)
	)


# ========== Item 1: Peer identity/state parity ==========
func _on_client_peer_connected(id: int) -> void:
	if _connected:
		return
	_connected = true

	print("")
	print("========== Item 1: Peer identity/state parity ==========")
	print("[ITEM 1] Client connected — host peer ID: ", id)
	print("[ITEM 1] Client unique_id: ", _peer.get_unique_id())
	print("[ITEM 1] Client is_server: ", multiplayer.is_server())
	print("[ITEM 1] Connected to peer ID 1 (server): ", id == 1)
	var client_pass := id == 1 and _peer.get_unique_id() > 0
	print("[ITEM 1] Client %s" % ["PASS" if client_pass else "FAIL"])
	_test_results.append({"item": 1, "pass": client_pass, "note": "client: connected to peer %d, unique_id=%d" % [id, _peer.get_unique_id()]})


func _on_host_peer_connected(id: int) -> void:
	if _connected:
		return
	_connected = true

	_client_peer_id = id
	print("")
	print("========== Item 1: Peer identity/state parity ==========")
	print("[ITEM 1] Host — client peer ID: ", id)
	print("[ITEM 1] Host unique_id: ", _peer.get_unique_id())
	print("[ITEM 1] Host is_server: ", multiplayer.is_server())
	print("[ITEM 1] Peer ID is stable and non-zero: ", id > 0)
	var host_pass := id > 0 and multiplayer.is_server()
	print("[ITEM 1] Host %s" % ["PASS" if host_pass else "FAIL"])
	_test_results.append({"item": 1, "pass": host_pass, "note": "host: peer_connected id=%d, is_server=%s" % [id, multiplayer.is_server()]})

	print("")
	print("========== Starting Verification Tests ==========")
	print("")
	_run_tests_from_host()


# ========== Host-side test orchestration ==========
func _run_tests_from_host() -> void:
	await get_tree().create_timer(0.5).timeout
	await _test_item2()
	await _test_item3()
	await _test_item4()
	await _test_item5()
	_print_summary()


# ========== Item 2: Reliable RPC ==========
@rpc("any_peer", "reliable")
func _ping(seq: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	print("[ITEM 2] Client received ping seq=%d from peer %d" % [seq, sender])
	_pong.rpc_id(sender, seq)


@rpc("any_peer", "reliable")
func _pong(seq: int) -> void:
	_item2_pongs += 1
	print("[ITEM 2] Host received pong seq=%d (ok=%d/10)" % [seq, _item2_pongs])


func _test_item2() -> void:
	print("========== Item 2: Reliable RPC round-trip ==========")
	_item2_pongs = 0

	for seq in range(10):
		_ping.rpc_id(_client_peer_id, seq)
		await get_tree().create_timer(0.15).timeout

	await get_tree().create_timer(1.0).timeout

	var pass_ := _item2_pongs == 10
	print("[ITEM 2] Sent 10, received %d pongs" % _item2_pongs)
	print("[ITEM 2] %s" % ["PASS" if pass_ else "FAIL"])
	_test_results.append({"item": 2, "pass": pass_, "note": "pongs=%d/10" % _item2_pongs})
	print("")


# ========== Item 3: Unreliable RPC ==========
@rpc("any_peer", "unreliable")
func _unreliable_test(seq: int, timestamp: float) -> void:
	_item3_received.append(seq)
	_item3_times.append(Time.get_unix_time_from_system() - timestamp)


@rpc("any_peer", "reliable")
func _unreliable_report(total_sent: int) -> void:
	_item3_done = true
	var received := _item3_received.size()
	var dropped := total_sent - received
	var out_of_order := 0
	var max_gap := 0
	for i in range(1, _item3_received.size()):
		var gap := _item3_received[i] - _item3_received[i - 1]
		if gap < 0:
			out_of_order += 1
		if abs(gap) > max_gap:
			max_gap = abs(gap)

	var avg_latency := 0.0
	if _item3_times.size() > 0:
		for t in _item3_times:
			avg_latency += t
		avg_latency /= _item3_times.size()

	print("========== Item 3: Unreliable RPC ==========")
	print("[ITEM 3] Sent: ", total_sent)
	print("[ITEM 3] Received: ", received)
	print("[ITEM 3] Dropped: ", dropped)
	print("[ITEM 3] Delivery: %.1f%%" % (float(received) / float(total_sent) * 100.0 if total_sent > 0 else 0.0))
	print("[ITEM 3] Out-of-order: ", out_of_order)
	print("[ITEM 3] Max gap: ", max_gap)
	print("[ITEM 3] Avg latency: %.3fs" % avg_latency)

	_item3_confirm.rpc_id(multiplayer.get_remote_sender_id(), received, total_sent, out_of_order, max_gap, avg_latency)


@rpc("any_peer", "reliable")
func _item3_confirm(received: int, total: int, ooo: int, gap: int, latency: float) -> void:
	_item3_done = true
	var pass_ := received > 0
	print("[ITEM 3] %s" % ["PASS" if pass_ else "FAIL"])
	_test_results.append({"item": 3, "pass": pass_, "note": "received %d/%d (%.1f%%), ooo=%d, gap=%d, avg_latency=%.3fs" % [received, total, float(received)/float(total)*100.0, ooo, gap, latency]})
	print("")


func _test_item3() -> void:
	print("========== Item 3: Unreliable RPC ==========")
	print("[ITEM 3] Host sending 60 unreliable packets (~1s burst)...")

	_item3_received.clear()
	_item3_times.clear()
	_item3_done = false

	var burst_start := Time.get_ticks_msec()
	for i in range(60):
		_unreliable_test.rpc(i, Time.get_unix_time_from_system())
		await get_tree().create_timer(0.016).timeout
	var burst_ms := Time.get_ticks_msec() - burst_start
	print("[ITEM 3] Burst sent in %.0fms" % burst_ms)

	await get_tree().create_timer(2.0).timeout
	_unreliable_report.rpc_id(_client_peer_id, 60)

	var timeout := get_tree().create_timer(3.0)
	while not _item3_done and timeout.time_left > 0:
		await get_tree().process_frame

	if not _item3_done:
		push_error("[ITEM 3] No confirm received — host timed out")
		_test_results.append({"item": 3, "pass": false, "note": "no client confirm"})


# ========== Item 4: MultiplayerSpawner ==========
@rpc("any_peer", "reliable")
func _item4_spawned_check() -> void:
	await get_tree().create_timer(1.5).timeout
	var spawned := _find_spawned_node()
	var found := is_instance_valid(spawned)
	print("========== Item 4: MultiplayerSpawner ==========")
	print("[ITEM 4] Client looking for spawned node: ", "FOUND" if found else "NOT FOUND")
	if found:
		print("[ITEM 4] Node name: ", spawned.name, " path: ", spawned.get_path())
	_item4_client_ack.rpc_id(multiplayer.get_remote_sender_id(), found)


@rpc("any_peer", "reliable")
func _item4_client_ack(found: bool) -> void:
	_item4_host_done = true
	var node_name: String = _host_spawned_node.name if is_instance_valid(_host_spawned_node) else "unknown"
	print("[ITEM 4] Host received client check: found=%s" % found)
	print("[ITEM 4] %s" % ["PASS" if found else "FAIL"])
	_test_results.append({"item": 4, "pass": found, "note": "spawned %s, client found=%s" % [node_name, found]})
	print("")


func _find_spawned_node() -> Node3D:
	for child in $Root.get_children():
		if child is Node3D:
			return child as Node3D
	return null


func _custom_spawn(_data: Variant) -> Node:
	var scene := preload("res://tests/eos_spike/spawnable_marker.tscn")
	var node := scene.instantiate()
	return node


func _test_item4() -> void:
	print("========== Item 4: MultiplayerSpawner ==========")
	var spawner := $Spawner as MultiplayerSpawner
	if not spawner:
		push_error("[ITEM 4] Spawner node missing")
		_test_results.append({"item": 4, "pass": false, "note": "Spawner node missing"})
		return

	_item4_host_done = false
	spawner.spawn_function = _custom_spawn
	spawner.add_spawnable_scene("res://tests/eos_spike/spawnable_marker.tscn")
	var spawned := spawner.spawn()
	if not is_instance_valid(spawned):
		push_error("[ITEM 4] spawn() returned null")
		_test_results.append({"item": 4, "pass": false, "note": "spawn() returned null"})
		return

	_host_spawned_node = spawned as Node3D
	print("[ITEM 4] Host spawned node: ", spawned.name)
	print("[ITEM 4] Asking client to verify...")
	_item4_spawned_check.rpc_id(_client_peer_id)

	var timeout := get_tree().create_timer(5.0)
	while not _item4_host_done and timeout.time_left > 0:
		await get_tree().process_frame

	if not _item4_host_done:
		push_error("[ITEM 4] No client confirmation received")
		_test_results.append({"item": 4, "pass": false, "note": "no client confirmation"})


# ========== Item 5: MultiplayerSynchronizer ==========
@rpc("any_peer", "reliable")
func _item5_verify_position(pos: Vector3) -> void:
	print("========== Item 5: MultiplayerSynchronizer ==========")
	var spawned := _find_spawned_node()
	if not spawned:
		print("[ITEM 5] Client: spawned node not found in $Root")
		_item5_client_ack.rpc_id(multiplayer.get_remote_sender_id(), false, Vector3(), pos)
		return

	var match_ok := false
	var actual := spawned.position
	for i in range(20):
		actual = spawned.position
		if actual.distance_to(pos) < 0.1:
			match_ok = true
			break
		await get_tree().create_timer(0.1).timeout

	print("[ITEM 5] Expected position: ", pos)
	print("[ITEM 5] Actual position:   ", actual)
	print("[ITEM 5] Match: ", match_ok)
	_item5_client_ack.rpc_id(multiplayer.get_remote_sender_id(), match_ok, actual, pos)


@rpc("any_peer", "reliable")
func _item5_client_ack(match_ok: bool, actual_pos: Vector3, expected_pos: Vector3) -> void:
	_item5_host_done = true
	var pass_ := match_ok
	print("[ITEM 5] %s" % ["PASS" if pass_ else "FAIL"])
	_test_results.append({"item": 5, "pass": pass_, "note": "position match=%s (expected %s, client got %s)" % [match_ok, expected_pos, actual_pos]})
	print("")


func _test_item5() -> void:
	print("========== Item 5: MultiplayerSynchronizer ==========")
	_item5_host_done = false

	if not is_instance_valid(_host_spawned_node):
		push_error("[ITEM 5] No spawned node reference on host")
		_test_results.append({"item": 5, "pass": false, "note": "no spawned node"})
		return

	var target_pos := Vector3(42.0, 0.0, 0.0)
	_host_spawned_node.position = target_pos
	print("[ITEM 5] Host set position to ", target_pos)
	print("[ITEM 5] Asking client to verify...")
	_item5_verify_position.rpc_id(_client_peer_id, target_pos)

	var timeout := get_tree().create_timer(5.0)
	while not _item5_host_done and timeout.time_left > 0:
		await get_tree().process_frame

	if not _item5_host_done:
		push_error("[ITEM 5] No client confirmation received")
		_test_results.append({"item": 5, "pass": false, "note": "no client confirmation"})


# ========== Summary ==========
func _print_summary() -> void:
	print("")
	print("========================================")
	print("  EOS Transport Spike — Final Results")
	print("========================================")
	var all_pass := true
	for r in _test_results:
		var mark := "PASS" if r.pass else "FAIL"
		if not r.pass:
			all_pass = false
		print("  Item %d: %s — %s" % [r.item, mark, r.note])
	print("")

	if all_pass:
		print("  ALL ITEMS PASSED")
	else:
		print("  SOME ITEMS FAILED — see above")

	print("")
	print("--- Non-trivial findings ---")
	print("  1. multiplayer.is_server() returns true only in MODE_SERVER.")
	print("     In MODE_MESH it is always false (GD-EOS demo uses mesh).")
	print("  2. TRANSFER_MODE_UNRELIABLE_ORDERED silently upgraded to")
	print("     reliable by EOSMultiplayerPeer C++ source (confirmed).")
	print("  3. Game code relying on is_server() for authority gating")
	print("     (game_manager.gd, health_component.gd, etc.) will need")
	print("     review if mesh mode is used in production.")
	print("================================")

	await get_tree().create_timer(2.0).timeout
	get_tree().quit()
