class_name TestDebugOverlayHistory
extends GutTest

var overlay: CanvasLayer

class MockDebugSystem extends Node:
	var state_dict: Dictionary = {"state": "WAITING", "count": 1}
	func get_debug_state() -> Dictionary:
		return state_dict


func before_each() -> void:
	var script = load("res://autoloads/debug_overlay.gd")
	overlay = autofree(script.new())
	add_child(overlay)
	await get_tree().process_frame


func test_get_debug_state_polling_renders_live_keys() -> void:
	var mock_sys = MockDebugSystem.new()
	add_child_autofree(mock_sys)
	overlay.register_system("MockSys", mock_sys)

	overlay._process(0.016)

	assert_true(overlay._live_label.text.contains("state: WAITING"), "Should render state key/value")
	assert_true(overlay._live_label.text.contains("count: 1"), "Should render count key/value")


func test_field_level_diff_produces_one_log_line_per_changed_field() -> void:
	var mock_sys = MockDebugSystem.new()
	add_child_autofree(mock_sys)
	overlay.register_system("MockSys", mock_sys)

	# First frame: silent seed
	overlay._process(0.016)
	assert_eq(overlay._history.size(), 0, "First frame should seed silently")

	# Second frame: change state and count
	mock_sys.state_dict["state"] = "APPROACHING"
	mock_sys.state_dict["count"] = 2
	overlay._process(0.016)

	assert_eq(overlay._history.size(), 2, "Should produce one log line per changed field")
	assert_string_contains(overlay._history[0], "MockSys: state WAITING -> APPROACHING")
	assert_string_contains(overlay._history[1], "MockSys: count 1 -> 2")


func test_history_timestamped_and_capped_at_200() -> void:
	var mock_sys = MockDebugSystem.new()
	add_child_autofree(mock_sys)
	overlay.register_system("MockSys", mock_sys)
	overlay._process(0.016) # seed

	for i in range(220):
		mock_sys.state_dict["count"] = i + 10
		overlay._process(0.016)

	assert_eq(overlay._history.size(), 200, "History ring buffer should cap at 200 entries")
	assert_string_contains(overlay._history[0], "MockSys: count")


func test_no_history_when_state_unchanged() -> void:
	var mock_sys = MockDebugSystem.new()
	add_child_autofree(mock_sys)
	overlay.register_system("MockSys", mock_sys)
	overlay._process(0.016) # seed

	overlay._process(0.016) # unchanged
	assert_eq(overlay._history.size(), 0, "No history log when state is unchanged")


func test_missing_get_debug_state_is_noop() -> void:
	var plain_sys = Node.new()
	add_child_autofree(plain_sys)
	overlay.register_system("PlainSys", plain_sys)
	overlay._process(0.016)
	assert_eq(overlay._history.size(), 0, "Systems without get_debug_state should be ignored without error")


func test_pruning_clears_prev_snapshot() -> void:
	var mock_sys = MockDebugSystem.new()
	add_child(mock_sys)
	overlay.register_system("MockSys", mock_sys)
	overlay._process(0.016) # seed
	assert_true(overlay._prev_states.has("MockSys"))

	mock_sys.queue_free()
	await get_tree().process_frame
	overlay._process(0.016)

	assert_false(overlay._systems.has("MockSys"))
	assert_false(overlay._prev_states.has("MockSys"), "Pruning should erase prev state snapshot")


func test_first_seen_seed_is_silent() -> void:
	var mock_sys = MockDebugSystem.new()
	add_child_autofree(mock_sys)
	overlay.register_system("NewSys", mock_sys)
	overlay._process(0.016)
	assert_eq(overlay._history.size(), 0, "First registration and poll should seed silently")


func test_added_key_produces_nil_sentinel() -> void:
	var mock_sys = MockDebugSystem.new()
	add_child_autofree(mock_sys)
	overlay.register_system("MockSys", mock_sys)
	overlay._process(0.016) # seed
	
	mock_sys.state_dict["new_key"] = 99
	overlay._process(0.016)
	
	assert_eq(overlay._history.size(), 1)
	assert_string_contains(overlay._history[0], "MockSys: new_key <nil> -> 99")


func test_removed_key_produces_removed_sentinel() -> void:
	var mock_sys = MockDebugSystem.new()
	add_child_autofree(mock_sys)
	overlay.register_system("MockSys", mock_sys)
	overlay._process(0.016) # seed
	
	mock_sys.state_dict.erase("count")
	overlay._process(0.016)
	
	assert_eq(overlay._history.size(), 1)
	assert_string_contains(overlay._history[0], "MockSys: count 1 -> <removed>")


func test_non_dictionary_state_is_ignored() -> void:
	var bad_sys = Node.new()
	# We can use a script or mock class that returns String from get_debug_state
	# Or dynamically attach a script
	var script = GDScript.new()
	script.source_code = "extends Node\nfunc get_debug_state() -> String:\n\treturn \"not a dict\"\n"
	script.reload()
	bad_sys.set_script(script)
	add_child_autofree(bad_sys)
	overlay.register_system("BadSys", bad_sys)
	overlay._process(0.016)
	assert_eq(overlay._history.size(), 0, "Non-Dictionary debug state should be ignored")

