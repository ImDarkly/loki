extends GutTest

const TEST_BUS_NAME := "VoiceChatRecordingBus"

var manager: Node


func before_each() -> void:
	_cleanup_test_bus()
	var scene := load("res://systems/voice_chat/voice_chat_manager.tscn")
	manager = autofree(scene.instantiate())
	add_child(manager)


func after_each() -> void:
	_cleanup_test_bus()


func _cleanup_test_bus() -> void:
	var idx := AudioServer.get_bus_index(TEST_BUS_NAME)
	if idx != -1:
		AudioServer.remove_bus(idx)


func _create_test_bus() -> void:
	var idx := AudioServer.get_bus_index(TEST_BUS_NAME)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, TEST_BUS_NAME)


func test_bus_not_found_logs_warning_once() -> void:
	await get_tree().process_frame
	assert_eq(manager._bus_error_logged, true, "Warning flag should be set after first _process")
	assert_eq(manager._bus_index, -1, "_bus_index should remain -1 when bus not found")


func test_bus_not_found_no_crash() -> void:
	for i in 5:
		await get_tree().process_frame
	assert_true(true, "Manager survived multiple frames without the bus")


func test_bus_found_on_first_process() -> void:
	_create_test_bus()
	await get_tree().process_frame
	assert_ne(manager._bus_index, -1, "_bus_index should be set after bus is found")
	assert_false(manager._bus_error_logged, "No warning should be logged when bus exists")


func test_bus_index_cached_after_first_lookup() -> void:
	_create_test_bus()
	await get_tree().process_frame
	var cached: int = manager._bus_index
	assert_ne(cached, -1, "Bus should be found initially")

	_cleanup_test_bus()
	await get_tree().process_frame
	assert_eq(manager._bus_index, cached, "_bus_index should remain cached after bus is removed")


func test_bus_created_later_found_on_retry() -> void:
	await get_tree().process_frame
	assert_eq(manager._bus_index, -1, "Bus should not be found initially")
	assert_true(manager._bus_error_logged, "Warning should be logged on first miss")

	_create_test_bus()
	await get_tree().process_frame
	assert_ne(manager._bus_index, -1, "Bus should be found on retry after creation")


func test_amplitude_above_on_threshold_activates_yelling() -> void:
	watch_signals(manager)
	manager._update_yelling_state(-11.0)
	assert_true(manager.is_yelling, "is_yelling should be true when amplitude exceeds ON threshold")
	assert_signal_emitted(manager, "yelling_state_changed", "Signal should fire on activation")


func test_amplitude_below_off_threshold_deactivates_yelling() -> void:
	manager._update_yelling_state(-11.0)
	watch_signals(manager)
	manager._update_yelling_state(-15.0)
	assert_false(manager.is_yelling, "is_yelling should be false when amplitude drops below OFF threshold")
	assert_signal_emitted(manager, "yelling_state_changed", "Signal should fire on deactivation")


func test_hysteresis_deadband_from_false() -> void:
	watch_signals(manager)
	manager._update_yelling_state(-13.0)
	assert_false(manager.is_yelling, "is_yelling should remain false in deadband")
	assert_signal_not_emitted(manager, "yelling_state_changed", "Signal should not fire in deadband when starting false")


func test_hysteresis_deadband_from_true() -> void:
	manager._update_yelling_state(-11.0)
	watch_signals(manager)
	manager._update_yelling_state(-13.0)
	assert_true(manager.is_yelling, "is_yelling should remain true in deadband")
	assert_signal_not_emitted(manager, "yelling_state_changed", "Signal should not fire in deadband when starting true")


func test_signal_guard_no_duplicate() -> void:
	watch_signals(manager)
	manager._update_yelling_state(-11.0)
	manager._update_yelling_state(-11.0)
	assert_signal_emit_count(manager, "yelling_state_changed", 1, "Signal should emit only once per transition")


func test_signal_emits_on_each_transition() -> void:
	watch_signals(manager)
	manager._update_yelling_state(-11.0)
	manager._update_yelling_state(-15.0)
	manager._update_yelling_state(-11.0)
	assert_signal_emit_count(manager, "yelling_state_changed", 3, "Signal should fire on each transition (true, false, true)")


func test_threshold_exports_apply() -> void:
	manager.amplitude_threshold_on = -20.0
	manager.amplitude_threshold_off = -25.0
	watch_signals(manager)

	manager._update_yelling_state(-22.0)
	assert_false(manager.is_yelling, "is_yelling should remain false with custom ON threshold at -20")
	assert_signal_not_emitted(manager, "yelling_state_changed", "Signal should not fire in custom deadband")

	manager._update_yelling_state(-19.0)
	assert_true(manager.is_yelling, "is_yelling should become true with custom ON threshold")
	assert_signal_emitted(manager, "yelling_state_changed", "Signal should fire with custom threshold")
