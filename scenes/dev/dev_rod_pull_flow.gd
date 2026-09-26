extends Node3D

var _rescuer: Player
var _victim: Player
var _mechanic: Node3D
var _zone_manager: Node3D
var _label: Label
var _victim_start := Vector3(6, 0, -20)


func _ready() -> void:
	_rescuer = get_node_or_null("Players/Player_1") as Player
	_victim = get_node_or_null("Players/Player_2") as Player
	_zone_manager = get_node_or_null("ZoneManager")
	_label = get_node_or_null("HUD/Label") as Label
	if _rescuer:
		_mechanic = _rescuer.fishing_mechanic

	if _victim:
		_victim.global_position = _victim_start
		_victim.player_state = Player.PlayerState.FLOATING
		_victim._float_time = 0.0

	if _mechanic:
		_mechanic.min_bite_delay = 0.5
		_mechanic.max_bite_delay = 1.0
		_mechanic.escape_time_threshold = 99.0

	if _zone_manager and _zone_manager.has_method("set_zones"):
		_zone_manager.set_zones([
			{"center": Vector3(6, 0, -20), "radius": 10.0}
		])

	if _label:
		_label.text = "Dev Rod Pull Flow — F5 hook / F6 pop / G rescue / R reset"


func _process(_delta: float) -> void:
	if not OS.is_debug_build():
		return
	if _mechanic == null or _label == null:
		return
	var hook_name := str(_mechanic.HookType.keys()[_mechanic.hook_type]) if _mechanic.hook_type < _mechanic.HookType.size() else str(_mechanic.hook_type)
	var tether_text := "(none)"
	if _mechanic.hook_type == _mechanic.HookType.PLAYER and _rescuer and is_instance_valid(_rescuer) and is_instance_valid(_mechanic._tether_target):
		tether_text = "%.1fm" % _rescuer.global_position.distance_to(_mechanic._tether_target.global_position)
	var fight_text := "%.1f/%.1f" % [_mechanic._fight_progress, _mechanic._fight_target]
	var float_text := "%.1fs" % _victim._float_time if _victim and is_instance_valid(_victim) else "?"
	var victim_state := str(_victim.player_state) if _victim and is_instance_valid(_victim) else "?"
	_label.text = "Hook: %s | Tether: %s | Fight: %s | Float: %s | Victim: %s\n[F5] Force hook  [F6] Pop tether  [G] Complete rescue  [R] Reset" % [hook_name, tether_text, fight_text, float_text, victim_state]


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F5:
				_force_hook()
			KEY_F6:
				_pop_tether()
			KEY_G:
				_complete_rescue()
			KEY_R:
				_reset_flow()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _force_hook() -> void:
	if _mechanic == null or _victim == null or not is_instance_valid(_victim):
		return
	if _victim.player_state != Player.PlayerState.FLOATING:
		_victim.player_state = Player.PlayerState.FLOATING
	_mechanic.request_hook_player(_victim._parse_owner_id())


func _pop_tether() -> void:
	if _mechanic == null or _rescuer == null or _victim == null:
		return
	if _mechanic.hook_type != _mechanic.HookType.PLAYER:
		return
	_victim.global_position = _rescuer.global_position + Vector3(30, 0, 0)
	_mechanic._check_tether_pop()


func _complete_rescue() -> void:
	if _mechanic == null or _victim == null or not is_instance_valid(_victim):
		return
	if _mechanic.hook_type != _mechanic.HookType.PLAYER:
		return
	_victim.global_position = MapConfig.MAP_CENTER
	_mechanic._check_rescue_complete()


func _reset_flow() -> void:
	if _mechanic:
		_mechanic.reset_for_restart()
	if _victim and is_instance_valid(_victim):
		_victim.global_position = _victim_start
		_victim.player_state = Player.PlayerState.FLOATING
		_victim._float_time = 0.0
