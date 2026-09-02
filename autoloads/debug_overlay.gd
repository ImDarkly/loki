extends CanvasLayer

const HISTORY_MAX: int = 200

var _systems: Dictionary = {}
var _prev_states: Dictionary = {}
var _history: Array[String] = []
var _focused_index: int = 0
var _test_force_client: bool = false
var _test_rpc_called_count: int = 0

var _panel: PanelContainer
var _title_label: Label
var _systems_label: Label
var _live_label: Label
var _actions_label: Label
var _history_label: Label
var _content_label: Label
var _scroll: ScrollContainer


func _init() -> void:
	layer = 150
	if not OS.is_debug_build():
		visible = false
		set_process(false)
		set_process_input(false)
		return

	if not InputMap.has_action("toggle_debug_overlay"):
		InputMap.add_action("toggle_debug_overlay")
	if InputMap.action_get_events("toggle_debug_overlay").is_empty():
		var event := InputEventKey.new()
		event.keycode = KEY_F3
		event.physical_keycode = KEY_F3
		InputMap.action_add_event("toggle_debug_overlay", event)


func _ready() -> void:
	if not OS.is_debug_build():
		visible = false
		set_process(false)
		set_process_input(false)
		return

	visible = false

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_top = 0.0
	_panel.anchor_right = 0.0
	_panel.anchor_bottom = 0.0
	_panel.position = Vector2(20, 20)
	_panel.size = Vector2(420, 320)
	_panel.custom_minimum_size = Vector2(420, 320)
	var _sb := StyleBoxFlat.new()
	_sb.bg_color = Color(0, 0, 0, 0.7)
	_panel.add_theme_stylebox_override("panel", _sb)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "DebugOverlay (F3) — 0 systems"
	vbox.add_child(_title_label)

	_systems_label = Label.new()
	_systems_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_systems_label.clip_text = false
	vbox.add_child(_systems_label)

	_live_label = Label.new()
	_live_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_live_label.clip_text = false
	vbox.add_child(_live_label)

	_actions_label = Label.new()
	_actions_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_actions_label.clip_text = false
	vbox.add_child(_actions_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, 80)
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_scroll)

	_history_label = Label.new()
	_history_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_history_label.clip_text = false
	_history_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_history_label)

	_content_label = _live_label


func _get_timestamp() -> String:
	return Time.get_time_string_from_system()


func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	var should_toggle := false
	if event.is_action_pressed("toggle_debug_overlay"):
		should_toggle = true
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F3 or event.keycode == KEY_F3:
			should_toggle = true
	if should_toggle:
		visible = not visible
		return

	if visible and event is InputEventKey and event.pressed and not event.echo:
		var k = event.physical_keycode
		if k == 0:
			k = event.keycode

		var keys: Array = _systems.keys()
		keys.sort()
		var n = keys.size()

		if k == KEY_TAB or k == KEY_DOWN:
			if n > 0:
				_focused_index = (_focused_index + 1) % n
				get_viewport().set_input_as_handled()
		elif k == KEY_UP:
			if n > 0:
				_focused_index = (_focused_index - 1 + n) % n
				get_viewport().set_input_as_handled()
		elif k >= KEY_1 and k <= KEY_9:
			var idx = k - KEY_1
			if n > 0:
				var focused_name = keys[_focused_index]
				if _systems.has(focused_name):
					var node = _systems[focused_name]
					if is_instance_valid(node) and node.has_method("get_debug_actions"):
						var actions = node.get_debug_actions()
						if typeof(actions) == TYPE_ARRAY and idx < actions.size():
							var act = actions[idx]
							if typeof(act) == TYPE_DICTIONARY and act.has("id"):
								var aid = String(act["id"])
								var is_client_mode = false
								if multiplayer.has_multiplayer_peer():
									if multiplayer.is_server():
										if is_instance_valid(node) and node.has_method("debug_action"):
											node.debug_action(aid)
									else:
										is_client_mode = true
								elif _test_force_client:
									is_client_mode = true
								else:
									if is_instance_valid(node) and node.has_method("debug_action"):
										node.debug_action(aid)

								if is_client_mode:
									if _test_force_client:
										_test_rpc_called_count += 1
									else:
										_debug_action_rpc.rpc(focused_name, aid)
								get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not OS.is_debug_build():
		return

	var root := get_tree().current_scene
	if root:
		_scan_tree_for_debug(root)

	var dead_keys := []
	for sys_name in _systems:
		var node = _systems[sys_name]
		if not is_instance_valid(node):
			dead_keys.append(sys_name)

	for sys_name in dead_keys:
		_systems.erase(sys_name)
		_prev_states.erase(sys_name)

	var now := _get_timestamp()

	for sys_name in _systems:
		var node = _systems[sys_name]
		if not is_instance_valid(node):
			continue
		if not node.has_method("get_debug_state"):
			continue
		var st = node.get_debug_state()
		if typeof(st) != TYPE_DICTIONARY:
			continue

		if not _prev_states.has(sys_name):
			_prev_states[sys_name] = st.duplicate(true)
			continue

		var prev: Dictionary = _prev_states[sys_name]
		var all_keys: Array = []
		for k in prev.keys():
			if not all_keys.has(k):
				all_keys.append(k)
		for k in st.keys():
			if not all_keys.has(k):
				all_keys.append(k)

		for key in all_keys:
			var has_prev = prev.has(key)
			var has_st = st.has(key)
			if has_prev and has_st:
				if prev[key] != st[key]:
					var line = "[%s] %s: %s %s -> %s" % [now, sys_name, key, str(prev[key]), str(st[key])]
					_history.append(line)
			elif not has_prev and has_st:
				var line = "[%s] %s: %s <nil> -> %s" % [now, sys_name, key, str(st[key])]
				_history.append(line)
			elif has_prev and not has_st:
				var line = "[%s] %s: %s %s -> <removed>" % [now, sys_name, key, str(prev[key])]
				_history.append(line)

			if _history.size() > HISTORY_MAX:
				_history.remove_at(0)

		_prev_states[sys_name] = st.duplicate(true)

	var keys: Array = _systems.keys()
	keys.sort()
	if keys.is_empty():
		_focused_index = 0
	else:
		_focused_index = clampi(_focused_index, 0, keys.size() - 1)

	var focused_name = keys[_focused_index] if not keys.is_empty() else ""

	if _title_label:
		_title_label.text = "DebugOverlay (F3) — %d systems — Focus: %s" % [_systems.size(), focused_name]

	var sys_lines: Array[String] = []
	for i in range(keys.size()):
		var prefix = "> " if i == _focused_index else "  "
		sys_lines.append("%s%s" % [prefix, keys[i]])
	if sys_lines.is_empty():
		sys_lines.append("(no systems)")
	if _systems_label:
		_systems_label.text = "\n".join(sys_lines)

	var live_lines: Array[String] = []
	if focused_name != "" and _systems.has(focused_name):
		var n = _systems[focused_name]
		if is_instance_valid(n) and n.has_method("get_debug_state"):
			var d = n.get_debug_state()
			if typeof(d) == TYPE_DICTIONARY:
				for k in d.keys():
					live_lines.append("%s: %s" % [k, str(d[k])])
	if live_lines.is_empty():
		live_lines.append("(no debug state)")

	if _live_label:
		_live_label.text = "\n".join(live_lines)
	if _content_label and _content_label != _live_label:
		_content_label.text = _live_label.text

	var action_lines: Array[String] = []
	if focused_name != "" and _systems.has(focused_name):
		var n = _systems[focused_name]
		if is_instance_valid(n) and n.has_method("get_debug_actions"):
			var acts = n.get_debug_actions()
			if typeof(acts) == TYPE_ARRAY:
				var limit = min(acts.size(), 9)
				for i in range(limit):
					var act = acts[i]
					if typeof(act) == TYPE_DICTIONARY and act.has("label"):
						action_lines.append("%d: %s" % [i + 1, str(act["label"])])
	if action_lines.is_empty():
		action_lines.append("(no actions)")

	if _actions_label:
		_actions_label.text = "\n".join(action_lines)

	if _history_label:
		_history_label.text = "\n".join(_history)


@rpc("any_peer", "reliable", "call_remote")
func _debug_action_rpc(sys_name: String, action_id: String) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if _systems.has(sys_name):
		var node = _systems[sys_name]
		if is_instance_valid(node) and node.has_method("debug_action"):
			node.debug_action(action_id)


func register_system(sys_name: String, node: Node) -> void:
	if not OS.is_debug_build():
		return
	_systems[sys_name] = node


func _scan_tree_for_debug(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node.has_method("get_debug_state"):
		var sys_name := node.name
		if not _systems.has(sys_name):
			register_system(sys_name, node)
	for child in node.get_children():
		_scan_tree_for_debug(child)
