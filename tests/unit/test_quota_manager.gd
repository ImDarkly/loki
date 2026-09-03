extends GutTest

var quota_manager: Node3D


func before_each() -> void:
	var scene: PackedScene = load("res://systems/quota/quota_manager.tscn")
	quota_manager = autofree(scene.instantiate())
	add_child(quota_manager)
	await get_tree().process_frame


func test_get_debug_state_keys_and_types() -> void:
	var st = quota_manager.get_debug_state()
	assert_true(st.has("shared_quota"))
	assert_eq(typeof(st["shared_quota"]), TYPE_INT)


func test_get_debug_actions_ids_and_labels() -> void:
	var acts = quota_manager.get_debug_actions()
	assert_eq(acts.size(), 2)
	var map = {}
	for act in acts:
		map[act["id"]] = act["label"]
	assert_eq(map.get("add_quota_10"), "+10 Quota")
	assert_eq(map.get("clear_quota"), "Clear Quota")


func test_debug_actions_execution() -> void:
	quota_manager.shared_quota = 5
	quota_manager.debug_action("add_quota_10")
	assert_eq(quota_manager.shared_quota, 15)

	quota_manager.debug_action("clear_quota")
	assert_eq(quota_manager.shared_quota, 0)


func test_debug_action_client_noop() -> void:
	quota_manager.shared_quota = 5
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", 1)
	quota_manager.multiplayer.multiplayer_peer = peer
	quota_manager.debug_action("add_quota_10")
	assert_eq(quota_manager.shared_quota, 5, "Client should no-op debug_action")
	quota_manager.multiplayer.multiplayer_peer = null


func test_quota_manager_registers_with_debug_overlay() -> void:
	var dbg = get_node_or_null("/root/DebugOverlay")
	assert_not_null(dbg, "DebugOverlay autoload missing")
	assert_true(dbg._systems.has(quota_manager.name), "QuotaManager should register with DebugOverlay")
