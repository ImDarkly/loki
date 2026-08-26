extends Node3D

var _manager: Node3D
var _quota: Node3D
var _label: Label

func _ready() -> void:
	_manager = get_node_or_null("SeagullManager")
	_quota = get_node_or_null("QuotaManager")
	_label = get_node_or_null("HUD/Label") as Label

	var player := get_node_or_null("Players/Player") as Player
	if player:
		player._rock_manager_ref = get_node_or_null("RockManager")
		player._seagull_manager_ref = _manager

	if _manager:
		_manager.spawn_interval_min = 2.0
		_manager.spawn_interval_max = 2.0
		_manager.return_interval_min = 5.0
		_manager.return_interval_max = 5.0
		_manager.roam_duration_min = 10.0
		_manager.roam_duration_max = 15.0
		_manager.spawn_timer.stop()
		_manager.return_timer.stop()
		if _manager.has_node("RoamTimer"):
			_manager.get_node("RoamTimer").stop()
		_manager.spawn_timer.start(2.0)

	if _quota and "shared_quota" in _quota:
		_quota.shared_quota = 10

	if _label:
		_label.text = "Dev Seagull Flow — F5 spawn / F6 skip roam / G +1 fish / R restart"

func _process(_delta: float) -> void:
	if not OS.is_debug_build():
		return
	if _manager == null or _label == null:
		return
	var state_name := str(_manager.current_state)
	if _manager.has_method("get") and "current_state" in _manager:
		state_name = str(_manager.State.keys()[_manager.current_state]) if _manager.current_state < _manager.State.size() else str(_manager.current_state)
	var roam_left := 0.0
	var spawn_left := 0.0
	var return_left := 0.0
	if _manager.has_node("RoamTimer"):
		roam_left = (_manager.get_node("RoamTimer") as Timer).time_left
	spawn_left = _manager.spawn_timer.time_left if _manager.spawn_timer else 0.0
	return_left = _manager.return_timer.time_left if _manager.return_timer else 0.0
	var quota_val := 0
	if _quota and "shared_quota" in _quota:
		quota_val = _quota.shared_quota
	var pos := Vector3.ZERO
	if _manager.seagull_node and is_instance_valid(_manager.seagull_node):
		pos = _manager.seagull_node.position
	_label.text = "State: %s | Roam: %.1fs Spawn: %.1fs Return: %.1fs | Quota: %d | Pos: (%.1f, %.1f, %.1f)\n[F5] Full cycle  [F6] Skip roam  [G] +5 fish  [R] Restart" % [state_name, roam_left, spawn_left, return_left, quota_val, pos.x, pos.y, pos.z]

func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F5:
				_trigger_full_cycle()
			KEY_F6:
				_skip_roam()
			KEY_G:
				_give_quota(5)
			KEY_R:
				if _manager:
					_manager.reset_for_restart()
			KEY_H:
				Engine.time_scale = 1.0 if Engine.time_scale > 1.5 else 2.0
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _trigger_full_cycle() -> void:
	if _manager == null:
		return
	_manager.reset_for_restart()
	_manager._spawn_seagull()
	_manager.current_state = _manager.State.ROAMING
	if _manager.has_node("RoamTimer"):
		(_manager.get_node("RoamTimer") as Timer).start(randf_range(_manager.roam_duration_min, _manager.roam_duration_max))
	_manager.seagull_node.visible = true

func _skip_roam() -> void:
	if _manager == null:
		return
	if _manager.current_state == _manager.State.ROAMING:
		_manager._on_roam_timer_timeout()

func _give_quota(amount: int) -> void:
	if _quota and "shared_quota" in _quota:
		_quota.shared_quota += amount
