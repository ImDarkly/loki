class_name PlayerFishingAnimation extends Node

enum State { IDLE, CAST, WAIT, BITE, REEL, STRUGGLE, TUG, CATCH }

const FISHING_IDLE := 0
const FISHING_CASTING := 1
const FISHING_WAITING := 2
const FISHING_BITE := 3
const FISHING_SUCCESS := 4
const PLAYER_HOOK := 2

var _state: State = State.IDLE
var _rig_ready := false
var _snapshot_requested := false

@onready var _visual_rig := get_parent() as PlayerVisualRig
@onready var _player := _visual_rig.get_parent() as Player


func _ready() -> void:
	set_multiplayer_authority(1)
	_visual_rig.rig_ready.connect(_on_rig_ready)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _exit_tree() -> void:
	if _visual_rig and _visual_rig.rig_ready.is_connected(_on_rig_ready):
		_visual_rig.rig_ready.disconnect(_on_rig_ready)
	if multiplayer.has_multiplayer_peer() and multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)


func _physics_process(_delta: float) -> void:
	_request_snapshot_when_connected()
	if _player == null:
		return
	if multiplayer.has_multiplayer_peer() and _player.get_multiplayer_authority() != multiplayer.get_unique_id():
		return
	var next_state := _derive_state()
	if next_state == _state:
		return
	_set_state(next_state)
	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			_record_state(next_state)
		else:
			_submit_state.rpc_id(1, next_state)


func get_fishing_state() -> State:
	return _state


func reset() -> void:
	_set_state(State.IDLE)
	if not multiplayer.has_multiplayer_peer():
		return
	if multiplayer.is_server():
		_record_state(State.IDLE)
		return
	if _player and _player.get_multiplayer_authority() == multiplayer.get_unique_id():
		_submit_state.rpc_id(1, State.IDLE)


func _derive_state() -> State:
	if _player.player_state != Player.PlayerState.ALIVE:
		return State.IDLE
	var fishing := _player.fishing_mechanic as Node
	if fishing == null:
		return State.IDLE
	var fishing_state: int = fishing.current_state
	if fishing_state == FISHING_SUCCESS:
		return State.CATCH
	if fishing_state == FISHING_IDLE:
		return State.IDLE
	if fishing_state == FISHING_CASTING:
		return State.CAST
	if fishing_state == FISHING_WAITING:
		return State.WAIT
	if fishing_state == FISHING_BITE and not fishing.is_fighting():
		return State.BITE
	if fishing.hook_type == PLAYER_HOOK:
		if _player._pull_spike_timer > 0.0 or fishing._pull_spike_timer > 0.0:
			return State.TUG
		return State.STRUGGLE
	if _player._pull_spike_timer > 0.0 or fishing._pull_spike_timer > 0.0:
		return State.TUG
	return State.REEL


@rpc("any_peer", "reliable", "call_remote")
func _submit_state(state: State) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id != _player.get_multiplayer_authority() or state < State.IDLE or state > State.CATCH:
		_apply_synced_state.rpc_id(sender_id, _state)
		return
	_record_state(state)


func _record_state(state: State) -> void:
	if state != _state:
		_set_state(state)
	_apply_synced_state.rpc(state)


@rpc("any_peer", "reliable", "call_local")
func _apply_synced_state(state: State) -> void:
	if multiplayer.has_multiplayer_peer():
		var sender_id := multiplayer.get_remote_sender_id()
		if multiplayer.is_server():
			if sender_id != 0:
				return
		else:
			if sender_id != 1:
				return
			if _player and _player.get_multiplayer_authority() == multiplayer.get_unique_id():
				return
	if state < State.IDLE or state > State.CATCH:
		return
	if state != _state:
		_set_state(state)


@rpc("any_peer", "reliable", "call_remote")
func _request_snapshot() -> void:
	if not multiplayer.is_server():
		return
	_apply_synced_state.rpc_id(multiplayer.get_remote_sender_id(), _state)


func _request_snapshot_when_connected() -> void:
	if not _snapshot_requested and multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		_snapshot_requested = true
		_request_snapshot.rpc_id(1)


func _set_state(state: State) -> void:
	_state = state
	if _rig_ready and _visual_rig:
		_visual_rig.apply_fishing_state(state)


func _on_rig_ready() -> void:
	_rig_ready = true
	_visual_rig.apply_fishing_state(_state)


func _on_peer_disconnected(id: int) -> void:
	if _player and _player.get_multiplayer_authority() == id:
		_record_state(State.IDLE)
