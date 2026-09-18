extends GutTest


var _component: CarryComponent
var _player: Player


func before_each() -> void:
	_player = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	_player.name = "Player"
	add_child(_player)

	_component = CarryComponent.new()
	_component.name = "CarryComponent"
	_player.add_child(_component)
	_component.setup(_player, _player.head, _player._rod_pivot)
	await get_tree().process_frame


func after_each() -> void:
	if _player and is_instance_valid(_player):
		_player.free()
	_player = null


func test_start_carrying_sets_state() -> void:
	assert_false(_component.is_carrying, "is_carrying should start false")
	_component.start_carrying()
	assert_true(_component.is_carrying, "is_carrying should be true after start_carrying")


func test_clear_carry_resets_state() -> void:
	_component.start_carrying()
	assert_true(_component.is_carrying)
	_component._clear_carry()
	assert_false(_component.is_carrying, "_clear_carry should reset is_carrying to false")


func test_deposit_carried_fish_requires_carrying() -> void:
	assert_false(_component.is_carrying)
	_component.deposit_carried_fish()
	assert_false(_component.is_carrying, "deposit_carried_fish should not change state when not carrying")


func test_start_holding_shark_bait_sets_state() -> void:
	assert_false(_component.holding_shark_bait, "holding_shark_bait should start false")
	_component.start_holding_shark_bait()
	assert_true(_component.holding_shark_bait, "holding_shark_bait should be true after start_holding_shark_bait")


func test_clear_holding_shark_bait_resets_state() -> void:
	_component.start_holding_shark_bait()
	assert_true(_component.holding_shark_bait)
	_component.clear_holding_shark_bait()
	assert_false(_component.holding_shark_bait, "clear_holding_shark_bait should reset holding_shark_bait to false")


func test_try_pickup_rock_requires_not_carrying() -> void:
	_component.start_carrying()
	var result := _component.try_pickup_rock()
	assert_false(result, "try_pickup_rock should return false when carrying")
	
	_component._clear_carry()
	_component.start_holding_shark_bait()
	result = _component.try_pickup_rock()
	assert_false(result, "try_pickup_rock should return false when holding shark bait")
	
	_component.clear_holding_shark_bait()
	_component.holding_rock = true
	result = _component.try_pickup_rock()
	assert_false(result, "try_pickup_rock should return false when already holding rock")


func test_try_place_shark_bait_requires_holding() -> void:
	assert_false(_component.holding_shark_bait)
	_component._try_place_shark_bait()
	assert_false(_component.holding_shark_bait, "_try_place_shark_bait should not change state when not holding bait")


func test_throw_rock_clears_holding_rock() -> void:
	_component.holding_rock = true
	_component._show_held_rock_remote()
	assert_true(_component.holding_rock)
	_component.throw_rock(15.0)
	assert_false(_component.holding_rock, "throw_rock should clear holding_rock")


func test_rpc_sync_carrying() -> void:
	# Test that the RPC method exists and can be called
	assert_true(_component.has_method("sync_carrying"), "sync_carrying RPC should exist")


func test_rpc_sync_holding_rock() -> void:
	assert_true(_component.has_method("sync_holding_rock"), "sync_holding_rock RPC should exist")


func test_rpc_sync_holding_bait() -> void:
	assert_true(_component.has_method("sync_holding_bait"), "sync_holding_bait RPC should exist")


func test_rod_visibility_updated_on_carry() -> void:
	if _player._rod_pivot:
		assert_true(_player._rod_pivot.visible, "rod should be visible when not carrying")
	_component.start_carrying()
	await get_tree().process_frame
	if _player._rod_pivot:
		assert_false(_player._rod_pivot.visible, "rod should be hidden when carrying")
	_component._clear_carry()
	await get_tree().process_frame
	if _player._rod_pivot:
		assert_true(_player._rod_pivot.visible, "rod should be visible again after clearing carry")


func test_rod_visibility_updated_on_holding_rock() -> void:
	if _player._rod_pivot:
		assert_true(_player._rod_pivot.visible)
	_component.holding_rock = true
	_component._show_held_rock_remote()
	await get_tree().process_frame
	if _player._rod_pivot:
		assert_false(_player._rod_pivot.visible, "rod should be hidden when holding rock")
	_component.holding_rock = false
	_component._hide_held_rock_remote()
	await get_tree().process_frame
	if _player._rod_pivot:
		assert_true(_player._rod_pivot.visible)


func test_rod_visibility_updated_on_holding_bait() -> void:
	if _player._rod_pivot:
		assert_true(_player._rod_pivot.visible)
	_component.start_holding_shark_bait()
	await get_tree().process_frame
	if _player._rod_pivot:
		assert_false(_player._rod_pivot.visible, "rod should be hidden when holding shark bait")
	_component.clear_holding_shark_bait()
	await get_tree().process_frame
	if _player._rod_pivot:
		assert_true(_player._rod_pivot.visible)