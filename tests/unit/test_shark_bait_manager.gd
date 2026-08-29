extends GutTest

class MockPlayer extends Node3D:
	var is_carrying: bool = false
	func _clear_carry() -> void:
		is_carrying = false

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


# --- Fill (BAIT-001 Decision 4) ---

func _create_mock_player(carrying: bool = false) -> Node3D:
	var players := _main.get_node_or_null("Players")
	if players == null:
		players = Node3D.new()
		players.name = "Players"
		_main.add_child(players)
	var p := MockPlayer.new()
	p.name = "MockPlayer"
	p.is_carrying = carrying
	autofree(p)
	players.add_child(p)
	if manager and manager.is_placed:
		p.global_position = manager.placed_position + Vector3(0.5, 0, 0)
	else:
		p.global_position = _water_position() + Vector3(0.5, 0, 0)
	return p


func _clear_mock_players() -> void:
	var players := _main.get_node_or_null("Players")
	if players:
		for c in players.get_children():
			c.queue_free()


func test_fill_cost_default_is_three() -> void:
	assert_eq(manager.fill_cost, 3, "fill_cost should default to 3")
	assert_eq(manager.bait_fill_count, 0, "initial fill should be 0")


func test_deposit_increments_when_carrying() -> void:
	manager._sync_placed(_water_position())
	var player := _create_mock_player(true)
	watch_signals(manager)
	manager.request_deposit_shark_bait()
	assert_eq(manager.bait_fill_count, 1, "Should increment to 1 when carrying")
	assert_false(player.is_carrying, "Should clear carry after deposit")
	assert_signal_emitted(manager, "bait_fill_updated")


func test_deposit_rejected_without_carrying() -> void:
	manager._sync_placed(_water_position())
	_create_mock_player(false)
	manager.request_deposit_shark_bait()
	assert_eq(manager.bait_fill_count, 0, "Should stay 0 when not carrying")


func test_deposit_capped_at_fill_cost() -> void:
	manager._sync_placed(_water_position())
	for i in 3:
		var p := _create_mock_player(true)
		manager.request_deposit_shark_bait()
		_clear_mock_players()
		await get_tree().process_frame
	assert_eq(manager.bait_fill_count, 3, "Should cap at fill_cost=3 after 3 deposits")
	var extra_player := _create_mock_player(true)
	manager.request_deposit_shark_bait()
	assert_eq(manager.bait_fill_count, 3, "Should stay at cap when already full")
	assert_true(extra_player.is_carrying, "Should NOT clear carry when rejected at cap")


func test_partial_values_replicate_via_sync() -> void:
	watch_signals(manager)
	manager._sync_fill(1)
	assert_eq(manager.bait_fill_count, 1)
	assert_signal_emit_count(manager, "bait_fill_updated", 1)
	manager._sync_fill(2)
	assert_eq(manager.bait_fill_count, 2)
	assert_signal_emit_count(manager, "bait_fill_updated", 2)
	manager._sync_fill(0)
	assert_eq(manager.bait_fill_count, 0)


func test_deposit_rejected_when_not_placed() -> void:
	assert_false(manager.is_placed)
	_create_mock_player(true)
	manager.request_deposit_shark_bait()
	assert_eq(manager.bait_fill_count, 0, "Should not fill when not yet placed")


func test_sync_fill_clamps_beyond_cost() -> void:
	manager._sync_fill(99)
	assert_eq(manager.bait_fill_count, manager.fill_cost, "Should clamp to fill_cost")
	manager._sync_fill(-5)
	assert_eq(manager.bait_fill_count, 0, "Should clamp to 0")


func test_reset_for_restart_clears_fill() -> void:
	manager._sync_placed(_water_position())
	manager._sync_fill(2)
	assert_eq(manager.bait_fill_count, 2)
	manager.reset_for_restart()
	assert_eq(manager.bait_fill_count, 0, "reset_for_restart should clear fill")
