class_name CameraComponent extends Node

@export var mouse_sensitivity: float = 0.002
@export var hand_follow_speed_left: float = 8.0
@export var hand_follow_speed_right: float = 5.0
@export var yaw_speed_variation: float = 4.0
@export var walk_squish_strength: float = 0.05
@export var walk_squish_decay: float = 8.0
@export var shake_lateral: float = 0.01
@export var shake_vertical: float = 0.0075
@export var shake_forward: float = 0.005
@export var shake_roll: float = 0.0025
@export var shake_speed_lateral: float = 12.0
@export var shake_speed_vertical: float = 10.0
@export var shake_speed_forward: float = 8.0
@export var shake_speed_roll: float = 14.0
@export var jump_bounce_impulse: float = 0.3
@export var land_bounce_impulse: float = 0.18
@export var bounce_stiffness: float = 50.0
@export var bounce_damping: float = 8.0
@export var hand_jump_raise: float = 0.03
@export var hand_land_drop: float = 0.025
@export var hand_bounce_decay: float = 10.0

var _player: Player = null
var _head: Node3D = null
var _camera: Camera3D = null
var _hand_left: MeshInstance3D = null
var _hand_right: MeshInstance3D = null
var _spectate_camera: Node3D = null
var _spectate_cam_camera: Camera3D = null
var _players_container: Node = null

var _cam_home: Vector3 = Vector3.ZERO
var _bounce_pos: float = 0.0
var _bounce_vel: float = 0.0
var _hand_bounce: float = 0.0
var _walk_squish_offset: float = 0.0
var _prev_yaw: float = 0.0
var _was_moving: bool = false
var _hand_base_left: Vector3 = Vector3.ZERO
var _hand_base_right: Vector3 = Vector3.ZERO

var _spectate_yaw: float = 0.0
var _spectate_pitch: float = 0.0
var _spectate_target: Node3D = null
var _spectate_target_index: int = 0


func setup(p_player: Player, p_head: Node3D = null, p_camera: Camera3D = null, p_hand_left: MeshInstance3D = null, p_hand_right: MeshInstance3D = null, p_spectate_camera: Node3D = null, p_spectate_cam_camera: Camera3D = null, p_players_container: Node = null) -> void:
	_player = p_player
	_head = p_head if p_head else (p_player.head if p_player and "head" in p_player else null)
	_camera = p_camera if p_camera else (p_player.camera if p_player and "camera" in p_player else null)
	_hand_left = p_hand_left if p_hand_left else (p_player.hand_left if p_player and "hand_left" in p_player else null)
	_hand_right = p_hand_right if p_hand_right else (p_player.hand_right if p_player and "hand_right" in p_player else null)
	_spectate_camera = p_spectate_camera if p_spectate_camera else (p_player.spectate_camera if p_player and "spectate_camera" in p_player else null)
	_spectate_cam_camera = p_spectate_cam_camera if p_spectate_cam_camera else (p_player.spectate_cam_camera if p_player and "spectate_cam_camera" in p_player else null)
	_players_container = p_players_container if p_players_container else (p_player._players_container if p_player and "_players_container" in p_player else get_node_or_null("/root/main/Players"))
	if _hand_left:
		_hand_base_left = _hand_left.position
	if _hand_right:
		_hand_base_right = _hand_right.position
	if _camera:
		_cam_home = _camera.position


func tick_physics(delta: float, linear_velocity: Vector3) -> void:
	var speed := Vector2(linear_velocity.x, linear_velocity.z).length()
	var t := Time.get_ticks_msec() / 1000.0

	var spring_force := -_bounce_pos * bounce_stiffness
	_bounce_vel += (spring_force - _bounce_vel * bounce_damping) * delta
	_bounce_pos += _bounce_vel * delta

	var shake_pos := Vector3.ZERO
	var shake_rot: float = 0.0

	if speed > 0.1:
		shake_pos = Vector3(
			sin(t * shake_speed_lateral) * shake_lateral,
			cos(t * shake_speed_vertical) * shake_vertical,
			sin(t * shake_speed_forward) * shake_forward
		)
		shake_rot = sin(t * shake_speed_roll) * shake_roll

	if _camera:
		_camera.position = _cam_home + shake_pos + Vector3(0, _bounce_pos, 0)
		_camera.rotation.z = shake_rot

	var is_moving := speed > 0.1
	if is_moving and not _was_moving:
		_walk_squish_offset = -walk_squish_strength
	_walk_squish_offset = lerp(_walk_squish_offset, 0.0, walk_squish_decay * delta)
	_was_moving = is_moving

	var yaw_delta: float = fmod(_player.rotation.y - _prev_yaw, TAU) if _player else 0.0
	if yaw_delta > PI:
		yaw_delta -= TAU
	elif yaw_delta < -PI:
		yaw_delta += TAU
	var yaw_sign: float = sign(yaw_delta)
	var speed_l: float = hand_follow_speed_left + yaw_sign * yaw_speed_variation
	var speed_r: float = hand_follow_speed_right - yaw_sign * yaw_speed_variation

	var pitch_factor: float = (_head.rotation.x / deg_to_rad(89.0)) if _head else 0.0
	var target_y: float = _hand_base_left.y + pitch_factor * 0.04 + _walk_squish_offset + _hand_bounce
	if _hand_left:
		_hand_left.position.y = lerp(_hand_left.position.y, target_y, speed_l * delta)
	if _hand_right:
		_hand_right.position.y = lerp(_hand_right.position.y, target_y, speed_r * delta)

	var yaw_sway: float = -yaw_delta * 2.0
	if _hand_left:
		_hand_left.position.x = lerp(_hand_left.position.x, _hand_base_left.x + yaw_sway, speed_l * delta)
	if _hand_right:
		_hand_right.position.x = lerp(_hand_right.position.x, _hand_base_right.x + yaw_sway, speed_r * delta)

	_hand_bounce = lerp(_hand_bounce, 0.0, hand_bounce_decay * delta)

	if _player:
		_prev_yaw = _player.rotation.y


func tick_process(delta: float) -> void:
	_update_spectate_camera(delta)


func _update_spectate_camera(_delta: float) -> void:
	if _spectate_target == null or not is_instance_valid(_spectate_target):
		_spectate_target = _find_spectate_target()
	elif _spectate_target != _player:
		var hp := _spectate_target.get_node_or_null("HealthComponent") as HealthComponent
		if hp == null or not hp.is_alive():
			_spectate_target = _find_spectate_target()
	var target := _spectate_target if _spectate_target != null else _player
	if target and _spectate_camera and _spectate_cam_camera:
		_spectate_camera.global_position = target.global_position
		_spectate_cam_camera.look_at(target.global_position + Vector3(0, 1.0, 0))


func _find_spectate_target() -> Node3D:
	if _players_container == null:
		return null
	for child in _players_container.get_children():
		if child == _player:
			continue
		var hp := child.get_node_or_null("HealthComponent") as HealthComponent
		if hp and hp.is_alive():
			return child
	return null


func _get_alive_players() -> Array[Node3D]:
	var alive: Array[Node3D] = []
	if _players_container == null:
		return alive
	for child in _players_container.get_children():
		if child == _player:
			continue
		var hp := child.get_node_or_null("HealthComponent") as HealthComponent
		if hp and hp.is_alive():
			alive.append(child)
	return alive


func cycle_spectate_target() -> void:
	var alive := _get_alive_players()
	if alive.is_empty():
		_spectate_target = null
		return
	var current_index := alive.find(_spectate_target)
	if current_index == -1:
		current_index = _spectate_target_index
	_spectate_target_index = (current_index + 1) % alive.size()
	_spectate_target = alive[_spectate_target_index]
