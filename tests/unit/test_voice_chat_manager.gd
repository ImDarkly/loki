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
