extends GutTest

var overlay: CanvasLayer


func before_each() -> void:
	multiplayer.multiplayer_peer = null
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


class MockActionSystem extends Node:
	var action_called: String = ""
	func get_debug_state() -> Dictionary:
		return {"status": "ok"}
	func get_debug_actions() -> Array[Dictionary]:
		return [
			{"id": "act_one", "label": "Action One"},
			{"id": "act_two", "label": "Action Two"}
		]
	func debug_action(id: String) -> void:
		action_called = id


class TenActionSystem extends Node:
	func get_debug_actions() -> Array[Dictionary]:
		var acts: Array[Dictionary] = []
		for i in range(10):
			acts.append({"id": "act_%d" % i, "label": "Action %d" % i})
		return acts


func test_debug_build_gating() -> void:
	if OS.is_debug_build():
		var node = Node.new()
		add_child_autofree(node)
		overlay.register_system("Gated", node)
		assert_true(overlay._systems.has("Gated"), "In debug build, register_system should store system")


func test_focus_cycling_and_wrapping() -> void:
	var sys1 = Node.new()
	var sys2 = Node.new()
	add_child_autofree(sys1)
	add_child_autofree(sys2)
	overlay.register_system("B_Sys", sys1)
	overlay.register_system("A_Sys", sys2)
	overlay.visible = true

	overlay._process(0.016)
	assert_eq(overlay._focused_index, 0)

	var event_tab := InputEventKey.new()
	event_tab.physical_keycode = KEY_TAB
	event_tab.pressed = true
	overlay._input(event_tab)
	overlay._process(0.016)
	assert_eq(overlay._focused_index, 1)

	overlay._input(event_tab)
	overlay._process(0.016)
	assert_eq(overlay._focused_index, 0)

	var event_up := InputEventKey.new()
	event_up.physical_keycode = KEY_UP
	event_up.pressed = true
	overlay._input(event_up)
	overlay._process(0.016)
	assert_eq(overlay._focused_index, 1)


func test_actions_rendering_and_triggering() -> void:
	var mock_act = MockActionSystem.new()
	add_child_autofree(mock_act)
	overlay.register_system("ActionSys", mock_act)
	overlay.visible = true
	overlay._process(0.016)

	assert_true(overlay._actions_label.text.contains("1: Action One"))
	assert_true(overlay._actions_label.text.contains("2: Action Two"))

	var event_1 := InputEventKey.new()
	event_1.physical_keycode = KEY_1
	event_1.pressed = true
	overlay._input(event_1)

	assert_eq(mock_act.action_called, "act_one", "Pressing 1 should trigger focused system's first action")


func test_focus_indicator_render() -> void:
	var sys1 = Node.new()
	var sys2 = Node.new()
	add_child_autofree(sys1)
	add_child_autofree(sys2)
	overlay.register_system("B_Sys", sys1)
	overlay.register_system("A_Sys", sys2)
	overlay.visible = true
	
	# Initial: A_Sys is focused (sorted)
	overlay._process(0.016)
	assert_true(overlay._systems_label.text.contains("> A_Sys"))
	
	# Tab: B_Sys focused
	var event_tab := InputEventKey.new()
	event_tab.physical_keycode = KEY_TAB
	event_tab.pressed = true
	overlay._input(event_tab)
	overlay._process(0.016)
	assert_true(overlay._systems_label.text.contains("> B_Sys"))


func test_actions_truncation_to_9() -> void:
	var mock_ten = TenActionSystem.new()
	add_child_autofree(mock_ten)
	overlay.register_system("TenSys", mock_ten)
	overlay.visible = true
	overlay._process(0.016)
	var lines = overlay._actions_label.text.split("\n")
	assert_eq(lines.size(), 9, "Actions should be truncated to 9")


func test_no_button_nodes() -> void:
	# Recursive search for Button
	var stack = [overlay]
	while not stack.is_empty():
		var node = stack.pop_back()
		assert_false(node is Button, "DebugOverlay should not contain Button nodes")
		for child in node.get_children():
			stack.append(child)


func test_rpc_trigger_host_calls_local_debug_action() -> void:
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(12345)
	multiplayer.multiplayer_peer = peer
	
	var mock_act = MockActionSystem.new()
	add_child_autofree(mock_act)
	overlay.register_system("HostRPC_Sys", mock_act)
	overlay.visible = true
	overlay._process(0.016)
	
	var event_1 := InputEventKey.new()
	event_1.physical_keycode = KEY_1
	event_1.pressed = true
	
	overlay._focused_index = 0
	overlay._input(event_1)
	
	assert_eq(mock_act.action_called, "act_one", "Host with server peer should execute debug_action locally")
	
	multiplayer.multiplayer_peer = null


func test_rpc_trigger_client_calls_rpc() -> void:
	overlay._test_force_client = true
	
	var mock_act = MockActionSystem.new()
	add_child_autofree(mock_act)
	overlay.register_system("ClientRPC_Sys", mock_act)
	overlay.visible = true
	overlay._process(0.016)
	
	var event_1 := InputEventKey.new()
	event_1.physical_keycode = KEY_1
	event_1.pressed = true
	
	overlay._focused_index = 0
	overlay._input(event_1)
	
	assert_eq(mock_act.action_called, "", "Client should not execute debug_action locally (should RPC)")
	assert_eq(overlay._test_rpc_called_count, 1, "Client should trigger RPC branch")
	
	overlay._test_force_client = false
	overlay._test_rpc_called_count = 0
