extends GutTest

var manager: Node3D

func before_each() -> void:
	var scene: PackedScene = load("res://systems/round/round_manager.tscn")
	manager = autofree(scene.instantiate())
	add_child(manager)
	await get_tree().process_frame

	manager.timer.stop()
	manager.round_active = true
	manager.fishing_active = true

func test_round_active_false_after_win() -> void:
	manager._end_round(true)
	assert_false(manager.round_active, "round_active should be false after win")

func test_round_active_false_after_fail() -> void:
	manager._end_round(false)
	assert_false(manager.round_active, "round_active should be false after fail")

func test_round_active_starts_true_when_host() -> void:
	manager = autofree(load("res://systems/round/round_manager.tscn").instantiate())
	add_child(manager)
	await get_tree().process_frame
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		assert_true(manager.round_active, "round_active should be true for host after ready")
	else:
		assert_false(manager.round_active, "round_active should be false for non-host")

func test_round_success_true_after_win() -> void:
	manager._end_round(true)
	assert_true(manager.round_success, "round_success should be true after win")

func test_round_success_false_after_fail() -> void:
	manager._end_round(false)
	assert_false(manager.round_success, "round_success should be false after fail")

func test_synced_state_emits_round_ended_on_transition() -> void:
	watch_signals(manager)
	manager._apply_synced_state(false, true)
	assert_signal_emitted(manager, "round_ended")
	assert_signal_emitted_with_parameters(manager, "round_ended", [true])

func test_synced_state_does_not_emit_on_no_transition() -> void:
	manager.round_active = false
	watch_signals(manager)
	manager._apply_synced_state(false, true)
	assert_signal_not_emitted(manager, "round_ended")

func test_synced_state_stores_success() -> void:
	manager._apply_synced_state(true, true)
	assert_true(manager.round_success)

func test_round_duration_has_default() -> void:
	assert_eq(manager.round_duration, 900.0, "Default round duration should be 900 seconds")

func test_apply_restart_sets_round_active_true() -> void:
	manager.round_active = false
	manager._apply_restart()
	assert_true(manager.round_active, "round_active should be true after apply_restart")

func test_apply_restart_sets_round_success_false() -> void:
	manager.round_success = true
	manager._apply_restart()
	assert_false(manager.round_success, "round_success should be false after apply_restart")

func test_apply_restart_resets_timer_stopped_on_client() -> void:
	manager.round_active = false
	manager.round_success = true
	manager._apply_restart()
	assert_true(manager.round_active)
	assert_false(manager.round_success)
	assert_true(manager.timer.is_stopped(), "timer should remain stopped on client after apply_restart")

func test_restart_round_resets_timer_and_active() -> void:
	manager._end_round(true)
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		manager.restart_round()
		assert_true(manager.round_active)
		assert_false(manager.timer.is_stopped(), "timer should be running after restart")
	else:
		assert_false(manager.round_active, "round_active should remain false for non-host")

func test_fishing_active_starts_true() -> void:
	assert_true(manager.fishing_active, "fishing_active should start true")

func test_timer_timeout_sets_fishing_active_false() -> void:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		manager._on_timer_timeout()
		assert_false(manager.fishing_active, "fishing_active should be false after timer timeout")

func test_timer_timeout_does_not_end_round() -> void:
	watch_signals(manager)
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		manager._on_timer_timeout()
		assert_true(manager.round_active, "round_active should remain true after timer timeout")
	assert_signal_not_emitted(manager, "round_ended")

func test_restart_round_sets_fishing_active_true() -> void:
	manager.fishing_active = false
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		manager.restart_round()
		assert_true(manager.fishing_active, "fishing_active should be true after restart")
	else:
		assert_false(manager.fishing_active, "fishing_active should remain false for non-host")

func test_apply_restart_sets_fishing_active_true() -> void:
	manager.fishing_active = false
	manager._apply_restart()
	assert_true(manager.fishing_active, "fishing_active should be true after apply_restart")

func test_synced_state_stores_fishing_active() -> void:
	manager._apply_synced_state(true, false, false)
	assert_false(manager.fishing_active, "fishing_active should match synced value")
