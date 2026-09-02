extends GutTest

var manager: Node3D
var mock_player: Node3D


func before_each() -> void:
	var scene: PackedScene = load("res://systems/danger/danger_manager.tscn")
	manager = autofree(scene.instantiate())
	add_child(manager)
	await get_tree().process_frame

	manager.spawn_timer.stop()
	manager.return_timer.stop()

	mock_player = Node3D.new()
	mock_player.name = "Player_1"
	var mock_script := GDScript.new()
	mock_script.source_code = "extends Node3D\nvar is_yelling: bool = false\n"
	mock_script.reload()
	mock_player.set_script(mock_script)
	add_child(mock_player)
	manager.set_player_ref(mock_player)

	var health_component := HealthComponent.new()
	health_component.name = "HealthComponent"
	mock_player.add_child(health_component)


func test_initial_state_is_inactive() -> void:
	assert_eq(manager.current_state, 0, "Should start INACTIVE (0)")


func test_spawn_timer_transitions_from_inactive_to_approaching() -> void:
	manager.current_state = 0
	manager._on_spawn_timer_timeout()
	assert_eq(manager.current_state, 1, "Should be APPROACHING (1)")
	assert_true(is_instance_valid(manager.shark_node), "Shark mesh should exist")


func test_spawn_timer_transitions_from_waiting_to_approaching() -> void:
	manager.current_state = 4
	manager._on_spawn_timer_timeout()
	assert_eq(manager.current_state, 1, "Should be APPROACHING (1)")


func test_repel_transitions_to_retreating_when_in_range() -> void:
	manager.current_state = 1 # APPROACHING
	manager._spawn_shark() # Make sure shark_node is created
	manager.shark_node.position = Vector3(5, 0, 0)
	
	manager.repel(Vector3(0, 0, 0), Vector3(1, 0, 0)) # Ray along +x
	
	assert_eq(manager.current_state, 3, "Should be RETREATING (3) after repel")

func test_repel_no_op_when_out_of_range() -> void:
	manager.current_state = 1 # APPROACHING
	manager._spawn_shark() # Make sure shark_node is created
	manager.shark_node.position = Vector3(10, 0, 0)
	
	# Ray along x-axis at y=5, z=0. Shark at (10,0,0). Distance is 5.
	manager.repel(Vector3(0, 5, 0), Vector3(1, 0, 0))
	
	assert_eq(manager.current_state, 1, "Should stay APPROACHING (1) after out-of-range repel")


func test_attack_distance_triggers_signals() -> void:
	manager.current_state = 0
	manager._on_spawn_timer_timeout()
	manager.shark_node.position = Vector3(0, 0, -7)
	manager.player_ref.global_position = Vector3(0, 0, -7)
	manager.attack_range = 5.0

	var health := mock_player.get_node("HealthComponent") as HealthComponent
	health.current_health = 5

	watch_signals(manager)
	manager.current_state = 1
	manager._physics_process(1.0)

	assert_signal_emitted(manager, "fish_fled")
	assert_signal_not_emitted(manager, "quota_penalty")
	assert_eq(health.current_health, 3, "Health should be reduced by shark_bite_damage (2)")
	assert_eq(manager.current_state, 4, "Should be WAITING (4) after attack")
	assert_between(manager.return_timer.time_left, 45.0, 90.0, "Return interval should be 45-90 seconds")


func test_approaching_never_enters_island() -> void:
	manager.current_state = 0
	manager._on_spawn_timer_timeout()
	manager.current_state = 1
	manager.player_ref.global_position = MapConfig.MAP_CENTER
	manager.attack_range = 2.0
	manager.shark_node.position = MapConfig.MAP_CENTER + Vector3(MapConfig.ISLAND_RADIUS + 10.0, 0, 0)

	manager._physics_process(10.0)

	var flat_dist: float = Vector2(
		manager.shark_node.position.x - MapConfig.MAP_CENTER.x,
		manager.shark_node.position.z - MapConfig.MAP_CENTER.z
	).length()
	assert_gt(flat_dist, MapConfig.ISLAND_RADIUS - 0.001, "Shark should never move onto the island interior")
	assert_eq(manager.current_state, 1, "Should stay APPROACHING while the player is beyond reach")


func test_shoreline_player_within_attack_radius_is_bitten() -> void:
	manager.current_state = 0
	manager._on_spawn_timer_timeout()
	manager.current_state = 1
	manager.attack_range = 2.0
	manager.shark_node.position = MapConfig.MAP_CENTER + Vector3(MapConfig.ISLAND_RADIUS, 0, 0)
	manager.player_ref.global_position = MapConfig.MAP_CENTER + Vector3(MapConfig.ISLAND_RADIUS - 1.0, 0, 0)

	var health := mock_player.get_node("HealthComponent") as HealthComponent
	health.current_health = 5

	watch_signals(manager)
	manager._physics_process(1.0)

	assert_signal_emitted(manager, "fish_fled")
	assert_eq(health.current_health, 3, "Health should be reduced by shark_bite_damage (2)")
	assert_eq(manager.current_state, 4, "Should be WAITING (4) after attack")


func test_shoreline_player_outside_attack_radius_not_bitten() -> void:
	manager.current_state = 0
	manager._on_spawn_timer_timeout()
	manager.current_state = 1
	manager.attack_range = 2.0
	manager.shark_node.position = MapConfig.MAP_CENTER + Vector3(MapConfig.ISLAND_RADIUS, 0, 0)
	manager.player_ref.global_position = MapConfig.MAP_CENTER + Vector3(MapConfig.ISLAND_RADIUS - 3.0, 0, 0)

	watch_signals(manager)
	manager._physics_process(1.0)

	assert_signal_not_emitted(manager, "fish_fled")
	assert_eq(manager.current_state, 1, "Should stay APPROACHING when the player is beyond attack radius")

	var flat_dist: float = Vector2(
		manager.shark_node.position.x - MapConfig.MAP_CENTER.x,
		manager.shark_node.position.z - MapConfig.MAP_CENTER.z
	).length()
	assert_gt(flat_dist, MapConfig.ISLAND_RADIUS - 0.001, "Shark should wait at the shore edge")


func test_attack_radius_ring_created_when_enabled() -> void:
	manager.show_attack_radius = true
	manager.current_state = 0
	manager._on_spawn_timer_timeout()
	assert_eq(manager.shark_node.get_child_count(), 1, "Shark mesh should carry the attack-radius ring")
	var ring := manager.shark_node.get_child(0) as MeshInstance3D
	assert_true(is_instance_valid(ring), "Ring child should be a MeshInstance3D")
	assert_true(ring.visible, "Ring should be visible when show_attack_radius is on")


func test_retreating_exits_boundary_transitions_to_waiting() -> void:
	manager.current_state = 0
	manager._on_spawn_timer_timeout()
	manager.current_state = 3
	manager.spawn_position = Vector3(30, 0, -7)
	manager.shark_node.position = Vector3(20, 0, -7)

	manager._physics_process(10.0)

	assert_eq(manager.current_state, 4, "Should be WAITING (4) after exiting boundary")


func test_retreat_along_diagonal_transitions_to_waiting_at_radius() -> void:
	manager.current_state = 0
	manager._on_spawn_timer_timeout()
	manager.current_state = 3
	manager.spawn_position = Vector3(25, 0, 25)
	manager.shark_node.position = Vector3(15, 0, 15)

	manager._physics_process(10.0)

	assert_eq(manager.current_state, 4, "Corners of the legacy square fall outside the circular fishable band")


func test_retreat_reaching_spawn_position_transitions_to_waiting() -> void:
	manager.current_state = 0
	manager._on_spawn_timer_timeout()
	manager.current_state = 3
	manager.spawn_position = MapConfig.MAP_CENTER + Vector3(MapConfig.FISHABLE_BAND_RADIUS - 1.0, 0, 0)
	manager.shark_node.position = Vector3(20, 0, -7)

	manager._physics_process(1.0)

	assert_eq(manager.current_state, 4, "Reaching a spawn point inside the band should transition to WAITING")


func test_return_timer_transitions_from_waiting_to_approaching() -> void:
	manager.current_state = 4
	manager._on_return_timer_timeout()
	assert_eq(manager.current_state, 1, "Should be APPROACHING (1)")


func test_spawn_position_rejects_close_points() -> void:
	manager.player_ref.global_position = Vector3(0, 0, -7)
	manager.min_spawn_distance_from_player = 100.0

	var pos: Vector3 = manager._pick_spawn_position(mock_player)
	var dist: float = Vector2(pos.x - 0, pos.z - (-7)).length()
	assert_gt(dist, 0, "Spawn should pick some position even when all points are too close")


func test_shark_not_spawned_without_player_ref() -> void:
	manager.player_ref = null
	manager.current_state = 0
	manager._on_spawn_timer_timeout()
	assert_eq(manager.current_state, 0, "Should stay INACTIVE when no player ref")


# --- Shark Bait range-priority (BAIT-001 Decision 5) ---

func _make_bait_manager(placed: bool, fill: int, pos: Vector3) -> Node:
	var bm: Node = load("res://systems/shark_bait/shark_bait_manager.tscn").instantiate()
	bm.name = "SharkBaitManager"
	add_child_autofree(bm)
	if placed:
		bm._sync_placed(pos)
	else:
		bm.is_placed = false
		bm.placed_position = pos
	bm.bait_fill_count = fill
	manager.set_bait_manager_for_test(bm)
	return bm


func test_bait_filled_in_range_becomes_target() -> void:
	var bait_pos := Vector3(15, 0, -7)
	_make_bait_manager(true, 3, bait_pos)
	manager.bait_priority_range = 10.0
	manager._debug_spawn_override = bait_pos + Vector3(5, 0, 0)
	manager._spawn_shark()
	assert_true(manager._is_targeting_bait, "filled+in-range should lock bait at spawn")
	assert_eq(manager._bait_target_position, Vector3(bait_pos.x, 0, bait_pos.z))
	manager._debug_spawn_override = Vector3.INF


func test_bait_filled_out_of_range_ignores() -> void:
	var bait_pos := Vector3(15, 0, -7)
	_make_bait_manager(true, 3, bait_pos)
	manager.bait_priority_range = 10.0
	manager._debug_spawn_override = bait_pos + Vector3(15, 0, 0)
	manager._spawn_shark()
	assert_false(manager._is_targeting_bait, "filled+out-of-range should not lock bait")
	manager._debug_spawn_override = Vector3.INF


func test_bait_unfilled_in_range_ignores() -> void:
	var bait_pos := Vector3(15, 0, -7)
	_make_bait_manager(true, 1, bait_pos)
	manager.bait_priority_range = 10.0
	manager._debug_spawn_override = bait_pos + Vector3(5, 0, 0)
	manager._spawn_shark()
	assert_false(manager._is_targeting_bait, "unfilled+in-range should not lock")
	manager._debug_spawn_override = Vector3.INF
	_make_bait_manager(true, 0, bait_pos)
	manager._debug_spawn_override = bait_pos + Vector3(5, 0, 0)
	manager._spawn_shark()
	assert_false(manager._is_targeting_bait, "empty bait should not lock")
	manager._debug_spawn_override = Vector3.INF


func test_bait_distance_threshold_exact() -> void:
	var bait_pos := Vector3(15, 0, -7)
	_make_bait_manager(true, 3, bait_pos)
	manager.bait_priority_range = 10.0
	manager._debug_spawn_override = bait_pos + Vector3(10, 0, 0)
	manager._spawn_shark()
	assert_true(manager._is_targeting_bait, "distance == range should lock (inclusive)")
	manager._debug_spawn_override = bait_pos + Vector3(10.01, 0, 0)
	manager._spawn_shark()
	assert_false(manager._is_targeting_bait, "distance > range should not lock")
	manager._debug_spawn_override = Vector3.INF


func test_bait_no_retarget_after_spawn() -> void:
	var bait_pos := Vector3(15, 0, -7)
	var bm := _make_bait_manager(true, 3, bait_pos)
	manager.bait_priority_range = 25.0
	manager._debug_spawn_override = bait_pos + Vector3(5, 0, 0)
	manager.current_state = 1
	manager._spawn_shark()
	manager._debug_spawn_override = Vector3.INF
	assert_true(manager._is_targeting_bait, "spawn in-range should lock")
	manager.shark_node.position = Vector3(30, 0, -7)
	mock_player.global_position = Vector3(0, 0, 0)
	bm.bait_fill_count = 0
	var before: Vector3 = manager.shark_node.position
	manager._process_approaching(1.0)
	var after: Vector3 = manager.shark_node.position
	var to_bait: Vector3 = (Vector3(bait_pos.x, 0, bait_pos.z) - Vector3(before.x, 0, before.z)).normalized()
	var moved: Vector3 = (after - before).normalized()
	assert_gt(moved.dot(to_bait), 0.9, "Should keep moving toward bait despite bait now empty (no retarget)")
	assert_true(manager._is_targeting_bait, "Lock should persist after bait emptied")


func test_bait_priority_range_export_exists() -> void:
	assert_true("bait_priority_range" in manager, "bait_priority_range export should exist")
	assert_gt(manager.bait_priority_range, 0.0, "bait_priority_range should be positive tunable")


func test_shark_attack_on_bait_consumes_bait_without_despawn() -> void:
	var bait_pos := Vector3(15, 0, -7)
	var bm := _make_bait_manager(true, 3, bait_pos)
	manager.bait_priority_range = 10.0
	manager._debug_spawn_override = bait_pos + Vector3(5, 0, 0)
	manager._spawn_shark()
	assert_true(manager._is_targeting_bait)

	manager.current_state = 1 # APPROACHING
	manager.shark_node.position = bait_pos
	manager.attack_range = 2.0

	watch_signals(bm)
	manager._physics_process(1.0)

	assert_eq(bm.bait_fill_count, 0, "Bait fill count should reset to 0 on attack")
	assert_true(bm.is_placed, "Bait is_placed should remain true")
	assert_eq(bm.placed_position, bait_pos, "Bait placed_position should remain unchanged")
	assert_true(is_instance_valid(bm._bait_instance), "Bait instance should not be despawned")
	assert_eq(manager.current_state, 4, "Should transition to WAITING")
	assert_false(manager.shark_node.visible, "Shark should be hidden after attacking bait")
	assert_between(manager.return_timer.time_left, 45.0, 90.0, "Return interval should be 45-90 seconds")
	assert_signal_emitted(bm, "bait_fill_updated")


func test_get_debug_state_returns_expected_keys() -> void:
	var st = manager.get_debug_state()
	assert_true(st.has("state"))
	assert_true(st.has("targeting_bait"))
	assert_true(st.has("shark_visible"))
	assert_true(st.has("spawn"))
	assert_true(st.has("spawn_timer_left"))
	assert_true(st.has("return_timer_left"))
	assert_true(st.has("shark_pos"))
	assert_eq(typeof(st["spawn_timer_left"]), TYPE_INT)
	assert_eq(typeof(st["return_timer_left"]), TYPE_INT)


func test_get_debug_actions_returns_four_actions() -> void:
	var acts = manager.get_debug_actions()
	assert_eq(acts.size(), 4)
	var ids = []
	for act in acts:
		ids.append(act["id"])
	assert_true(ids.has("force_spawn"))
	assert_true(ids.has("force_retreat"))
	assert_true(ids.has("force_attack"))
	assert_true(ids.has("reset_inactive"))


func test_debug_actions_execution() -> void:
	manager.debug_action("force_spawn")
	assert_eq(manager.current_state, 1, "force_spawn should set state to APPROACHING (1)")
	assert_true(is_instance_valid(manager.shark_node))

	manager.debug_action("force_retreat")
	assert_eq(manager.current_state, 3, "force_retreat should set state to RETREATING (3)")

	manager.debug_action("force_attack")
	assert_eq(manager.current_state, 4, "force_attack should set state to WAITING (4)")

	manager.debug_action("reset_inactive")
	assert_eq(manager.current_state, 0, "reset_inactive should set state to INACTIVE (0)")


func test_get_debug_actions_labels() -> void:
	var acts = manager.get_debug_actions()
	var labels = {}
	for act in acts:
		labels[act["id"]] = act["label"]
	assert_eq(labels.get("force_spawn"), "Force Spawn")
	assert_eq(labels.get("force_retreat"), "Force Retreat")
	assert_eq(labels.get("force_attack"), "Force Attack")
	assert_eq(labels.get("reset_inactive"), "Reset Inactive")


func test_debug_action_client_noop() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", 1)
	manager.multiplayer.multiplayer_peer = peer
	manager.current_state = 0
	manager.debug_action("force_spawn")
	assert_eq(manager.current_state, 0, "Client should no-op debug_action")
	manager.multiplayer.multiplayer_peer = null


func test_bait_not_synced() -> void:
	manager._is_targeting_bait = true
	manager._sync_state_to_clients()
	assert_true(manager._is_targeting_bait, "Bait targeting state should remain local and not be cleared/synced by state broadcast")

