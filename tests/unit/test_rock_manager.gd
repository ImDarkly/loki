extends GutTest

var manager: Node3D


func before_each() -> void:
	var scene: PackedScene = load("res://systems/rocks/rock_manager.tscn")
	manager = autofree(scene.instantiate())
	add_child(manager)
	await get_tree().process_frame

	manager.call("set_rocks", [
		{"position": Vector3(30, 0, 0), "available": true},
		{"position": Vector3(-30, 0, 10), "available": true}
	])


func test_point_availability_after_pickup() -> void:
	assert_true(manager.is_point_available(0))
	manager.request_pickup(0)
	assert_false(manager.is_point_available(0))


func test_pickup_of_unavailable_is_noop() -> void:
	manager.request_pickup(0)
	assert_false(manager.is_point_available(0))
	manager.request_pickup(0)
	assert_false(manager.is_point_available(0))


func test_nearest_available_found() -> void:
	assert_eq(manager.get_nearest_available_point(Vector3(28, 0, 0), 10.0), 0)


func test_nearest_available_out_of_range() -> void:
	assert_eq(manager.get_nearest_available_point(Vector3(0, 0, 0), 5.0), -1)


func test_nearest_available_skips_depleted() -> void:
	manager.request_pickup(0)
	assert_eq(manager.get_nearest_available_point(Vector3(28, 0, 0), 100.0), 1)


func test_nearest_available_sentinel_when_all_depleted() -> void:
	manager.request_pickup(0)
	manager.request_pickup(1)
	assert_eq(manager.get_nearest_available_point(Vector3(0, 0, 0), 100.0), -1)


func test_respawn_after_delay() -> void:
	manager.request_pickup(0)
	assert_false(manager.is_point_available(0))
	manager._cooldowns[0] = 1.0
	manager._on_respawn_tick()
	assert_true(manager.is_point_available(0))


func test_placement_respects_minimum_spacing() -> void:
	manager.min_rock_spacing = 10.0
	manager.call("set_rocks", [
		{"position": Vector3(30, 0, 0), "available": true},
		{"position": Vector3(-30, 0, 0), "available": true}
	])
	assert_false(manager._is_clear_of_other_rocks(Vector3(35, 0, 0)))
	assert_true(manager._is_clear_of_other_rocks(Vector3(35, 0, 10)))


func test_get_debug_state_keys_and_types() -> void:
	var st = manager.get_debug_state()
	assert_true(st.has("rock_count"))
	assert_true(st.has("available"))
	assert_true(st.has("respawn_timer_left"))
	assert_true(st.has("cooldowns_active"))
	assert_eq(typeof(st["rock_count"]), TYPE_INT)
	assert_eq(typeof(st["available"]), TYPE_INT)
	assert_eq(typeof(st["respawn_timer_left"]), TYPE_INT)
	assert_eq(typeof(st["cooldowns_active"]), TYPE_INT)


func test_get_debug_actions_ids_and_labels() -> void:
	var acts = manager.get_debug_actions()
	assert_eq(acts.size(), 2)
	var map = {}
	for act in acts:
		map[act["id"]] = act["label"]
	assert_eq(map.get("respawn_all"), "Respawn All")
	assert_eq(map.get("clear_all"), "Clear All")


func test_debug_actions_execution() -> void:
	assert_true(manager.is_point_available(0))
	manager.debug_action("clear_all")
	assert_false(manager.is_point_available(0), "clear_all should make rocks unavailable")
	manager.debug_action("respawn_all")
	assert_true(manager.is_point_available(0), "respawn_all should restore rock availability")


func test_debug_action_client_noop() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", 1)
	manager.multiplayer.multiplayer_peer = peer
	manager.debug_action("clear_all")
	assert_true(manager.is_point_available(0), "Client should no-op debug_action")
	manager.multiplayer.multiplayer_peer = null


func test_rock_manager_registers_with_debug_overlay() -> void:
	var dbg = get_node_or_null("/root/DebugOverlay")
	assert_not_null(dbg, "DebugOverlay autoload missing")
	assert_true(dbg._systems.has(manager.name), "RockManager should register with DebugOverlay")
