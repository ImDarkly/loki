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
