extends Node3D

signal quota_updated(value: int)

var shared_quota: int = 0


func _ready() -> void:
	GDSync.expose_func(report_catch)
	GDSync.expose_func(_sync_quota)


func report_catch(amount: int) -> void:
	if not GDSync.is_host():
		return
	shared_quota += amount
	GDSync.call_func_all(_sync_quota, [shared_quota])


func apply_penalty(amount: int) -> void:
	if not GDSync.is_host():
		return
	shared_quota = max(0, shared_quota - amount)
	GDSync.call_func_all(_sync_quota, [shared_quota])


func _sync_quota(value: int) -> void:
	shared_quota = value
	quota_updated.emit(value)
