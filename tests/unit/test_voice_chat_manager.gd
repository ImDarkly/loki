extends GutTest

var manager


func before_each() -> void:
	var scene: PackedScene = load("res://systems/voice_chat/voice_chat_manager.tscn")
	manager = autofree(scene.instantiate())
	add_child(manager)
	await get_tree().process_frame


func test_bus_created_and_queryable() -> void:
	var idx := AudioServer.get_bus_index("VoiceChatRecord")
	assert_ne(idx, -1, "Bus VoiceChatRecord should exist after manager loads")
	var peak: float = AudioServer.get_bus_peak_volume_left_db(idx, 0)
	assert_lt(peak, -60, "Peak should be near noise floor with no audio playing")


func test_get_peak_volume_db_returns_float() -> void:
	var peak: float = manager.get_peak_volume_db()
	assert_lt(peak, -60, "get_peak_volume_db should return a low value when silent")


func test_synthetic_amplitude_minus_20_db() -> void:
	manager.inject_synthetic_amplitude(-20.0)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var peak: float = manager.get_peak_volume_db()
	assert_gt(peak, -35.0, "Peak at -20 dB injection should be above -35 dB")


func test_synthetic_amplitude_minus_12_db() -> void:
	manager.inject_synthetic_amplitude(-12.0)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var peak: float = manager.get_peak_volume_db()
	assert_gt(peak, -25.0, "Peak at -12 dB injection should be above -25 dB")


func test_synthetic_amplitude_minus_6_db() -> void:
	manager.inject_synthetic_amplitude(-6.0)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var peak: float = manager.get_peak_volume_db()
	assert_gt(peak, -18.0, "Peak at -6 dB injection should be above -18 dB")


func test_peak_rises_with_louder_injection() -> void:
	manager.inject_synthetic_amplitude(-20.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var peak_quiet: float = manager.get_peak_volume_db()
	assert_lt(peak_quiet, -10.0, "Baseline quiet peak should be below -10 dB")

	manager.inject_synthetic_amplitude(-6.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var peak_loud: float = manager.get_peak_volume_db()
	assert_gt(peak_loud, peak_quiet, "Louder injection should produce higher peak volume")


func test_get_bus_index_returns_valid() -> void:
	var idx: int = manager.get_bus_index()
	assert_ne(idx, -1, "get_bus_index should return a valid bus index")
	assert_eq(idx, AudioServer.get_bus_index("VoiceChatRecord"), "get_bus_index should match AudioServer lookup")
