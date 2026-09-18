class_name NetworkSyncComponent extends Node

var _player: Player = null
var _fishing: Node = null
var _sync_tick: int = 0
var _last_fish_state: int = -1
var _last_cast_target: Vector3 = Vector3.ZERO
var _last_flight_duration: float = 0.0
var _last_flight_start: Vector3 = Vector3.ZERO


func setup(p_player: Player, p_fishing: Node = null) -> void:
	_player = p_player
	_fishing = p_fishing if p_fishing else (p_player.fishing_mechanic if p_player and "fishing_mechanic" in p_player else null)


func push_transform(pos: Vector3, rot: Vector3, head_rot: Vector3) -> void:
	_sync_tick += 1
	if _sync_tick >= 2:
		_sync_tick = 0
		if multiplayer.has_multiplayer_peer():
			_sync_transform.rpc(pos, rot, head_rot)


func push_fishing_state(state: int) -> void:
	if state != _last_fish_state:
		_last_fish_state = state
		if multiplayer.has_multiplayer_peer():
			_sync_fishing_state.rpc(state)


func push_cast_target(pos: Vector3) -> void:
	if pos != _last_cast_target:
		_last_cast_target = pos
		if multiplayer.has_multiplayer_peer():
			_sync_cast_target.rpc(pos)


func push_flight(dur: float, start: Vector3) -> void:
	if dur != _last_flight_duration:
		_last_flight_duration = dur
		if multiplayer.has_multiplayer_peer():
			_sync_flight_duration.rpc(dur)
	if start != _last_flight_start:
		_last_flight_start = start
		if multiplayer.has_multiplayer_peer():
			_sync_flight_start.rpc(start)


@rpc("any_peer", "unreliable", "call_remote")
func sync_yelling(new_is_yelling: bool) -> void:
	if _player:
		_player.is_yelling = new_is_yelling


@rpc("authority", "unreliable", "call_remote")
func _sync_transform(pos: Vector3, rot: Vector3, head_rot: Vector3) -> void:
	if _player:
		_player.global_position = pos
		_player.rotation = rot
		if _player.head:
			_player.head.rotation = head_rot


@rpc("authority", "reliable", "call_remote")
func _sync_fishing_state(state: int) -> void:
	if _fishing and "current_state" in _fishing:
		_fishing.current_state = state


@rpc("authority", "reliable", "call_remote")
func _sync_cast_target(pos: Vector3) -> void:
	if _fishing and "cast_target_position" in _fishing:
		_fishing.cast_target_position = pos


@rpc("authority", "reliable", "call_remote")
func _sync_flight_duration(dur: float) -> void:
	if _fishing and "_current_flight_duration" in _fishing:
		_fishing._current_flight_duration = dur


@rpc("authority", "reliable", "call_remote")
func _sync_flight_start(pos: Vector3) -> void:
	if _fishing and "_flight_start_position" in _fishing:
		_fishing._flight_start_position = pos


@rpc("any_peer", "reliable", "call_remote")
func _sync_floating_state() -> void:
	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			return
		if multiplayer.get_remote_sender_id() != 1:
			return
	if _player:
		_player._enter_floating()


@rpc("any_peer", "reliable", "call_remote")
func _sync_player_state(state: int) -> void:
	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			return
		if multiplayer.get_remote_sender_id() != 1:
			return
	if not _player:
		return
	if state == Player.PlayerState.FLOATING:
		_player._water_report_retry = 0
		_player._enter_floating()
	elif state == Player.PlayerState.ALIVE:
		_player.player_state = Player.PlayerState.ALIVE
		_player._entered_water_reported = false
		_player._water_report_retry = 0
		_player._fell_off_island_reported = false
		_player._float_time = 0.0
	elif state == Player.PlayerState.SPECTATE:
		_player.player_state = Player.PlayerState.SPECTATE


@rpc("any_peer", "reliable", "call_remote")
func report_fell_off_island(_fell_position: Vector3) -> void:
	if _player and _player._movement_component:
		_player._movement_component._apply_fall_death(_fell_position)


@rpc("any_peer", "reliable", "call_remote")
func report_entered_water(_fell_position: Vector3) -> void:
	if _player and _player._movement_component:
		_player._movement_component._apply_enter_water(_fell_position)
