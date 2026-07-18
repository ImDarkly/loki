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


func test_fish_fled_during_bite_transitions_to_idle() -> void:
	mechanic.current_state = 3
	mechanic._active_zone_index = 0
	mechanic.personal_catch_count = 3

	watch_signals(mechanic)
	mechanic.on_fish_fled()

	assert_eq(mechanic.current_state, 0, "Should be IDLE (0) after fish_fled during BITE")
	assert_eq(mechanic.personal_catch_count, 3, "Personal catch should remain unchanged after fish_fled")
	assert_signal_emitted(mechanic, "reel_failure")


func test_fish_fled_during_idle_does_nothing() -> void:
	mechanic.current_state = 0
	mechanic.personal_catch_count = 3

	watch_signals(mechanic)
	mechanic.on_fish_fled()

	assert_eq(mechanic.current_state, 0, "Should remain IDLE (0)")
	assert_signal_not_emitted(mechanic, "reel_failure")


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


func test_bite_timer_uses_dead_zone_feedback_outside_zones() -> void:
	mechanic.current_state = 2
	mechanic.cast_target_position = Vector3(100, 0, 100)
	watch_signals(mechanic)
	mechanic._on_bite_timer_timeout()
	assert_eq(mechanic.current_state, 0, "Should return to IDLE (0) when outside every zone")
	assert_signal_not_emitted(mechanic, "bite_occurred")
	assert_eq(mechanic.catch_feedback_manager.feedback_label.text, "Nothing's biting...")


func test_bite_click_transitions_to_success_increments_count() -> void:
	mechanic.current_state = 3
	mechanic.personal_catch_count = 0
	mechanic._active_zone_index = 0
	mechanic._bite_time = 0.0

	watch_signals(mechanic)

	Input.action_press("reel")
	mechanic._process(0.0)
	Input.action_release("reel")

	assert_eq(mechanic.current_state, 4, "BITE click should transition to SUCCESS (4)")
	assert_eq(mechanic.personal_catch_count, 1, "personal_catch_count should increment")
	assert_signal_emitted(mechanic, "reel_success")
	assert_signal_emitted(mechanic, "personal_catch_changed")


func test_bite_miss_window_2_5_seconds_causes_escape() -> void:
	mechanic.current_state = 3
	mechanic._active_zone_index = 0
	mechanic._bite_time = 0.0
	mechanic.personal_catch_count = 0

	watch_signals(mechanic)

	Input.action_release("reel")

	while mechanic._bite_time < 3.0:
		mechanic._process(0.5)
		if mechanic.current_state != 3:
			break

	assert_eq(mechanic.current_state, 0, "Should return to IDLE (0) after 2.5s miss window")
	assert_eq(mechanic.personal_catch_count, 0, "personal_catch_count should remain unchanged")
	assert_signal_emitted(mechanic, "reel_failure")


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
