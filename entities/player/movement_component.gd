class_name MovementComponent extends Node

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_boost: float = 1.2
@export var accel_factor: float = 10.0
@export var jump_height: float = 1.1
@export var coyote_time: float = 0.10
@export var jump_buffer_time: float = 0.12
@export var fall_gravity_multiplier: float = 1.5
@export var jump_cut_multiplier: float = 0.5
@export var launch_vertical_boost: float = 2.0
@export var max_cast_range: float = 20.0

const GROUND_BRAKE_RATE: float = 60.0
const AIR_DRAG_RATE: float = 10.0
const STOP_SNAP_THRESHOLD: float = 0.05
const DEADZONE: float = 0.15
const FALL_DEATH_Y: float = -3.0
const WATER_SURFACE_Y: float = -0.5
const UP = Vector3.UP

var _player: Player = null
var _head: Node3D = null
var _fishing: Node = null
var _sitting: SittingHealComponent = null
var _slap: SlapComponent = null
var _net_sync: NetworkSyncComponent = null
var _camera_comp: CameraComponent = null

var _pending_yaw: float = 0.0
var _pending_pitch: float = 0.0
var _pending_launch: Vector3 = Vector3.ZERO
var _coyote_clock: float = 0.0
var _jump_buffer_t: float = -999.0
var _jump_hold_frames: int = 0
var _jump_requested: bool = false
var _was_grounded: bool = false
var _pull_spike_timer: float = 0.0
var _float_time: float = 0.0
var _float_base_y: float = -0.5
var float_timeout: float = 30.0
var float_drift_speed: float = 1.0
var float_bob_amplitude: float = 0.12
var float_bob_frequency: float = 0.9
var _fell_off_island_reported: bool = false
var _entered_water_reported: bool = false
var _water_report_retry: int = 0
var _last_fish_state: int = -1
var _last_cast_target: Vector3 = Vector3.ZERO


func setup(p_player: Player, p_head: Node3D = null, p_fishing: Node = null, p_sitting: SittingHealComponent = null, p_slap: SlapComponent = null, p_net_sync: NetworkSyncComponent = null, p_camera_comp: CameraComponent = null) -> void:
	_player = p_player
	_head = p_head if p_head else (p_player.head if p_player and "head" in p_player else null)
	_fishing = p_fishing if p_fishing else (p_player.fishing_mechanic if p_player and "fishing_mechanic" in p_player else null)
	_sitting = p_sitting if p_sitting else (p_player._sitting_heal if p_player and "_sitting_heal" in p_player else null)
	_slap = p_slap if p_slap else (p_player._slap_component if p_player and "_slap_component" in p_player else null)
	_net_sync = p_net_sync if p_net_sync else (p_player._net_sync if p_player and "_net_sync" in p_player else null)
	_camera_comp = p_camera_comp if p_camera_comp else (p_player._camera_comp if p_player and "_camera_comp" in p_player else null)


func _current_max_speed() -> float:
	if Input.is_action_pressed("sprint"):
		return sprint_speed
	return walk_speed


func _is_grounded(state: PhysicsDirectBodyState3D) -> bool:
	var vel_y := state.linear_velocity.y if state != null else (_player.linear_velocity.y if _player else 0.0)
	if _was_grounded and abs(vel_y) < 0.2:
		return true
	if state != null:
		for i in range(state.get_contact_count()):
			var normal := state.get_contact_local_normal(i)
			if normal.y > 0.5:
				return true
	var space_state := _player.get_world_3d().direct_space_state if _player and _player.get_world_3d() else null
	if space_state:
		var origin := _player.global_position + Vector3(0, 0.1, 0)
		var params := PhysicsRayQueryParameters3D.new()
		params.from = origin
		params.to = origin + Vector3(0, -0.5, 0)
		params.collision_mask = 1 << 0
		params.exclude = [_player.get_rid()]
		var result := space_state.intersect_ray(params)
		if result:
			return true
	return false


func _check_fell_off_island() -> void:
	if not _player or _player.player_state != Player.PlayerState.ALIVE:
		return
	if _player.has_method("_is_local_authority") and not _player._is_local_authority():
		return
	if _player.global_position.y < FALL_DEATH_Y:
		if _fell_off_island_reported:
			return
		_fell_off_island_reported = true
		if _net_sync:
			if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
				_net_sync.report_fell_off_island.rpc(_player.global_position)
			else:
				_apply_fall_death(_player.global_position)
		elif multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
			_player.report_fell_off_island.rpc(_player.global_position)
		else:
			_apply_fall_death(_player.global_position)
	elif _player.global_position.y < WATER_SURFACE_Y:
		if _entered_water_reported:
			_water_report_retry += 1
			if _water_report_retry < 15:
				return
			_water_report_retry = 0
		else:
			_entered_water_reported = true
		if multiplayer.has_multiplayer_peer():
			if not multiplayer.is_server():
				if _net_sync:
					_net_sync.report_entered_water.rpc(_player.global_position)
				else:
					_player.report_entered_water.rpc(_player.global_position)
			else:
				_apply_enter_water(_player.global_position)
		else:
			_apply_enter_water(_player.global_position)


func _apply_fall_death(_fell_position: Vector3) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var server_below := _player and _player.global_position.y < FALL_DEATH_Y
	var client_below := _fell_position.y < FALL_DEATH_Y
	if not (server_below or client_below):
		return
	if _player and _player.player_state != Player.PlayerState.ALIVE:
		return
	var health_comp := _player.get_node_or_null("HealthComponent") as HealthComponent
	if health_comp:
		health_comp.take_damage(health_comp.max_health)


func _apply_enter_water(_fell_position: Vector3) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var server_in_water := _player and _player.global_position.y < WATER_SURFACE_Y and _player.global_position.y >= FALL_DEATH_Y
	var client_in_water := _fell_position.y < WATER_SURFACE_Y and _fell_position.y >= FALL_DEATH_Y
	if not (server_in_water or client_in_water):
		return
	if _player and _player.player_state != Player.PlayerState.ALIVE:
		return
	_player._enter_floating()


func _process_floating(state: PhysicsDirectBodyState3D) -> void:
	var delta := state.step
	_float_time += delta
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		if _float_time >= float_timeout:
			var health_comp := _player.get_node_or_null("HealthComponent") as HealthComponent
			if health_comp:
				health_comp.take_damage(health_comp.max_health)
			return
	var flat_pos := Vector2(state.transform.origin.x, state.transform.origin.z)
	var center_2d := Vector2(MapConfig.MAP_CENTER.x, MapConfig.MAP_CENTER.z)
	var dir := (flat_pos - center_2d)
	if dir.length() < 0.001:
		dir = Vector2(1.0, 0.0)
	else:
		dir = dir.normalized()
	var drift := dir * float_drift_speed
	state.linear_velocity = Vector3(drift.x, 0.0, drift.y)
	var bob := _float_base_y + sin(_float_time * TAU * float_bob_frequency) * float_bob_amplitude
	var t := state.transform
	t.origin.y = bob
	state.transform = t

	if _net_sync:
		_net_sync._sync_tick += 1
		if _net_sync._sync_tick >= 2:
			_net_sync._sync_tick = 0
			if multiplayer.has_multiplayer_peer() and _player._is_local_authority():
				_net_sync._sync_transform.rpc(_player.global_position, _player.rotation, _head.rotation)


func integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not _player or not _player._is_local_authority():
		return

	if _player.player_state == Player.PlayerState.SPECTATE:
		_pending_yaw = 0.0
		_pending_pitch = 0.0
		if _player.global_position.y <= FALL_DEATH_Y:
			state.linear_velocity = Vector3.ZERO
			return
		var grounded := _is_grounded(state)
		var vel := state.linear_velocity
		if not grounded:
			vel.y -= _player.gravity * state.step
		else:
			vel.x = 0.0
			vel.z = 0.0
		state.linear_velocity = vel
		if _net_sync:
			_net_sync._sync_tick += 1
			if _net_sync._sync_tick >= 2:
				_net_sync._sync_tick = 0
				if multiplayer.has_multiplayer_peer():
					_net_sync._sync_transform.rpc(_player.global_position, _player.rotation, _head.rotation)
			var fs: int = _fishing.current_state if _fishing and "current_state" in _fishing else 0
			if fs != _net_sync._last_fish_state:
				_net_sync._last_fish_state = fs
				if multiplayer.has_multiplayer_peer():
					_net_sync._sync_fishing_state.rpc(fs)
			var ct: Vector3 = _fishing.cast_target_position if _fishing and "cast_target_position" in _fishing else Vector3.ZERO
			if ct != _net_sync._last_cast_target:
				_net_sync._last_cast_target = ct
				if multiplayer.has_multiplayer_peer():
					_net_sync._sync_cast_target.rpc(ct)
		return

	if _pending_yaw != 0.0:
		var t := state.transform
		t.basis = Basis(UP, _pending_yaw) * t.basis
		state.transform = t
		_pending_yaw = 0.0
	if _pending_pitch != 0.0 and _head:
		_head.rotation.x = clamp(_head.rotation.x + _pending_pitch, deg_to_rad(-89.0), deg_to_rad(89.0))
		_pending_pitch = 0.0

	if _player.player_state == Player.PlayerState.FLOATING:
		_process_floating(state)
		return

	if _player.is_slapped:
		var vel := state.linear_velocity
		vel.x = 0.0
		vel.z = 0.0
		var grounded := _is_grounded(state)
		if not grounded:
			var mult := fall_gravity_multiplier if vel.y < 0 else 1.0
			vel.y -= _player.gravity * mult * state.step
		else:
			vel.y = 0.0
		state.linear_velocity = vel
		_check_fell_off_island()
		if _net_sync:
			_net_sync._sync_tick += 1
			if _net_sync._sync_tick >= 2:
				_net_sync._sync_tick = 0
				if multiplayer.has_multiplayer_peer() and _player._is_local_authority():
					_net_sync._sync_transform.rpc(_player.global_position, _player.rotation, _head.rotation)
		return

	if _sitting and _sitting.is_sitting:
		_jump_requested = false
		_jump_buffer_t = -999.0
		var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back", DEADZONE)
		if input_dir.length() < DEADZONE:
			input_dir = Vector2.ZERO
		if input_dir != Vector2.ZERO:
			if _player.assigned_fireplace and _player.assigned_fireplace.has_method("release_seat_for_player"):
				_player.assigned_fireplace.release_seat_for_player(_player)
			_sitting.set_sitting(false)
		else:
			var vel := state.linear_velocity
			vel.x = 0.0
			vel.z = 0.0
			var grounded := _is_grounded(state)
			if not grounded:
				vel.y -= _player.gravity * state.step
			else:
				vel.y = 0.0
			state.linear_velocity = vel
			return

	if _fishing and _fishing.has_method("is_fighting") and _fishing.is_fighting():
		_jump_requested = false
		_jump_buffer_t = -999.0
		var grounded := _is_grounded(state)
		var vel := state.linear_velocity
		if not grounded:
			var mult := fall_gravity_multiplier if vel.y < 0 else 1.0
			vel.y -= _player.gravity * mult * state.step

		var fish_pos: Vector3 = _fishing.cast_target_position
		var to_fish: Vector3 = fish_pos - _player.global_position
		var dist: float = to_fish.length()
		var dir: Vector3 = to_fish.normalized() if dist > 0.001 else Vector3.FORWARD

		var initial_dist: float = max(_fishing._fight_initial_distance, 0.01)
		var pull_mult: float = clamp(dist / initial_dist, 0.1, 1.0)
		_pull_spike_timer = max(0.0, _pull_spike_timer - state.step)
		if Input.is_action_just_pressed("reel_fight"):
			_pull_spike_timer = 0.3
			_fishing.notify_scroll()
		var is_spiked: bool = _pull_spike_timer > 0
		var current_pull: float = _fishing.fighting_spike_pull if is_spiked else _fishing.fighting_pull_strength
		var pull_force: Vector3 = dir * current_pull * pull_mult

		_fishing.advance_fight(state.step)
		if not _fishing._is_fighting:
			var exit_vel := state.linear_velocity
			exit_vel.x = 0.0
			exit_vel.z = 0.0
			state.linear_velocity = exit_vel
			return

		var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back", DEADZONE)
		if input_dir.length() < DEADZONE:
			input_dir = Vector2.ZERO
		var wasd_dir := (_player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		var wasd_scale: float = 0.2 if is_spiked else 1.0
		var wasd_force := wasd_dir * _current_max_speed() * wasd_scale

		vel.x = pull_force.x + wasd_force.x
		vel.z = pull_force.z + wasd_force.z
		state.linear_velocity = vel

		_check_fell_off_island()

		if _net_sync:
			_net_sync._sync_tick += 1
			if _net_sync._sync_tick >= 2:
				_net_sync._sync_tick = 0
				if multiplayer.has_multiplayer_peer():
					_net_sync._sync_transform.rpc(_player.global_position, _player.rotation, _head.rotation)

			var fs: int = _fishing.current_state
			if fs != _net_sync._last_fish_state:
				_net_sync._last_fish_state = fs
				if multiplayer.has_multiplayer_peer():
					_net_sync._sync_fishing_state.rpc(fs)
		return

	if _pending_launch != Vector3.ZERO:
		state.linear_velocity = Vector3.ZERO
		state.apply_central_impulse(_pending_launch * _player.mass)
		_pending_launch = Vector3.ZERO

	var grounded := _is_grounded(state)

	if grounded:
		_coyote_clock = 0.0
	else:
		_coyote_clock += state.step

	var prev_jump_hold_frames := _jump_hold_frames
	if Input.is_action_pressed("jump"):
		_jump_hold_frames += 1
	else:
		_jump_hold_frames = 0

	if Input.is_action_just_pressed("jump") or _jump_requested:
		_jump_buffer_t = jump_buffer_time
		_jump_requested = false

	if _jump_buffer_t > 0.0:
		_jump_buffer_t = max(0.0, _jump_buffer_t - state.step)

	if not grounded:
		var vel := state.linear_velocity
		var mult := fall_gravity_multiplier if vel.y < 0 else 1.0
		state.apply_central_force(Vector3.DOWN * _player.gravity * (mult - 1.0) * _player.mass)

	if (grounded or _coyote_clock <= coyote_time) and _jump_buffer_t > 0.0:
		var current_jump_height := jump_height
		if Input.is_action_pressed("sprint"):
			current_jump_height *= jump_boost
		var jump_impulse := Vector3.UP * sqrt(2.0 * _player.gravity * current_jump_height) * _player.mass
		state.apply_central_impulse(jump_impulse)
		if _camera_comp:
			_camera_comp._bounce_vel = -_camera_comp.jump_bounce_impulse
			_camera_comp._hand_bounce = _camera_comp.hand_jump_raise
		_jump_buffer_t = -999.0
		_coyote_clock = coyote_time + 1.0
		_jump_hold_frames = 0

	if Input.is_action_just_released("jump") and state.linear_velocity.y > 0.0 and prev_jump_hold_frames >= 2:
		var vel := state.linear_velocity
		vel.y *= jump_cut_multiplier
		state.linear_velocity = vel

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back", DEADZONE)
	if input_dir.length() < DEADZONE:
		input_dir = Vector2.ZERO
	var direction := (_player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction != Vector3.ZERO:
		state.apply_central_force(direction * _current_max_speed() * _player.mass * accel_factor)
	else:
		var vel := state.linear_velocity
		if grounded:
			vel.x = move_toward(vel.x, 0.0, GROUND_BRAKE_RATE * state.step)
			vel.z = move_toward(vel.z, 0.0, GROUND_BRAKE_RATE * state.step)
		else:
			vel.x = move_toward(vel.x, 0.0, AIR_DRAG_RATE * state.step)
			vel.z = move_toward(vel.z, 0.0, AIR_DRAG_RATE * state.step)
		if abs(vel.x) < STOP_SNAP_THRESHOLD:
			vel.x = 0.0
		if abs(vel.z) < STOP_SNAP_THRESHOLD:
			vel.z = 0.0
		state.linear_velocity = vel

	var max_spd := _current_max_speed()
	var horiz_vel := Vector2(state.linear_velocity.x, state.linear_velocity.z)
	if horiz_vel.length() > max_spd:
		horiz_vel = horiz_vel.normalized() * max_spd
		state.linear_velocity = Vector3(horiz_vel.x, state.linear_velocity.y, horiz_vel.y)

	_check_fell_off_island()

	if not _was_grounded and grounded and _camera_comp:
		_camera_comp._hand_bounce = -_camera_comp.hand_land_drop
		_camera_comp._bounce_vel = _camera_comp.land_bounce_impulse
	_was_grounded = grounded

	if _camera_comp:
		_camera_comp.tick_physics(state.step, state.linear_velocity)

	if _net_sync:
		_net_sync.push_transform(_player.global_position, _player.rotation, _head.rotation)
		if _fishing:
			_net_sync.push_fishing_state(_fishing.current_state)
			_net_sync.push_cast_target(_fishing.cast_target_position)
			_net_sync.push_flight(_fishing._current_flight_duration, _fishing._flight_start_position)


func reset_for_restart() -> void:
	_fell_off_island_reported = false
	_entered_water_reported = false
	_water_report_retry = 0
	_float_time = 0.0
