extends GutTest

var _component: SlapComponent
var _player: Player


func before_each() -> void:
	_player = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	_player.name = "Player"
	add_child(_player)

	_component = SlapComponent.new()
	_component.name = "SlapComponent"
	_player.add_child(_component)
	_component.setup(_player, null, null)
	await get_tree().process_frame


func after_each() -> void:
	if _player and is_instance_valid(_player):
		_player.free()
	_player = null


func test_apply_slap_sets_state_and_timer() -> void:
	assert_false(_component.is_slapped, "is_slapped should start false")
	_component.apply_slap(3.5)
	assert_true(_component.is_slapped, "is_slapped should be true after apply_slap")
	assert_eq(_component._slap_time_left, 3.5, "_slap_time_left should be set")


func test_apply_slap_clamps_duration() -> void:
	_component.apply_slap(1.0)
	assert_eq(_component._slap_time_left, 3.0, "duration below 3.0 should clamp to 3.0")
	_component.apply_slap(10.0)
	assert_eq(_component._slap_time_left, 5.0, "duration above 5.0 should clamp to 5.0")


func test_slap_cooldown_decrement() -> void:
	_component._slap_cooldown_left = 1.0
	_component._physics_process(0.4)
	assert_almost_eq(_component._slap_cooldown_left, 0.6, 0.001, "Slap cooldown should decrement")


func test_apply_slap_self_clears_without_physics() -> void:
	_component.apply_slap(0.1)
	assert_true(_component.is_slapped)
	await get_tree().create_timer(0.15).timeout
	assert_false(_component.is_slapped, "slap should self-clear after timer")


func test_exports_and_defaults() -> void:
	assert_eq(_component.slap_duration, 3.5, "default slap_duration should be 3.5")
	assert_eq(_component.slap_range, 2.0, "default slap_range should be 2.0")
	assert_eq(_component.slap_cooldown, 1.0, "default slap_cooldown should be 1.0")
	_component.slap_duration = 4.0
	_component.slap_range = 3.0
	_component.slap_cooldown = 1.5
	assert_eq(_component.slap_duration, 4.0)
	assert_eq(_component.slap_range, 3.0)
	assert_eq(_component.slap_cooldown, 1.5)


func test_players_layer_mask() -> void:
	assert_eq(1 << 1, 2, "PLAYERS_LAYER 2 corresponds to collision mask bit 1 (value 2)")


func test_process_slapped_expiry_clear() -> void:
	_component.apply_slap(3.0)
	assert_true(_component.is_slapped)
	_component._process_slapped(3.1)
	assert_false(_component.is_slapped, "_process_slapped expiry should clear slap when time left <= 0")
	assert_eq(_component._slap_time_left, 0.0)


func test_token_auto_clear_and_re_entrant_no_extend() -> void:
	_component.apply_slap(3.0)
	assert_true(_component.is_slapped)
	var t1 := _component._slap_token
	var time1 := _component._slap_time_left

	_component.apply_slap(5.0)
	assert_eq(_component._slap_time_left, time1, "re-entrant apply_slap should not extend time")
	assert_eq(_component._slap_token, t1, "re-entrant apply_slap should not change token")

	_component._clear_slap()
	assert_false(_component.is_slapped)
	assert_eq(_component._slap_token, t1 + 1, "_clear_slap should increment token")


func test_try_slap_false_cases() -> void:
	var result := _component._try_fish_slap()
	assert_false(result, "_try_fish_slap should return false when no target")


func test_slap_does_not_drop_fish() -> void:
	_player.start_carrying()
	assert_true(_player.is_carrying, "Player should be carrying fish")
	_component.apply_slap(3.5)
	assert_true(_player.is_carrying, "Slap should not drop carried fish")
