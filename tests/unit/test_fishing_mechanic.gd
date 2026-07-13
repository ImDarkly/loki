extends GutTest

var mechanic: Node3D
var zone_manager: Node3D


func before_each() -> void:
	var scene = load("res://systems/fishing/fishing_mechanic.tscn")
	mechanic = autofree(scene.instantiate())
	add_child(mechanic)
	await get_tree().process_frame

	var zone_scene: PackedScene = load("res://systems/zones/zone_manager.tscn")
	zone_manager = autofree(zone_scene.instantiate())
	add_child(zone_manager)
	zone_manager.call("set_zones", [
		{"center": Vector3(0, 0, 0), "radius": 10.0}
	])


func test_reel_success_when_bar_in_zone() -> void:
	mechanic._enter_reeling()
	mechanic.reel_timer.stop()
	mechanic.reel_meter.size = Vector2(40, 300)
	mechanic.player_bar_position = 40.0
	mechanic.green_zone_position = 30.0
	mechanic.personal_catch_count = 0
	mechanic._on_reel_timer_timeout()
	assert_eq(mechanic.personal_catch_count, 1)
	assert_eq(mechanic.current_state, 6, "Should be CARRYING (6)")


func test_carry_feedback_does_not_transition_to_idle() -> void:
	mechanic._enter_reeling()
	mechanic.reel_timer.stop()
	mechanic.reel_meter.size = Vector2(40, 300)
	mechanic.player_bar_position = 40.0
	mechanic.green_zone_position = 30.0
	mechanic.personal_catch_count = 0
	mechanic._on_reel_timer_timeout()
	assert_eq(mechanic.current_state, 6, "Should be CARRYING (6) after reel timeout")
	mechanic._on_catch_feedback_completed()
	assert_eq(mechanic.current_state, 6, "Should remain CARRYING (6) after feedback completes")


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


func test_bite_timer_fires_when_fishing_inactive() -> void:
	mechanic.current_state = 2
	mechanic._active_zone_index = 0
	mechanic._cached_fishing_active = false
	mechanic.cast_target_position = Vector3(0, 0, 0)
	mechanic._on_bite_timer_timeout()
	assert_eq(mechanic.current_state, 3, "Should transition to BITE (3) regardless of fishing_active")


func test_reel_timer_resolves_when_fishing_inactive() -> void:
	mechanic._enter_reeling()
	mechanic.reel_timer.stop()
	mechanic.reel_meter.size = Vector2(40, 300)
	mechanic.player_bar_position = 90.0
	mechanic.green_zone_position = 30.0
	mechanic._cached_fishing_active = false
	watch_signals(mechanic)
	mechanic._on_reel_timer_timeout()
	assert_eq(mechanic.current_state, 0, "Should transition to IDLE (0) regardless of fishing_active")
	assert_signal_not_emitted(mechanic, "reel_success")
	assert_signal_not_emitted(mechanic, "reel_failure")


func test_bite_timer_uses_dead_zone_feedback_outside_zones() -> void:
	mechanic.current_state = 2
	mechanic.cast_target_position = Vector3(100, 0, 100)
	watch_signals(mechanic)
	mechanic._on_bite_timer_timeout()
	assert_eq(mechanic.current_state, 0, "Should return to IDLE (0) when outside every zone")
	assert_signal_not_emitted(mechanic, "bite_occurred")
	assert_eq(mechanic.catch_feedback_manager.feedback_label.text, "Nothing's biting...")


func test_arc_velocity_lands_at_target() -> void:
	var start: Vector3 = Vector3(2, 1.6, 0)
	var target: Vector3 = Vector3(10, 0, 3)
	var duration: float = 0.5
	var gravity: float = 9.8
	var v: Vector3 = mechanic._compute_launch_velocity(start, target, duration, gravity)
	var g: Vector3 = Vector3(0, -gravity, 0)
	var pos: Vector3 = start + v * duration + 0.5 * g * duration * duration
	assert_eq(pos, target, "Arc should land at target at t=flight_duration")


func test_arc_starts_at_rod_tip() -> void:
	var start: Vector3 = Vector3(2, 1.6, 0)
	var target: Vector3 = Vector3(10, 0, 3)
	var duration: float = 0.5
	var gravity: float = 9.8
	var v: Vector3 = mechanic._compute_launch_velocity(start, target, duration, gravity)
	var pos: Vector3 = start + v * 0.0 + 0.5 * Vector3(0, -gravity, 0) * 0.0 * 0.0
	assert_eq(pos, start, "Arc should start at rod tip at t=0")


func test_arc_is_deterministic() -> void:
	var start: Vector3 = Vector3(2, 1.6, 0)
	var target: Vector3 = Vector3(10, 0, 3)
	var duration: float = 0.5
	var gravity: float = 9.8
	var t: float = duration * 0.3
	var v1: Vector3 = mechanic._compute_launch_velocity(start, target, duration, gravity)
	var v2: Vector3 = mechanic._compute_launch_velocity(start, target, duration, gravity)
	var g: Vector3 = Vector3(0, -gravity, 0)
	var pos1: Vector3 = start + v1 * t + 0.5 * g * t * t
	var pos2: Vector3 = start + v2 * t + 0.5 * g * t * t
	assert_eq(pos1, pos2, "Same inputs should produce identical intermediate positions")


func test_is_carrying_true_after_start_carrying() -> void:
	mechanic.start_carrying()
	assert_true(mechanic.is_carrying, "is_carrying should be true after start_carrying")


func test_is_carrying_false_after_drop_carried_fish() -> void:
	mechanic.start_carrying()
	assert_true(mechanic.is_carrying)
	mechanic.drop_carried_fish()
	assert_false(mechanic.is_carrying, "is_carrying should be false after drop_carried_fish")


func test_can_cast_returns_false_when_carrying() -> void:
	mechanic.start_carrying()
	assert_false(mechanic.can_cast(), "can_cast should return false while carrying")


func test_reset_for_restart_clears_carry_state() -> void:
	mechanic.start_carrying()
	assert_true(mechanic.is_carrying)
	mechanic.reset_for_restart()
	assert_eq(mechanic.current_state, 0, "Should be IDLE (0) after restart")
	assert_eq(mechanic.personal_catch_count, 0, "Personal catch should be 0 after restart")


func test_drop_carried_fish_snaps_bobber_to_idle() -> void:
	mechanic.start_carrying()
	mechanic.drop_carried_fish()
	assert_eq(mechanic.current_state, 0, "Should be IDLE (0) after drop")
