extends Node3D

var _player: Player
var _mechanic: Node3D
var _zone_manager: Node3D
var _label: Label


func _ready() -> void:
	_player = get_node_or_null("Players/Player_1") as Player
	_zone_manager = get_node_or_null("ZoneManager")
	_label = get_node_or_null("HUD/Label") as Label
	if _player:
		_mechanic = _player.fishing_mechanic
		var cam := _player.get_node_or_null("Head/Camera3D") as Camera3D
		if cam:
			cam.current = true

	if _mechanic:
		_mechanic.min_bite_delay = 0.2
		_mechanic.max_bite_delay = 0.5
		_mechanic.escape_time_threshold = 10.0

	if _zone_manager and _zone_manager.has_method("set_zones"):
		_zone_manager.set_zones([
			{"center": Vector3(0, 0, -10), "radius": 15.0}
		])

	if _label:
		_label.text = "Dev Fish Fight Flow — F5 cast & bite / Scroll or F6 reel / R reset"


func _process(_delta: float) -> void:
	if not OS.is_debug_build():
		return
	if _mechanic == null or _label == null:
		return
	var state_name := str(_mechanic.State.keys()[_mechanic.current_state]) if _mechanic.current_state < _mechanic.State.size() else str(_mechanic.current_state)
	var hook_name := str(_mechanic.HookType.keys()[_mechanic.hook_type]) if _mechanic.hook_type < _mechanic.HookType.size() else str(_mechanic.hook_type)
	var fight_pull := _mechanic._fight_pull
	var fish_pos := _mechanic.get_fish_position()
	_label.text = "State: %s | Hook: %s | Fight Pull: %.2f | Fish Pos: (%.1f, %.1f, %.1f)\n[F5] Cast & Bite  [Scroll Down / F6] Reel / Spike  [R] Reset" % [state_name, hook_name, fight_pull, fish_pos.x, fish_pos.y, fish_pos.z]


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F5:
				_force_cast_and_bite()
			KEY_F6:
				_trigger_reel()
			KEY_R:
				_reset_flow()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_trigger_reel()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _force_cast_and_bite() -> void:
	if _mechanic == null:
		return
	_mechanic.reset_for_restart()
	_mechanic.cast(Vector3(0, 0, -10), 0.5)
	_mechanic._on_casting_timer_timeout()
	_mechanic._on_bite_timer_timeout()
	_mechanic._is_fighting = true
	_mechanic._fight_target = 10.0


func _trigger_reel() -> void:
	if _mechanic == null:
		return
	_mechanic._reset_scroll_timers()


func _reset_flow() -> void:
	if _mechanic:
		_mechanic.reset_for_restart()
