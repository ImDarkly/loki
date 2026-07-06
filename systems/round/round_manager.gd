extends Node3D

signal round_ended(success: bool)

@export var round_duration: float = 900.0
@export var quota_target: int = 20

var round_active: bool = false
var _quota_manager_ref: Node3D = null

@onready var timer: Timer = $Timer


func _ready() -> void:
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)
	_try_find_quota_manager()

	if GDSync.is_host():
		timer.start(round_duration)
		round_active = true


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
	timer.stop()
	round_ended.emit(success)
