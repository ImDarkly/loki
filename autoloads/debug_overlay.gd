extends CanvasLayer

var _systems: Dictionary = {}
var _title_label: Label
var _content_label: Label
var _panel: PanelContainer


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
	_panel.offset_left = 20
	_panel.offset_top = 20
	_panel.offset_right = 420
	_panel.offset_bottom = 200
	var _sb := StyleBoxFlat.new()
	_sb.bg_color = Color(0, 0, 0, 0.7)
	_panel.add_theme_stylebox_override("panel", _sb)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var vbox := VBoxContainer.new()
	_panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "DebugOverlay (F3) — 0 systems"
	vbox.add_child(_title_label)

	_content_label = Label.new()
	_content_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_content_label)


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


func _process(_delta: float) -> void:
	if not OS.is_debug_build():
		return

	var dead_keys := []
	for sys_name in _systems:
		var node = _systems[sys_name]
		if not is_instance_valid(node):
			dead_keys.append(sys_name)

	for sys_name in dead_keys:
		_systems.erase(sys_name)

	var count := _systems.size()
	if _title_label:
		_title_label.text = "DebugOverlay (F3) — %d systems" % count

	var lines: Array[String] = []
	for sys_name in _systems:
		var node = _systems[sys_name]
		var status := "active"
		if node.has_method("get_debug_status"):
			status = str(node.get_debug_status())
		elif node.has_method("get_state"):
			status = str(node.get_state())
		lines.append("%s: %s" % [sys_name, status])

	if _content_label:
		_content_label.text = "\n".join(lines)


func register_system(sys_name: String, node: Node) -> void:
	if not OS.is_debug_build():
		return
	_systems[sys_name] = node
