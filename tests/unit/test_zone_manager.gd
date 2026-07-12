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
