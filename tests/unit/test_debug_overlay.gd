extends GutTest

var overlay: CanvasLayer


func before_each() -> void:
	var script = load("res://autoloads/debug_overlay.gd")
	overlay = autofree(script.new())
	add_child(overlay)
	await get_tree().process_frame


func test_register_system_stores_reference() -> void:
	var mock_sys = Node.new()
	add_child_autofree(mock_sys)
	
	overlay.register_system("TestSystem", mock_sys)
	assert_true(overlay._systems.has("TestSystem"), "Should store system reference")
	assert_eq(overlay._systems["TestSystem"], mock_sys, "Stored reference should match node")


func test_register_system_repeated_and_null_calls() -> void:
	var mock_sys1 = Node.new()
	var mock_sys2 = Node.new()
	add_child_autofree(mock_sys1)
	add_child_autofree(mock_sys2)

	overlay.register_system("SystemA", mock_sys1)
	overlay.register_system("SystemA", mock_sys2)
	assert_eq(overlay._systems["SystemA"], mock_sys2, "Repeated registration should update reference")

	overlay.register_system("NullSys", null)
	assert_true(overlay._systems.has("NullSys"), "Should accept null node entry")
	assert_null(overlay._systems["NullSys"], "Null node reference should be stored as null")


func test_pruning_removes_dead_entries() -> void:
	var mock_sys = Node.new()
	add_child(mock_sys)
	
	overlay.register_system("LiveSystem", mock_sys)
	assert_true(overlay._systems.has("LiveSystem"))

	mock_sys.queue_free()
	await get_tree().process_frame

	overlay._process(0.016)

	assert_false(overlay._systems.has("LiveSystem"), "Pruning should remove invalid/freed node entries")


func test_input_map_action_toggle_debug_overlay_exists() -> void:
	assert_true(InputMap.has_action("toggle_debug_overlay"), "InputMap action toggle_debug_overlay should exist")
	var events = InputMap.action_get_events("toggle_debug_overlay")
	assert_false(events.is_empty(), "toggle_debug_overlay action should have assigned events")
	
	var has_f3 = false
	for event in events:
		if event is InputEventKey and event.physical_keycode == KEY_F3:
			has_f3 = true
			break
	assert_true(has_f3, "toggle_debug_overlay should be bound to KEY_F3")


func test_f3_toggles_visibility_without_touching_mouse_mode() -> void:
	assert_false(overlay.visible, "Overlay should start invisible")

	var initial_mouse_mode = Input.get_mouse_mode()

	var event := InputEventKey.new()
	event.physical_keycode = KEY_F3
	event.pressed = true
	
	overlay._input(event)
	assert_true(overlay.visible, "F3 press should toggle overlay visibility to true")

	assert_eq(Input.get_mouse_mode(), initial_mouse_mode, "Toggling debug overlay should not touch Input.mouse_mode")

	overlay._input(event)
	assert_false(overlay.visible, "Second F3 press should toggle overlay visibility back to false")


func test_autoload_order_after_hlobbies() -> void:
	var config := ConfigFile.new()
	var err = config.load("res://project.godot")
	assert_eq(err, OK, "Should successfully load project.godot")
	
	if err == OK:
		var autoloads = config.get_section_keys("autoload")
		assert_true("DebugOverlay" in autoloads, "DebugOverlay should be present in autoloads")
		assert_true("HLobbies" in autoloads, "HLobbies should be present in autoloads")
		
		var hlobbies_idx = autoloads.find("HLobbies")
		var debug_overlay_idx = autoloads.find("DebugOverlay")
		assert_gt(debug_overlay_idx, hlobbies_idx, "DebugOverlay autoload order should be after HLobbies")


func test_debug_build_gating() -> void:
	if OS.is_debug_build():
		var node = Node.new()
		add_child_autofree(node)
		overlay.register_system("Gated", node)
		assert_true(overlay._systems.has("Gated"), "In debug build, register_system should store system")
