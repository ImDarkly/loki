extends Node3D

signal round_ended(success: bool)

@export var round_duration: float = 900.0
@export var quota_target: int = 20

var round_active: bool = false
var round_success: bool = false

@export var quota_manager: Node3D = null

@onready var timer: Timer = $Timer


func _ready() -> void:
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)
	if quota_manager:
		quota_manager.quota_updated.connect(_on_quota_updated)
	GDSync.expose_func(_apply_synced_state)

	if GDSync.is_host():
		timer.start(round_duration)
		round_active = true
		_sync_state_to_clients()


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


func _apply_synced_state(active: bool, success: bool = false) -> void:
	var was_active := round_active
	round_active = active
	round_success = success
	if was_active and not active:
		round_ended.emit(success)
