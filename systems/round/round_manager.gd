extends Node3D

const _shop_ui_script = preload("res://ui/shop_ui.gd")

# Reserved for Night phase — not emitted during Fishing phase
signal round_ended(success: bool)

@export var round_duration: float = 900.0

var round_active: bool = false
var round_success: bool = false
var fishing_active: bool = true

@onready var timer: Timer = $Timer


func _ready() -> void:
	var dbg = get_node_or_null("/root/DebugOverlay")
	if dbg:
		dbg.register_system(name, self)

	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)

	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		timer.start(round_duration)
		round_active = true
		fishing_active = true
		_sync_state_to_clients()


func _on_timer_timeout() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if not round_active:
		return
	fishing_active = false
	_sync_state_to_clients()


# Reserved for Night phase — not called during Fishing phase
func _end_round(success: bool) -> void:
	round_active = false
	round_success = success
	timer.stop()
	round_ended.emit(success)
	_sync_state_to_clients()


func _sync_state_to_clients() -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	_apply_synced_state.rpc(round_active, round_success, fishing_active)


func restart_round() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	round_active = true
	round_success = false
	fishing_active = true
	timer.start(round_duration)
	_sync_state_to_clients()

	var dm := get_node_or_null("/root/main/DangerManager")
	if dm:
		dm.reset_for_restart()

	var zm := get_node_or_null("/root/main/ZoneManager")
	if zm:
		zm.reset_for_restart()

	var rm := get_node_or_null("/root/main/RockManager")
	if rm:
		rm.reset_for_restart()

	var sm := get_node_or_null("/root/main/SeagullManager")
	if sm and sm.has_method("reset_for_restart"):
		sm.reset_for_restart()

	if multiplayer.has_multiplayer_peer():
		_apply_restart.rpc()


@rpc("authority", "call_local", "reliable")
func _apply_restart() -> void:
	round_active = true
	round_success = false
	fishing_active = true

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	var es := get_node_or_null("/root/main/EndScreen")
	if es:
		es.visible = false

	for child in get_tree().root.get_children():
		if child.get_script() == _shop_ui_script:
			get_node("/root/game_manager").shop_toggled.emit(false)
			child.queue_free()

	var players_node := get_node_or_null("/root/main/Players")
	if players_node:
		for child in players_node.get_children():
			if child is Player:
				var fm := child.get_node_or_null("FishingMechanic")
				if fm:
					fm.reset_for_restart()
				child.reset_for_restart()
				child._on_restart()


@rpc("authority", "call_local", "reliable")
func _apply_synced_state(active: bool, success: bool = false, active_fishing: bool = true) -> void:
	var was_active := round_active
	round_active = active
	round_success = success
	fishing_active = active_fishing
	if was_active and not active:
		round_ended.emit(success)


func get_debug_state() -> Dictionary:
	return {
		"round_active": round_active,
		"round_success": round_success,
		"fishing_active": fishing_active,
		"time_left": max(0, int(ceil(timer.time_left))) if is_instance_valid(timer) else 0
	}


func get_debug_actions() -> Array[Dictionary]:
	return [
		{"id": "pause_fishing", "label": "Pause Fishing"},
		{"id": "resume_fishing", "label": "Resume Fishing"},
		{"id": "restart_round", "label": "Restart Round"},
		{"id": "add_time_30", "label": "+30s Time"},
		{"id": "shave_time_30", "label": "-30s Time"}
	]


func debug_action(action_id: String) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	match action_id:
		"pause_fishing":
			fishing_active = false
			_sync_state_to_clients()
		"resume_fishing":
			fishing_active = true
			_sync_state_to_clients()
		"restart_round":
			restart_round()
		"add_time_30":
			_adjust_timer(30.0)
		"shave_time_30":
			_adjust_timer(-30.0)


func _adjust_timer(delta: float) -> void:
	if not is_instance_valid(timer) or timer.is_stopped():
		return
	var remaining := timer.time_left + delta
	if remaining <= 0.0:
		timer.stop()
		_on_timer_timeout()
	else:
		timer.start(remaining)
		# time_left is intentionally local-derived; timer runs on server only
