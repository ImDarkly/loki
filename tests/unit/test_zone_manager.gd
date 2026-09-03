extends GutTest

const BITE_STATE := 3
const WAITING_STATE := 1

var manager: Node3D
var _saved_multiplayer_peer: Object = null


func after_each() -> void:
	if _saved_multiplayer_peer != null:
		manager.multiplayer.multiplayer_peer = _saved_multiplayer_peer
		_saved_multiplayer_peer = null


func before_each() -> void:
	var scene: PackedScene = load("res://systems/zones/zone_manager.tscn")
	manager = autofree(scene.instantiate())
	add_child(manager)
	await get_tree().process_frame

	manager.call("set_zones", [
		{"center": Vector3(1, 0, 1), "radius": 4.0},
		{"center": Vector3(12, 0, 1), "radius": 4.0}
	])


func test_lookup_returns_matching_index_for_point_inside_zone() -> void:
	assert_eq(manager.get_zone_index_for_point(Vector3(2, 0, 1)), 0)


func test_lookup_returns_sentinel_outside_all_zones() -> void:
	assert_eq(manager.get_zone_index_for_point(Vector3(100, 0, 100)), -1)


func test_lookup_treats_boundary_as_inside() -> void:
	assert_eq(manager.get_zone_index_for_point(Vector3(5, 0, 1)), 0)


func test_entering_and_leaving_zone_updates_occupant_count() -> void:
	manager.enter_zone(0, 101)
	assert_eq(manager.zone_occupant_counts[0], 1)
	manager.leave_zone(0, 101)
	assert_eq(manager.zone_occupant_counts[0], 0)


func test_multiple_occupants_require_matching_leaves() -> void:
	manager.enter_zone(0, 101)
	manager.enter_zone(0, 202)
	assert_eq(manager.zone_occupant_counts[0], 2)

	manager.leave_zone(0, 101)
	assert_eq(manager.zone_occupant_counts[0], 1)

	manager.leave_zone(0, 202)
	assert_eq(manager.zone_occupant_counts[0], 0)


func test_leave_without_prior_enter_is_noop() -> void:
	manager.leave_zone(0, 101)
	assert_eq(manager.zone_occupant_counts[0], 0)


func test_occupied_zone_is_skipped_during_reshuffle() -> void:
	manager.enter_zone(0, 101)
	var before = manager.zones[0]["center"]
	manager._reshuffle_unoccupied_zones()
	assert_eq(manager.zones[0]["center"], before)


func test_unoccupied_zone_is_eligible_during_reshuffle() -> void:
	var before = manager.zones[1]["center"]
	manager._reshuffle_unoccupied_zones()
	assert_ne(manager.zones[1]["center"], before)


func test_placement_respects_minimum_zone_spacing() -> void:
	manager.min_zone_spacing = 10.0
	manager.set_zones([
		{"center": Vector3(0, 0, 0), "radius": 4.0},
		{"center": Vector3(20, 0, 0), "radius": 4.0}
	])
	assert_true(manager._is_valid_zone_position_excluding(Vector3(0, 0, 12), 0))


func test_placement_stays_within_water_boundary_margin() -> void:
	manager.water_boundary_margin = 2.0
	assert_true(manager._is_within_water_boundary(Vector3(0, 0, -7 + 25.0 - manager.zone_radius - manager.water_boundary_margin)))
	assert_false(manager._is_within_water_boundary(Vector3(0, 0, -7 + 25.0 - manager.zone_radius - manager.water_boundary_margin + 0.1)))


func test_disconnect_clears_peer_occupancy() -> void:
	manager.enter_zone(0, 101)
	manager.enter_zone(0, 101)
	manager._clear_peer_occupancy(101)
	assert_eq(manager.zone_occupant_counts[0], 0)


func test_reset_for_restart_clears_occupancy() -> void:
	manager.enter_zone(0, 101)
	manager.enter_zone(0, 202)
	manager.enter_zone(1, 101)
	assert_eq(manager.zone_occupant_counts[0], 2)
	assert_eq(manager.zone_occupant_counts[1], 1)

	manager.reset_for_restart()

	assert_eq(manager.zone_occupant_counts[0], 0)
	assert_eq(manager.zone_occupant_counts[1], 0)


func test_reset_for_restart_starts_timer() -> void:
	manager.reshuffle_timer.stop()
	assert_true(manager.reshuffle_timer.is_stopped())

	manager.reset_for_restart()

	assert_false(manager.reshuffle_timer.is_stopped())


func test_reset_for_restart_preserves_positions() -> void:
	var positions_before: Array[Vector3] = []
	for zone in manager.zones:
		positions_before.append(zone["center"])

	manager.reset_for_restart()

	for i in range(manager.zones.size()):
		assert_eq(manager.zones[i]["center"], positions_before[i])


func test_scare_relocates_occupied_zone_overriding_lock() -> void:
	manager.enter_zone(0, 101)
	var source := Vector3(0, 0, 0)
	var before: Vector3 = manager.zones[0]["center"]

	manager._reshuffle_unoccupied_zones()
	assert_eq(manager.zones[0]["center"], before, "Occupied zone must be skipped by idle reshuffle")

	manager.scare(source, 30.0)

	var after: Vector3 = manager.zones[0]["center"]
	assert_ne(after, before)
	assert_gt(_flat_distance(source, after), _flat_distance(source, before))


func _near_source_zone_pos() -> Vector3:
	return MapConfig.MAP_CENTER + Vector3(0, 0, MapConfig.ISLAND_RADIUS + manager.zone_radius + manager.water_boundary_margin + 1.0)


func test_scare_moves_zone_farther_from_source() -> void:
	manager.set_zones([{"center": _near_source_zone_pos(), "radius": 1.0}])
	var source := Vector3(0, 0, 0)
	var before: Vector3 = manager.zones[0]["center"]
	var before_dist := _flat_distance(source, before)

	manager.scare(source, 30.0)

	var after: Vector3 = manager.zones[0]["center"]
	assert_ne(after, before)
	assert_gt(_flat_distance(source, after), before_dist)


func test_scare_interrupts_fight_in_affected_zone() -> void:
	manager.set_zones([{"center": _near_source_zone_pos(), "radius": 1.0}])
	manager.enter_zone(0, 101)
	var mechanic := _add_mock_occupant(101, BITE_STATE, 101)
	watch_signals(mechanic)

	manager.scare(Vector3(0, 0, 0), 30.0)

	assert_signal_emitted(mechanic, "reel_failure")


func test_scare_does_not_interrupt_non_bite_occupant() -> void:
	manager.set_zones([{"center": _near_source_zone_pos(), "radius": 1.0}])
	manager.enter_zone(0, 101)
	var mechanic := _add_mock_occupant(101, WAITING_STATE, 101)
	watch_signals(mechanic)

	manager.scare(Vector3(0, 0, 0), 30.0)

	assert_signal_not_emitted(mechanic, "reel_failure")


func _far_spot_from(source: Vector3) -> Vector3:
	var dir := Vector2(MapConfig.MAP_CENTER.x - source.x, MapConfig.MAP_CENTER.z - source.z).normalized()
	var outer: float = MapConfig.FISHABLE_BAND_RADIUS - manager.zone_radius - manager.water_boundary_margin
	return MapConfig.MAP_CENTER + Vector3(dir.x, 0, dir.y) * outer


func test_scare_keeps_center_when_no_farther_candidate() -> void:
	manager.set_zones([{"center": _far_spot_from(Vector3(0, 0, 0)), "radius": 1.0}])
	var before: Vector3 = manager.zones[0]["center"]

	manager.scare(Vector3(0, 0, 0), 30.0)

	assert_eq(manager.zones[0]["center"], before)


func test_scare_interrupts_bite_in_zone_that_cannot_move() -> void:
	var far_spot := _far_spot_from(Vector3(0, 0, 0))
	manager.set_zones([{"center": far_spot, "radius": 1.0}])
	manager.enter_zone(0, 101)
	var mechanic := _add_mock_occupant(101, BITE_STATE, 101)
	watch_signals(mechanic)

	manager.scare(Vector3(0, 0, 0), 30.0)

	assert_eq(manager.zones[0]["center"], far_spot)
	assert_signal_emitted(mechanic, "reel_failure")


func test_scare_interrupts_offline_occupant_with_minus_one_owner() -> void:
	_saved_multiplayer_peer = manager.multiplayer.multiplayer_peer
	manager.multiplayer.multiplayer_peer = null
	manager.set_zones([{"center": _near_source_zone_pos(), "radius": 1.0}])
	manager.enter_zone(0, 1)
	var mechanic := _add_mock_occupant(1, BITE_STATE, -1)
	watch_signals(mechanic)

	manager.scare(Vector3(0, 0, 0), 30.0)

	assert_signal_emitted(mechanic, "reel_failure")


func test_yell_start_fires_immediate_scare_and_starts_timer() -> void:
	manager.set_zones([{"center": _near_source_zone_pos(), "radius": 1.0}])
	var yeller := _add_yelling_player(101, Vector3(0, 0, 0), true)
	manager.set_process(false)
	var before: Vector3 = manager.zones[0]["center"]
	var source: Vector3 = yeller.global_position

	manager._update_yell_scare_state()

	var after: Vector3 = manager.zones[0]["center"]
	assert_ne(after, before)
	assert_gt(_flat_distance(source, after), _flat_distance(source, before))
	assert_false(manager.yell_scare_timer.is_stopped(), "Timer must run while anyone is yelling")


func test_sustained_yelling_fires_scare_on_each_tick() -> void:
	manager.set_zones([{"center": _near_source_zone_pos(), "radius": 1.0}])
	_add_yelling_player(101, Vector3(0, 0, 0), true)
	manager.set_process(false)
	manager._update_yell_scare_state()

	for tick in range(3):
		manager.set_zones([{"center": _near_source_zone_pos(), "radius": 1.0}])
		var before: Vector3 = manager.zones[0]["center"]
		assert_eq(manager._on_yell_scare_tick(), 1, "Each tick must scare once per yeller")
		assert_ne(manager.zones[0]["center"], before, "Each tick must relocate the in-range zone")


func test_client_peer_never_scares() -> void:
	_saved_multiplayer_peer = manager.multiplayer.multiplayer_peer
	var fake_peer := _make_client_peer()
	manager.multiplayer.multiplayer_peer = fake_peer
	manager.set_zones([{"center": _near_source_zone_pos(), "radius": 1.0}])
	_add_yelling_player(101, Vector3(0, 0, 0), true)
	manager.set_process(false)
	var before: Vector3 = manager.zones[0]["center"]

	manager._update_yell_scare_state()
	assert_eq(manager.zones[0]["center"], before, "Client must not scare during poll")
	assert_true(manager.yell_scare_timer.is_stopped(), "Client must not start the scare timer")

	manager._on_yell_scare_tick()
	assert_eq(manager.zones[0]["center"], before, "Client must not scare on tick")


func test_sustained_yelling_runs_on_configured_interval() -> void:
	_add_yelling_player(101, Vector3(0, 0, 0), true)
	manager.set_process(false)

	manager._update_yell_scare_state()

	assert_false(manager.yell_scare_timer.is_stopped(), "Timer must run while sustained")
	assert_eq(manager.yell_scare_timer.wait_time, manager.yell_rescare_interval)


func test_yell_stop_stops_timer_and_halts_scares() -> void:
	manager.set_zones([{"center": _near_source_zone_pos(), "radius": 1.0}])
	var yeller := _add_yelling_player(101, Vector3(0, 0, 0), true)
	manager.set_process(false)
	manager._update_yell_scare_state()
	assert_false(manager.yell_scare_timer.is_stopped(), "Timer must be running while yelling")

	yeller.is_yelling = false
	manager._update_yell_scare_state()

	assert_true(manager.yell_scare_timer.is_stopped(), "Timer must stop when yelling ends")
	assert_eq(manager._on_yell_scare_tick(), 0, "No scares after yelling stops")


func test_new_yeller_while_another_yelling_fires_immediate_scare() -> void:
	manager.set_zones([
		{"center": Vector3(0, 0, 6.5), "radius": 1.0},
		{"center": Vector3(0, 0, -20.0), "radius": 1.0}
	])
	_add_yelling_player(101, Vector3(0, 0, 0), true)
	manager.set_process(false)
	manager._update_yell_scare_state()

	var second_zone_before: Vector3 = manager.zones[1]["center"]
	var second_yeller := _add_yelling_player(202, Vector3(0, 0, -12.0), true)
	manager._update_yell_scare_state()

	var second_zone_after: Vector3 = manager.zones[1]["center"]
	assert_ne(second_zone_after, second_zone_before, "New yeller's edge must scare its nearby zone")
	assert_gt(_flat_distance(second_yeller.global_position, second_zone_after), _flat_distance(second_yeller.global_position, second_zone_before))
	assert_false(manager.yell_scare_timer.is_stopped(), "Timer must keep running while anyone yells")


func test_get_debug_state_keys_and_types() -> void:
	var st = manager.get_debug_state()
	assert_true(st.has("zone_count"))
	assert_true(st.has("occupied_zones"))
	assert_true(st.has("total_occupants"))
	assert_true(st.has("reshuffle_timer_left"))
	assert_true(st.has("yell_scare_timer_left"))
	assert_eq(typeof(st["zone_count"]), TYPE_INT)
	assert_eq(typeof(st["occupied_zones"]), TYPE_INT)
	assert_eq(typeof(st["total_occupants"]), TYPE_INT)
	assert_eq(typeof(st["reshuffle_timer_left"]), TYPE_INT)
	assert_eq(typeof(st["yell_scare_timer_left"]), TYPE_INT)


func test_get_debug_actions_ids_and_labels() -> void:
	var acts = manager.get_debug_actions()
	assert_eq(acts.size(), 3)
	var map = {}
	for act in acts:
		map[act["id"]] = act["label"]
	assert_eq(map.get("reshuffle_zones"), "Reshuffle Zones")
	assert_eq(map.get("regen_zones"), "Regenerate Zones")
	assert_eq(map.get("clear_occupancy"), "Clear Occupancy")


func test_debug_actions_execution() -> void:
	manager.enter_zone(0, 101)
	assert_eq(manager.zone_occupant_counts[0], 1)
	manager.debug_action("clear_occupancy")
	assert_eq(manager.zone_occupant_counts[0], 0, "clear_occupancy should reset occupant counts")

	var before = manager.zones[1]["center"]
	manager.debug_action("reshuffle_zones")
	assert_ne(manager.zones[1]["center"], before, "reshuffle_zones should move unoccupied zone")


func test_debug_action_client_noop() -> void:
	manager.enter_zone(0, 101)
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", 1)
	manager.multiplayer.multiplayer_peer = peer
	manager.debug_action("clear_occupancy")
	assert_eq(manager.zone_occupant_counts[0], 1, "Client should no-op debug_action")
	manager.multiplayer.multiplayer_peer = null


func test_zone_manager_registers_with_debug_overlay() -> void:
	var dbg = get_node_or_null("/root/DebugOverlay")
	assert_not_null(dbg, "DebugOverlay autoload missing")
	assert_true(dbg._systems.has(manager.name), "ZoneManager should register with DebugOverlay")


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _add_mock_occupant(peer_id: int, state: int, owner_id: int) -> Node:
	var players := manager.get_parent().get_node_or_null("Players")
	if players == null:
		players = autofree(Node3D.new())
		players.name = "Players"
		manager.get_parent().add_child(players)
	var player := Node3D.new()
	player.name = "Player_%d" % peer_id
	players.add_child(player)
	var mechanic := Node3D.new()
	mechanic.name = "FishingMechanic"
	var mock_script := GDScript.new()
	mock_script.source_code = (
		"extends Node3D\n"
		+ "const BITE := 3\n"
		+ "signal reel_failure\n"
		+ "var current_state: int = %d\n"
		+ "func _get_owner_client_id() -> int:\n\treturn %d\n"
		+ "func on_fish_fled(target_client_id: int = -1) -> void:\n"
		+ "\tif target_client_id != -1 and target_client_id != _get_owner_client_id():\n\t\treturn\n"
		+ "\tif current_state != BITE:\n\t\treturn\n"
		+ "\treel_failure.emit()\n"
	) % [state, owner_id]
	mock_script.reload()
	mechanic.set_script(mock_script)
	player.add_child(mechanic)
	return mechanic


func _make_client_peer() -> MultiplayerPeer:
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", 1)
	return peer


func _add_yelling_player(peer_id: int, position: Vector3, is_yelling: bool) -> Node3D:
	var players := manager.get_parent().get_node_or_null("Players")
	if players == null:
		players = autofree(Node3D.new())
		players.name = "Players"
		manager.get_parent().add_child(players)
	var player := Node3D.new()
	player.name = "Player_%d" % peer_id
	player.position = position
	var yell_script := GDScript.new()
	yell_script.source_code = "extends Node3D\nvar is_yelling: bool = false\n"
	yell_script.reload()
	player.set_script(yell_script)
	player.is_yelling = is_yelling
	players.add_child(player)
	var mechanic := Node3D.new()
	mechanic.name = "FishingMechanic"
	player.add_child(mechanic)
	return player



