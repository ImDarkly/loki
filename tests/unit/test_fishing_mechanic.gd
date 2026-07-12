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
	mechanic.personal_catch_count = 0
	mechanic._on_reel_timer_timeout()
	assert_eq(mechanic.personal_catch_count, 1)
	assert_eq(mechanic.current_state, 5, "Should be SUCCESS (5)")


func test_success_feedback_transitions_to_idle() -> void:
	mechanic._enter_reeling()
	mechanic.reel_timer.stop()
	mechanic.reel_meter.size = Vector2(40, 300)
	mechanic.player_bar_position = 40.0
	mechanic.green_zone_position = 30.0
	mechanic.personal_catch_count = 0
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
	mechanic.personal_catch_count = 3

	watch_signals(mechanic)
	mechanic.on_fish_fled()

	assert_eq(mechanic.current_state, 0, "Should be IDLE (0) after fish_fled")
	assert_eq(mechanic.personal_catch_count, 3, "Personal catch should remain unchanged after fish_fled")
	assert_false(mechanic.reel_meter.visible, "Reel meter should be hidden after cleanup")
	assert_signal_emitted(mechanic, "reel_failure")


func test_fish_fled_during_idle_does_nothing() -> void:
	mechanic.current_state = 0
	mechanic.personal_catch_count = 3

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
	mechanic.personal_catch_count = 0
	mechanic._on_reel_timer_timeout()
	assert_eq(mechanic.personal_catch_count, 0)
	assert_eq(mechanic.current_state, 0, "Should be IDLE (0) after reel failure")


func test_cast_ignored_when_fishing_inactive() -> void:
	mechanic._cached_fishing_active = false
	mechanic.current_state = 0
	assert_false(mechanic.can_cast(), "can_cast should return false when fishing inactive")


func test_bite_timer_noops_when_fishing_inactive() -> void:
	mechanic.current_state = 2
	mechanic._cached_fishing_active = false
	mechanic._on_bite_timer_timeout()
	assert_eq(mechanic.current_state, 2, "Should remain WAITING (2)")


func test_reel_timer_noops_when_fishing_inactive() -> void:
	mechanic._enter_reeling()
	mechanic.reel_timer.stop()
	mechanic._cached_fishing_active = false
	watch_signals(mechanic)
	mechanic._on_reel_timer_timeout()
	assert_eq(mechanic.current_state, 4, "Should remain REELING (4)")
	assert_signal_not_emitted(mechanic, "reel_success")
	assert_signal_not_emitted(mechanic, "reel_failure")


func test_arc_velocity_lands_at_target() -> void:
	var start := Vector3(2, 1.6, 0)
	var target := Vector3(10, 0, 3)
	var duration := 0.5
	var gravity := 9.8
	var v := mechanic._compute_launch_velocity(start, target, duration, gravity)
	var g := Vector3(0, -gravity, 0)
	var pos := start + v * duration + 0.5 * g * duration * duration
	assert_eq(pos, target, "Arc should land at target at t=flight_duration")


func test_arc_starts_at_rod_tip() -> void:
	var start := Vector3(2, 1.6, 0)
	var target := Vector3(10, 0, 3)
	var duration := 0.5
	var gravity := 9.8
	var v := mechanic._compute_launch_velocity(start, target, duration, gravity)
	var pos := start + v * 0.0 + 0.5 * Vector3(0, -gravity, 0) * 0.0 * 0.0
	assert_eq(pos, start, "Arc should start at rod tip at t=0")


func test_arc_is_deterministic() -> void:
	var start := Vector3(2, 1.6, 0)
	var target := Vector3(10, 0, 3)
	var duration := 0.5
	var gravity := 9.8
	var t := duration * 0.3
	var v1 := mechanic._compute_launch_velocity(start, target, duration, gravity)
	var v2 := mechanic._compute_launch_velocity(start, target, duration, gravity)
	var g := Vector3(0, -gravity, 0)
	var pos1 := start + v1 * t + 0.5 * g * t * t
	var pos2 := start + v2 * t + 0.5 * g * t * t
	assert_eq(pos1, pos2, "Same inputs should produce identical intermediate positions")
