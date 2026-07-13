extends GutTest

var manager: Node3D


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
	var before := manager.zones[0]["center"]
	manager._reshuffle_unoccupied_zones()
	assert_eq(manager.zones[0]["center"], before)


func test_unoccupied_zone_is_eligible_during_reshuffle() -> void:
	var before := manager.zones[1]["center"]
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
