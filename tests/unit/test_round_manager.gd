extends GutTest

var manager: Node3D


func before_each() -> void:
	var scene: PackedScene = load("res://systems/round/round_manager.tscn")
	manager = autofree(scene.instantiate())
	add_child(manager)
	await get_tree().process_frame

	manager.timer.stop()
	manager.round_active = true


func test_win_when_quota_reaches_target() -> void:
	watch_signals(manager)
	manager._end_round(true)
	assert_signal_emitted(manager, "round_ended")
	assert_signal_emitted_with_parameters(manager, "round_ended", [true])


func test_fail_when_timer_expires() -> void:
	watch_signals(manager)
	manager._end_round(false)
	assert_signal_emitted(manager, "round_ended")
	assert_signal_emitted_with_parameters(manager, "round_ended", [false])


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
	if GDSync.is_host():
		assert_true(manager.round_active, "round_active should be true for host after ready")
	else:
		assert_false(manager.round_active, "round_active should be false for non-host")


func test_round_duration_has_default() -> void:
	assert_eq(manager.round_duration, 900.0, "Default round duration should be 900 seconds")


func test_quota_target_has_default() -> void:
	assert_eq(manager.quota_target, 20, "Default quota target should be 20")
