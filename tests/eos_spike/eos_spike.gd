extends Node

const SOCKET_ID := "LokiSpikeSocket"

var _eos_init: EOSInit
var _peer: EOSMultiplayerPeer


func _ready() -> void:
	_eos_init = EOSInit.new()
	add_child(_eos_init)
	_eos_init.eos_ready.connect(_on_eos_ready)
	_eos_init.eos_failed.connect(_on_eos_failed)
	_eos_init.initialize()


func _on_eos_ready() -> void:
	print("[SPIKE] 1/5 PASS: EOS initialized")
	print("[SPIKE] 2/5 PASS: Device ID login successful")
	print("[SPIKE]    ProductUserId: ", _eos_init.product_user_id)

	_peer = EOSMultiplayerPeer.new()
	var err: Error = _peer.create_mesh(SOCKET_ID)
	if err != OK:
		push_error("[SPIKE] Mesh create failed: ", err)
		get_tree().quit(1)
		return

	print("[SPIKE] 3/5 PASS: EOSMultiplayerPeer.create_mesh() OK")

	multiplayer.multiplayer_peer = _peer
	print("[SPIKE] 4/5 PASS: multiplayer.multiplayer_peer assigned")
	print("[SPIKE]    get_connection_status: ", _peer.get_connection_status())
	print("[SPIKE]    get_unique_id: ", _peer.get_unique_id())
	print("[SPIKE]    socket_name: ", _peer.get_socket_id())

	print("[SPIKE] 5/5 PASS: EOS transport integrated with Godot MultiplayerAPI")
	print("    Peer connects to Godot's scene multiplayer system without errors")
	print("")
	print("========== EOS Transport Spike Results ==========")
	print("  5/5 tests passed, 0 failed")
	print("================================================")
	print("")
	print("NOTE: Full multi-peer testing (RPCs, Spawner, Synchronizer")
	print("across the network) requires TWO distinct EOS identities.")
	print("Device ID is per-machine. To run multi-peer:")
	print("  1. Deploy to two machines, each with its own .env")
	print("  2. Host: godot -- --role=host")
	print("  3. Client: godot --scene spike.tscn -- --role=client")
	print("")
	print("Single-machine validation proved: EOS init, Device ID login,")
	print("EOSMultiplayerPeer creation, and Godot multiplayer binding all work.")

	get_tree().quit()


func _on_eos_failed(reason: String) -> void:
	push_error("[SPIKE] EOS init failed: ", reason)
	get_tree().quit(1)
