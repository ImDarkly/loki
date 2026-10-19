class_name PlayerLocomotionAnimation extends Node

enum State { IDLE, WALK, JUMP, AIRBORNE, LAND }

const MOVEMENT_THRESHOLD := 0.1
const LAND_MIN_SECONDS := 0.15

var _state: State = State.IDLE
var _was_airborne := false
var _rig_ready := false
var _land_time_left := 0.0
var _snapshot_requested := false

@onready var _visual_rig := get_parent() as PlayerVisualRig
@onready var _player := _visual_rig.get_parent() as Player


func _ready() -> void:
	set_multiplayer_authority(1)
	_visual_rig.rig_ready.connect(_on_rig_ready)


func _exit_tree() -> void:
	if _visual_rig and _visual_rig.rig_ready.is_connected(_on_rig_ready):
		_visual_rig.rig_ready.disconnect(_on_rig_ready)


func _physics_process(delta: float) -> void:
	_request_snapshot_when_connected()
	if _player == null:
		return
	if multiplayer.has_multiplayer_peer() and _player.get_multiplayer_authority() != multiplayer.get_unique_id():
		return
	if _land_time_left > 0.0:
		_land_time_left -= delta
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


func get_locomotion_state() -> State:
	return _state


func _derive_state() -> State:
	if not _player.is_on_floor():
		_was_airborne = true
		return State.JUMP if _player.velocity.y > 0.0 else State.AIRBORNE
	if _was_airborne:
		_was_airborne = false
		return State.LAND
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	return State.WALK if speed > MOVEMENT_THRESHOLD else State.IDLE


@rpc("any_peer", "reliable", "call_remote")
func _submit_state(state: State) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id != _player.get_multiplayer_authority():
		_apply_synced_state.rpc_id(sender_id, _state)
		return
	if state < State.IDLE or state > State.LAND:
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
	if state == State.LAND:
		_land_time_left = max(LAND_MIN_SECONDS, _visual_rig.get_locomotion_animation_length(state))
	_apply_state(state)


func _apply_state(state: State) -> void:
	if _rig_ready and _visual_rig:
		_visual_rig.apply_locomotion_state(state)


func _on_rig_ready() -> void:
	_rig_ready = true
	_apply_state(_state)
