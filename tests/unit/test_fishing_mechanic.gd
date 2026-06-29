extends GutTest

var mechanic: Node3D


func before_each() -> void:
	var scene = load("res://systems/fishing/fishing_mechanic.tscn")
	mechanic = autofree(scene.instantiate())
	add_child(mechanic)
	await get_tree().process_frame


func test_reel_success_when_bar_in_zone() -> void:
	mechanic._enter_reeling()
	mechanic.reel_timer.stop()
	mechanic.reel_meter.size = Vector2(40, 300)
	mechanic.player_bar_position = 40.0
	mechanic.green_zone_position = 30.0
	mechanic.quota = 0
	mechanic._on_reel_timer_timeout()
	assert_eq(mechanic.quota, 1)
	assert_eq(mechanic.current_state, 5, "Should be SUCCESS (5)")


func test_success_feedback_transitions_to_idle() -> void:
	mechanic._enter_reeling()
	mechanic.reel_timer.stop()
	mechanic.reel_meter.size = Vector2(40, 300)
	mechanic.player_bar_position = 40.0
	mechanic.green_zone_position = 30.0
	mechanic.quota = 0
	mechanic._on_reel_timer_timeout()
	assert_eq(mechanic.current_state, 5, "Should be SUCCESS (5) after reel timeout")
	mechanic._on_catch_feedback_completed()
	assert_eq(mechanic.current_state, 0, "Should be IDLE (0) after feedback completes")


func test_fish_fled_during_reeling_transitions_to_idle() -> void:
	mechanic._enter_reeling()
	mechanic.reel_timer.stop()
	mechanic.reel_meter.size = Vector2(40, 300)
	mechanic.player_bar_position = 50.0
	mechanic.green_zone_position = 50.0
	mechanic.quota = 3

	watch_signals(mechanic)
	mechanic.on_fish_fled()

	assert_eq(mechanic.current_state, 0, "Should be IDLE (0) after fish_fled")
	assert_eq(mechanic.quota, 3, "Quota should remain unchanged after fish_fled")
	assert_signal_emitted(mechanic, "reel_failure")


func test_fish_fled_during_idle_does_nothing() -> void:
	mechanic.current_state = 0
	mechanic.quota = 3

	watch_signals(mechanic)
	mechanic.on_fish_fled()

	assert_eq(mechanic.current_state, 0, "Should remain IDLE (0)")
	assert_signal_not_emitted(mechanic, "reel_failure")


func test_reel_failure_when_bar_outside_zone() -> void:
	mechanic._enter_reeling()
	mechanic.reel_timer.stop()
	mechanic.reel_meter.size = Vector2(40, 300)
	mechanic.player_bar_position = 90.0
	mechanic.green_zone_position = 30.0
	mechanic.quota = 0
	mechanic._on_reel_timer_timeout()
	assert_eq(mechanic.quota, 0)
	assert_eq(mechanic.current_state, 0, "Should be IDLE (0) after reel failure")
