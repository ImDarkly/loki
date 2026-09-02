extends GutTest

var debug_overlay: CanvasLayer

class MockSystem extends Node:
	var actions: Array = []
	var action_called: String = ""
	var call_count: int = 0
	func get_debug_state() -> Dictionary:
		return {}
	func get_debug_actions() -> Array:
		return actions
	func debug_action(id: String) -> void:
		action_called = id
		call_count += 1

class FifteenActionSystem extends Node:
	var action_called: String = ""
	func get_debug_actions() -> Array:
		var acts: Array = []
		for i in range(15):
			acts.append({"id": "act_%d" % i, "label": "Action %d" % i})
		return acts
	func debug_action(id: String) -> void:
		action_called = id
	func get_debug_state() -> Dictionary:
		return {}

func before_each() -> void:
	multiplayer.multiplayer_peer = null
	debug_overlay = load("res://autoloads/debug_overlay.gd").new()
	add_child_autofree(debug_overlay)
	await get_tree().process_frame

func test_focus_wrap_tab_down_up() -> void:
	var a = MockSystem.new()
	var b = MockSystem.new()
	add_child_autofree(a)
	add_child_autofree(b)
	debug_overlay.register_system("A_Sys", a)
	debug_overlay.register_system("B_Sys", b)
	debug_overlay.visible = true
	debug_overlay._process(0.016)
	assert_eq(debug_overlay._focused_index, 0, "starts at 0 (A_Sys sorted first)")

	var event_tab := InputEventKey.new()
	event_tab.physical_keycode = KEY_TAB
	event_tab.pressed = true
	debug_overlay._input(event_tab)
	assert_eq(debug_overlay._focused_index, 1, "Tab moves to 1")
	debug_overlay._input(event_tab)
	assert_eq(debug_overlay._focused_index, 0, "Tab wraps to 0")

	var event_down := InputEventKey.new()
	event_down.physical_keycode = KEY_DOWN
	event_down.pressed = true
	debug_overlay._input(event_down)
	assert_eq(debug_overlay._focused_index, 1, "Down moves to 1")
	debug_overlay._input(event_down)
	assert_eq(debug_overlay._focused_index, 0, "Down wraps to 0")

	var event_up := InputEventKey.new()
	event_up.physical_keycode = KEY_UP
	event_up.pressed = true
	debug_overlay._input(event_up)
	assert_eq(debug_overlay._focused_index, 1, "Up wraps from 0 to 1")
	debug_overlay._input(event_up)
	assert_eq(debug_overlay._focused_index, 0, "Up wraps from 1 to 0")

func test_highlight_moves_with_focus() -> void:
	var a = MockSystem.new()
	var b = MockSystem.new()
	add_child_autofree(a)
	add_child_autofree(b)
	debug_overlay.register_system("A_Sys", a)
	debug_overlay.register_system("B_Sys", b)
	debug_overlay.visible = true
	debug_overlay._process(0.016)
	assert_true(debug_overlay._systems_label.text.contains("> A_Sys"), "A_Sys highlighted initially")

	var event_tab := InputEventKey.new()
	event_tab.physical_keycode = KEY_TAB
	event_tab.pressed = true
	debug_overlay._input(event_tab)
	debug_overlay._process(0.016)
	assert_true(debug_overlay._systems_label.text.contains("> B_Sys"), "B_Sys highlighted after Tab")
	assert_eq(debug_overlay._systems_label.text.count("> "), 1, "only one highlight")

func test_actions_truncation_to_nine_display() -> void:
	var sys = FifteenActionSystem.new()
	add_child_autofree(sys)
	debug_overlay.register_system("BigSys", sys)
	debug_overlay.visible = true
	debug_overlay._process(0.016)
	var lines = debug_overlay._actions_label.text.split("\n")
	assert_eq(lines.size(), 9, "should only show 9 actions")
	assert_true(debug_overlay._actions_label.text.contains("1: Action 0"), "first action shown")
	assert_true(debug_overlay._actions_label.text.contains("9: Action 8"), "ninth action shown")
	assert_false(debug_overlay._actions_label.text.contains("10: Action 9"), "tenth action not shown")

func test_actions_truncation_dispatch_still_nine() -> void:
	var mock = MockSystem.new()
	for i in range(15):
		mock.actions.append({"id": "act_%d" % i, "label": "Action %d" % i})
	add_child_autofree(mock)
	debug_overlay.register_system("MockBig", mock)
	debug_overlay.visible = true
	debug_overlay._process(0.016)
	debug_overlay._focused_index = 0
	var event9 := InputEventKey.new()
	event9.physical_keycode = KEY_9
	event9.pressed = true
	debug_overlay._input(event9)
	assert_eq(mock.action_called, "act_8", "KEY_9 dispatches 9th action (index 8)")
	mock.action_called = ""
	var event1 := InputEventKey.new()
	event1.physical_keycode = KEY_1
	event1.pressed = true
	debug_overlay._input(event1)
	assert_eq(mock.action_called, "act_0", "KEY_1 dispatches first action")

func test_only_focused_dispatch() -> void:
	var sys_a = MockSystem.new()
	sys_a.actions = [{"id": "a_one", "label": "A One"}, {"id": "a_two", "label": "A Two"}]
	var sys_b = MockSystem.new()
	sys_b.actions = [{"id": "b_one", "label": "B One"}, {"id": "b_two", "label": "B Two"}]
	add_child_autofree(sys_a)
	add_child_autofree(sys_b)
	debug_overlay.register_system("A_Focus", sys_a)
	debug_overlay.register_system("B_Focus", sys_b)
	debug_overlay.visible = true
	debug_overlay._process(0.016)
	# Sorted: A_Focus(0), B_Focus(1) -> focus 0 = A
	assert_eq(debug_overlay._focused_index, 0)
	var event1 := InputEventKey.new()
	event1.physical_keycode = KEY_1
	event1.pressed = true
	debug_overlay._input(event1)
	assert_eq(sys_a.action_called, "a_one", "focused A should receive")
	assert_eq(sys_b.action_called, "", "unfocused B should not receive")
	assert_eq(sys_a.call_count, 1)
	assert_eq(sys_b.call_count, 0)

	# Move focus to B via Tab
	var event_tab := InputEventKey.new()
	event_tab.physical_keycode = KEY_TAB
	event_tab.pressed = true
	debug_overlay._input(event_tab)
	debug_overlay._process(0.016)
	assert_eq(debug_overlay._focused_index, 1)
	sys_a.action_called = ""
	sys_b.action_called = ""
	debug_overlay._input(event1)
	assert_eq(sys_b.action_called, "b_one", "now focused B should receive")
	assert_eq(sys_a.action_called, "", "unfocused A should not receive after focus change")

func test_invisible_blocks_dispatch_and_focus() -> void:
	var sys = MockSystem.new()
	sys.actions = [{"id": "act_one", "label": "One"}]
	add_child_autofree(sys)
	debug_overlay.register_system("A_Sys", sys)
	var sys2 = MockSystem.new()
	add_child_autofree(sys2)
	debug_overlay.register_system("B_Sys", sys2)
	debug_overlay.visible = false
	debug_overlay._process(0.016)
	debug_overlay._focused_index = 0
	var event_tab := InputEventKey.new()
	event_tab.physical_keycode = KEY_TAB
	event_tab.pressed = true
	debug_overlay._input(event_tab)
	assert_eq(debug_overlay._focused_index, 0, "Tab should not move when invisible")
	var event1 := InputEventKey.new()
	event1.physical_keycode = KEY_1
	event1.pressed = true
	debug_overlay._input(event1)
	assert_eq(sys.action_called, "", "dispatch blocked when invisible")

func test_no_buttons_or_mouse():
	# Check panel mouse_filter
	assert_eq(debug_overlay._panel.mouse_filter, Control.MOUSE_FILTER_IGNORE, "Panel should ignore mouse")
	
	# Recursively check no Buttons
	var stack = [debug_overlay]
	while stack.size() > 0:
		var node = stack.pop_back()
		assert_false(node is Button, "Should not contain Button node: " + node.name)
		for child in node.get_children():
			stack.append(child)

class MockBrokenSystem extends Node:
	func get_debug_state(): return {}
	func get_debug_actions(): return [{"id": "a1", "label": "A1"}]
	# No debug_action method

func test_missing_method_does_not_crash():
	var broken = MockBrokenSystem.new()
	broken.name = "Broken"
	add_child_autofree(broken)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Find index of "Broken"
	var keys = debug_overlay._systems.keys()
	keys.sort()
	var idx = keys.find("Broken")
	debug_overlay._focused_index = idx
	
	# Should not crash
	var event = InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_1
	debug_overlay._input(event)
	
	# If we got here, it didn't crash
	assert_true(true, "Did not crash")
