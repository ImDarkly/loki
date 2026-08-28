extends GutTest

var manager: Node3D
var coin_manager: Node3D
var _main: Node3D


func before_each() -> void:
	_main = Node3D.new()
	_main.name = "main"
	get_node("/root").add_child(_main)

	coin_manager = load("res://systems/quota/coin_manager.tscn").instantiate()
	coin_manager.name = "CoinManager"
	_main.add_child(coin_manager)

	manager = autofree(load("res://systems/shark_bait/shark_bait_manager.tscn").instantiate())
	add_child(manager)
	await get_tree().process_frame


func after_each() -> void:
	if _main and is_instance_valid(_main):
		_main.queue_free()
		await get_tree().process_frame
	_main = null


func _water_position() -> Vector3:
	return MapConfig.MAP_CENTER + Vector3(MapConfig.ISLAND_RADIUS + 5.0, 0, 0)


func _inside_position() -> Vector3:
	return MapConfig.MAP_CENTER + Vector3(MapConfig.ISLAND_RADIUS - 0.5, 0, 0)


func test_place_rejected_without_ownership() -> void:
	coin_manager.shark_bait_owned = false
	manager.request_place_shark_bait(_water_position())
	assert_false(manager.is_placed, "Should not place without ownership")


func test_place_rejected_inside_island() -> void:
	coin_manager.shark_bait_owned = true
	manager.request_place_shark_bait(_inside_position())
	assert_false(manager.is_placed, "Should reject position inside ISLAND_RADIUS")

	manager.request_place_shark_bait(MapConfig.MAP_CENTER)
	assert_false(manager.is_placed, "Center of island should be rejected")

	manager.request_place_shark_bait(MapConfig.MAP_CENTER + Vector3(MapConfig.ISLAND_RADIUS, 0, 0))
	assert_false(manager.is_placed, "Exactly at ISLAND_RADIUS should be rejected (boundary inclusive)")


func test_place_accepted_in_water() -> void:
	coin_manager.shark_bait_owned = true
	var water := _water_position()
	manager.request_place_shark_bait(water)
	assert_true(manager.is_placed, "Water position outside ISLAND_RADIUS should be accepted")
	assert_eq(manager.placed_position, Vector3(water.x, 0, water.z))


func test_place_rejected_when_already_placed() -> void:
	coin_manager.shark_bait_owned = true
	var first := _water_position()
	var second := MapConfig.MAP_CENTER + Vector3(MapConfig.ISLAND_RADIUS + 8.0, 0, 0)
	manager.request_place_shark_bait(first)
	assert_true(manager.is_placed)
	var first_stored: Vector3 = manager.placed_position
	manager.request_place_shark_bait(second)
	assert_eq(manager.placed_position, first_stored, "Second placement should be ignored when already placed")
	assert_eq(manager.is_placed, true)


func test_sync_placed_creates_visible_bait() -> void:
	var water := _water_position()
	manager._sync_placed(water)
	assert_true(manager.is_placed, "_sync_placed should mark as placed")
	assert_eq(manager.placed_position, water)
	assert_true(is_instance_valid(manager._bait_instance), "Bait instance should be created on sync")
	assert_eq(manager._bait_instance.global_position, water)


func test_request_place_emits_signal_and_syncs() -> void:
	coin_manager.shark_bait_owned = true
	watch_signals(manager)
	var water := _water_position()
	manager.request_place_shark_bait(water)
	assert_signal_emitted(manager, "shark_bait_placed")
	assert_true(is_instance_valid(manager._bait_instance))


func test_height_does_not_affect_island_check() -> void:
	coin_manager.shark_bait_owned = true
	var raised_inside := MapConfig.MAP_CENTER + Vector3(MapConfig.ISLAND_RADIUS - 0.5, 10.0, 0)
	manager.request_place_shark_bait(raised_inside)
	assert_false(manager.is_placed, "Y should be ignored — XZ inside island still rejected")

	var raised_water := MapConfig.MAP_CENTER + Vector3(MapConfig.ISLAND_RADIUS + 5.0, 10.0, 0)
	manager.request_place_shark_bait(raised_water)
	assert_true(manager.is_placed, "Y should be ignored — XZ outside island should be accepted")


func test_cannot_place_before_purchase_gated_on_shark_bait_owned() -> void:
	coin_manager.shark_bait_owned = false
	manager.request_place_shark_bait(_water_position())
	assert_false(manager.is_placed)
	coin_manager.shark_bait_owned = true
	manager.request_place_shark_bait(_water_position())
	assert_true(manager.is_placed)


func test_reset_for_restart_clears_placement() -> void:
	coin_manager.shark_bait_owned = true
	manager.request_place_shark_bait(_water_position())
	assert_true(manager.is_placed)
	manager.reset_for_restart()
	assert_false(manager.is_placed)
	assert_eq(manager.placed_position, Vector3.ZERO)
	assert_false(is_instance_valid(manager._bait_instance))


func test_shark_bait_entity_is_static_body_with_interactable() -> void:
	var bait = load("res://entities/shark_bait.tscn").instantiate()
	add_child_autofree(bait)
	assert_true(bait is StaticBody3D, "SharkBait should be StaticBody3D")
	assert_not_null(bait.get_node_or_null("InteractableComponent"), "Should have InteractableComponent")
	assert_eq(bait.collision_layer, 32, "Should be on interactable layer 32")
