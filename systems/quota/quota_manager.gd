extends Node3D

signal quota_updated(value: int)

var shared_quota: int = 0


func _ready() -> void:
	if OS.is_debug_build():
		var dbg = get_node_or_null("/root/DebugOverlay")
		if dbg:
			dbg.register_system(name, self)


func get_debug_state() -> Dictionary:
	return {
		"shared_quota": shared_quota
	}


func get_debug_actions() -> Array[Dictionary]:
	return [
		{"id": "add_quota_10", "label": "+10 Quota"},
		{"id": "clear_quota", "label": "Clear Quota"}
	]


func debug_action(action_id: String) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	match action_id:
		"add_quota_10":
			report_catch(10)
		"clear_quota":
			apply_penalty(shared_quota)


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
