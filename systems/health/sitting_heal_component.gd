class_name SittingHealComponent extends Node

const FULL_HEAL_FRACTION: float = 10.0

var is_sitting: bool = false

var _heal_progress: float = 0.0
var _tick_interval: float = 1.0
var _health: HealthComponent = null


func _ready() -> void:
	_health = get_parent().get_node_or_null("HealthComponent") as HealthComponent


func _process(delta: float) -> void:
	if not is_sitting:
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	_accumulate(delta)


func toggle_sitting() -> void:
	set_sitting(not is_sitting)


func set_sitting(sitting: bool) -> void:
	if is_sitting == sitting:
		return
	is_sitting = sitting
	if sitting:
		_recompute_tick_interval()
	if multiplayer.has_multiplayer_peer():
		_sync_sitting.rpc(is_sitting, _tick_interval)


@rpc("any_peer", "unreliable", "call_remote")
func _sync_sitting(sitting: bool, tick_interval: float = 0.0) -> void:
	is_sitting = sitting
	if sitting and tick_interval > 0.0:
		_tick_interval = tick_interval


func reset() -> void:
	set_sitting(false)
	_heal_progress = 0.0


func _recompute_tick_interval() -> void:
	var round_duration := 900.0
	var rm := get_node_or_null("/root/main/RoundManager")
	if rm:
		round_duration = rm.round_duration
	var max_hp := 1
	if _health:
		max_hp = _health.max_health
	_tick_interval = (round_duration / FULL_HEAL_FRACTION) / max_hp


func _accumulate(delta: float) -> void:
	if not is_sitting or not _health:
		return
	if _health.current_health >= _health.max_health:
		_heal_progress = 0.0
		return
	_heal_progress += delta / _tick_interval
	var healed := int(_heal_progress)
	if healed > 0:
		_heal_progress -= healed
		_health.heal(healed)