extends Node3D

signal quota_updated(value: int)

var shared_quota: int = 0


@rpc("any_peer", "call_remote", "reliable")
func report_catch(amount: int) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	shared_quota += amount
	if multiplayer.has_multiplayer_peer():
		_sync_quota.rpc(shared_quota)


func apply_penalty(amount: int) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	shared_quota = max(0, shared_quota - amount)
	if multiplayer.has_multiplayer_peer():
		_sync_quota.rpc(shared_quota)


@rpc("authority", "call_local", "reliable")
func _sync_quota(value: int) -> void:
	shared_quota = value
	quota_updated.emit(value)
