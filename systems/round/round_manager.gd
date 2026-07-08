extends Node3D

# Reserved for Night phase — not emitted during Fishing phase
signal round_ended(success: bool)

@export var round_duration: float = 900.0

var round_active: bool = false
var round_success: bool = false
var fishing_active: bool = true

@onready var timer: Timer = $Timer


func _ready() -> void:
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)
	GDSync.expose_func(_apply_synced_state)
	GDSync.expose_func(_apply_restart)

	if GDSync.is_host():
		timer.start(round_duration)
		round_active = true
		fishing_active = true
		_sync_state_to_clients()


func _on_timer_timeout() -> void:
	if not GDSync.is_host():
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
	if not GDSync.is_host():
		return
	GDSync.call_func_all(_apply_synced_state, round_active, round_success, fishing_active)


func restart_round() -> void:
	if not GDSync.is_host():
		return
	round_active = true
	round_success = false
	fishing_active = true
	timer.start(round_duration)
	_sync_state_to_clients()

	var dm := get_node_or_null("/root/main/DangerManager")
	if dm:
		dm.reset_for_restart()

	GDSync.call_func_all(_apply_restart)


func _apply_restart() -> void:
	round_active = true
	round_success = false
	fishing_active = true

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	var es := get_node_or_null("/root/main/EndScreen")
	if es:
		es.visible = false

	var players_node := get_node_or_null("/root/main/Players")
	if players_node:
		for child in players_node.get_children():
			var fm := child.get_node_or_null("FishingMechanic")
			if fm:
				fm.reset_for_restart()


func _apply_synced_state(active: bool, success: bool = false, active_fishing: bool = true) -> void:
	var was_active := round_active
	round_active = active
	round_success = success
	fishing_active = active_fishing
	if was_active and not active:
		round_ended.emit(success)
