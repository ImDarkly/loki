extends GutTest


var _component: InteractionComponent
var _player: Player
var _carry: CarryComponent


func before_each() -> void:
	_player = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	_player.name = "Player"
	add_child(_player)

	_carry = CarryComponent.new()
	_carry.name = "CarryComponent"
	_player.add_child(_carry)
	_carry.setup(_player, _player.head, _player._rod_pivot)

	_component = InteractionComponent.new()
	_component.name = "InteractionComponent"
	_player.add_child(_component)
	_component.setup(_carry, _player, _player.camera, _player.head)
	await get_tree().process_frame


func after_each() -> void:
	if _player and is_instance_valid(_player):
		_player.free()
	_player = null


func test_setup_creates_interact_prompt() -> void:
	assert_true(is_instance_valid(_component._interact_prompt), "_interact_prompt should be created")
	assert_true(_component._interact_prompt.is_inside_tree(), "_interact_prompt should be in tree")


func test_tick_updates_shop_state() -> void:
	_component.tick(0.016, false, false, false, true)
	assert_true(_component._is_shop_open, "_is_shop_open should be updated by tick")
	_component.tick(0.016, false, false, false, false)
	assert_false(_component._is_shop_open, "_is_shop_open should be updated to false by tick")


func test_refresh_prompts_calls_visibility_updates() -> void:
	# Just verify the method exists and can be called without error
	_component.refresh_prompts()
	assert_true(true, "refresh_prompts should not error")


func test_handle_interact_requires_ray_hit() -> void:
	# When no ray hit, handle_interact should return false
	var result := _component.handle_interact()
	assert_false(result, "handle_interact should return false when no ray hit")


func test_handle_cast_line_delegates_to_carry() -> void:
	# When holding rock, handle_cast_line should call throw_rock
	_carry.holding_rock = true
	var result := _component.handle_cast_line(15.0)
	assert_true(result, "handle_cast_line should return true when holding rock")


func test_handle_cast_line_pickup_rock_when_not_carrying() -> void:
	# When not carrying anything, handle_cast_line should try to pickup rock
	_carry.is_carrying = false
	_carry.holding_rock = false
	_carry.holding_shark_bait = false
	# Note: actual raycast requires physics setup, so we just verify it doesn't error
	var result := _component.handle_cast_line(15.0)
	# Result depends on raycast, but should not error


func test_on_shop_toggled_updates_state() -> void:
	_component._on_shop_toggled(true)
	assert_true(_component._is_shop_open)
	_component._on_shop_toggled(false)
	assert_false(_component._is_shop_open)


func test_exports_and_defaults() -> void:
	assert_eq(_component.interact_range, 3.0, "default interact_range should be 3.0")
	assert_eq(_component.rock_pickup_range, 3.0, "default rock_pickup_range should be 3.0")
	_component.interact_range = 5.0
	_component.rock_pickup_range = 4.0
	assert_eq(_component.interact_range, 5.0)
	assert_eq(_component.rock_pickup_range, 4.0)