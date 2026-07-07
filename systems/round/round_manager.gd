extends Node3D

signal round_ended(success: bool)

@export var round_duration: float = 900.0
@export var quota_target: int = 20

var round_active: bool = false
var round_success: bool = false
var _quota_manager_ref: Node3D = null

@onready var timer: Timer = $Timer


func _ready() -> void:
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)
	_try_find_quota_manager()
	GDSync.expose_func(_apply_synced_state)
	GDSync.expose_func(_apply_restart)

	if GDSync.is_host():
		timer.start(round_duration)
		round_active = true
		_sync_state_to_clients()


func _try_find_quota_manager() -> void:
	if _quota_manager_ref:
		return
	var qm := get_node_or_null("/root/main/QuotaManager")
	if qm:
		_quota_manager_ref = qm
		qm.quota_updated.connect(_on_quota_updated)


func _on_quota_updated(value: int) -> void:
	if not GDSync.is_host():
		return
	if not round_active:
		return
	if value >= quota_target:
		_end_round(true)


func _on_timer_timeout() -> void:
	if not GDSync.is_host():
		return
	if not round_active:
		return
	_end_round(false)


func _end_round(success: bool) -> void:
	round_active = false
	round_success = success
	timer.stop()
	round_ended.emit(success)
	_sync_state_to_clients()


func _sync_state_to_clients() -> void:
	if not GDSync.is_host():
		return
	GDSync.call_func_all(_apply_synced_state, round_active, round_success)


func restart_round() -> void:
	if not GDSync.is_host():
		return
	round_active = true
	round_success = false
	timer.start(round_duration)
	_sync_state_to_clients()

	var qm := get_node_or_null("/root/main/QuotaManager")
	if qm:
		GDSync.call_func_all(qm._sync_quota, 0)

	var dm := get_node_or_null("/root/main/DangerManager")
	if dm:
		dm.reset_for_restart()

	GDSync.call_func_all(_apply_restart)


func _apply_restart() -> void:
	round_active = true
	round_success = false

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


func _apply_synced_state(active: bool, success: bool = false) -> void:
	var was_active := round_active
	round_active = active
	round_success = success
	if was_active and not active:
		round_ended.emit(success)
