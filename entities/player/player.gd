class_name Player extends RigidBody3D

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var fishing_mechanic: Node3D = $FishingMechanic
@onready var hand_left: MeshInstance3D = $Head/HandLeft
@onready var hand_right: MeshInstance3D = $Head/HandRight
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var _voice_chat: Node = $VoiceChatManager
@onready var mic_level_bar: CanvasLayer = get_node_or_null("MicLevelBar")
@onready var health_label: CanvasLayer = get_node_or_null("HealthLabel")
@onready var spectate_camera: Node3D = $SpectateCamera
@onready var spectate_cam_camera: Camera3D = $SpectateCamera/Camera3D
@onready var _players_container: Node = get_node_or_null("/root/main/Players")
@onready var _health_component: HealthComponent = $HealthComponent
@onready var _sitting_heal: SittingHealComponent = $SittingHeal
@onready var _slap_component: SlapComponent = $SlapComponent
@onready var _carry_component: CarryComponent = $CarryComponent
@onready var _interaction_component: InteractionComponent = $InteractionComponent
@onready var _movement_component: MovementComponent = $MovementComponent
@onready var _camera_component: CameraComponent = $CameraComponent
@onready var _net_sync: NetworkSyncComponent = $NetworkSyncComponent

var assigned_fireplace: Node3D = null
var assigned_fireplace_seat: Node3D = null

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var is_yelling: bool = false

enum PlayerState { ALIVE, FLOATING, SPECTATE }
var player_state: PlayerState = PlayerState.ALIVE
var spawn_index: int = 0
var launch_speed: float = 15.0
var _rod_pivot: Node3D = null

var walk_speed: float:
	get: return _movement_component.walk_speed if _movement_component else 5.0
	set(val): if _movement_component: _movement_component.walk_speed = val

var sprint_speed: float:
	get: return _movement_component.sprint_speed if _movement_component else 8.0
	set(val): if _movement_component: _movement_component.sprint_speed = val

var jump_boost: float:
	get: return _movement_component.jump_boost if _movement_component else 1.2
	set(val): if _movement_component: _movement_component.jump_boost = val

var accel_factor: float:
	get: return _movement_component.accel_factor if _movement_component else 10.0
	set(val): if _movement_component: _movement_component.accel_factor = val

var jump_height: float:
	get: return _movement_component.jump_height if _movement_component else 1.1
	set(val): if _movement_component: _movement_component.jump_height = val

var coyote_time: float:
	get: return _movement_component.coyote_time if _movement_component else 0.10
	set(val): if _movement_component: _movement_component.coyote_time = val

var jump_buffer_time: float:
	get: return _movement_component.jump_buffer_time if _movement_component else 0.12
	set(val): if _movement_component: _movement_component.jump_buffer_time = val

var mouse_sensitivity: float:
	get: return _camera_component.mouse_sensitivity if _camera_component else 0.002
	set(val): if _camera_component: _camera_component.mouse_sensitivity = val

var fall_gravity_multiplier: float:
	get: return _movement_component.fall_gravity_multiplier if _movement_component else 1.5
	set(val): if _movement_component: _movement_component.fall_gravity_multiplier = val

var hand_follow_speed_left: float:
	get: return _camera_component.hand_follow_speed_left if _camera_component else 8.0
	set(val): if _camera_component: _camera_component.hand_follow_speed_left = val

var hand_follow_speed_right: float:
	get: return _camera_component.hand_follow_speed_right if _camera_component else 5.0
	set(val): if _camera_component: _camera_component.hand_follow_speed_right = val

var yaw_speed_variation: float:
	get: return _camera_component.yaw_speed_variation if _camera_component else 4.0
	set(val): if _camera_component: _camera_component.yaw_speed_variation = val

var walk_squish_strength: float:
	get: return _camera_component.walk_squish_strength if _camera_component else 0.05
	set(val): if _camera_component: _camera_component.walk_squish_strength = val

var walk_squish_decay: float:
	get: return _camera_component.walk_squish_decay if _camera_component else 8.0
	set(val): if _camera_component: _camera_component.walk_squish_decay = val

var shake_lateral: float:
	get: return _camera_component.shake_lateral if _camera_component else 0.01
	set(val): if _camera_component: _camera_component.shake_lateral = val

var shake_vertical: float:
	get: return _camera_component.shake_vertical if _camera_component else 0.0075
	set(val): if _camera_component: _camera_component.shake_vertical = val

var shake_forward: float:
	get: return _camera_component.shake_forward if _camera_component else 0.005
	set(val): if _camera_component: _camera_component.shake_forward = val

var shake_roll: float:
	get: return _camera_component.shake_roll if _camera_component else 0.0025
	set(val): if _camera_component: _camera_component.shake_roll = val

var shake_speed_lateral: float:
	get: return _camera_component.shake_speed_lateral if _camera_component else 12.0
	set(val): if _camera_component: _camera_component.shake_speed_lateral = val

var shake_speed_vertical: float:
	get: return _camera_component.shake_speed_vertical if _camera_component else 10.0
	set(val): if _camera_component: _camera_component.shake_speed_vertical = val

var shake_speed_forward: float:
	get: return _camera_component.shake_speed_forward if _camera_component else 8.0
	set(val): if _camera_component: _camera_component.shake_speed_forward = val

var shake_speed_roll: float:
	get: return _camera_component.shake_speed_roll if _camera_component else 14.0
	set(val): if _camera_component: _camera_component.shake_speed_roll = val

var jump_bounce_impulse: float:
	get: return _camera_component.jump_bounce_impulse if _camera_component else 0.3
	set(val): if _camera_component: _camera_component.jump_bounce_impulse = val

var land_bounce_impulse: float:
	get: return _camera_component.land_bounce_impulse if _camera_component else 0.18
	set(val): if _camera_component: _camera_component.land_bounce_impulse = val

var bounce_stiffness: float:
	get: return _camera_component.bounce_stiffness if _camera_component else 50.0
	set(val): if _camera_component: _camera_component.bounce_stiffness = val

var bounce_damping: float:
	get: return _camera_component.bounce_damping if _camera_component else 8.0
	set(val): if _camera_component: _camera_component.bounce_damping = val

var hand_jump_raise: float:
	get: return _camera_component.hand_jump_raise if _camera_component else 0.03
	set(val): if _camera_component: _camera_component.hand_jump_raise = val

var hand_land_drop: float:
	get: return _camera_component.hand_land_drop if _camera_component else 0.025
	set(val): if _camera_component: _camera_component.hand_land_drop = val

var hand_bounce_decay: float:
	get: return _camera_component.hand_bounce_decay if _camera_component else 10.0
	set(val): if _camera_component: _camera_component.hand_bounce_decay = val

var jump_cut_multiplier: float:
	get: return _movement_component.jump_cut_multiplier if _movement_component else 0.5
	set(val): if _movement_component: _movement_component.jump_cut_multiplier = val

var max_cast_range: float:
	get: return _movement_component.max_cast_range if _movement_component else 20.0
	set(val): if _movement_component: _movement_component.max_cast_range = val

var float_drift_speed: float:
	get: return _movement_component.float_drift_speed if _movement_component else 1.0
	set(val): if _movement_component: _movement_component.float_drift_speed = val

var float_bob_amplitude: float:
	get: return _movement_component.float_bob_amplitude if _movement_component else 0.12
	set(val): if _movement_component: _movement_component.float_bob_amplitude = val

var float_bob_frequency: float:
	get: return _movement_component.float_bob_frequency if _movement_component else 0.9
	set(val): if _movement_component: _movement_component.float_bob_frequency = val

var float_timeout: float:
	get: return _movement_component.float_timeout if _movement_component else 30.0
	set(val): if _movement_component: _movement_component.float_timeout = val

var launch_vertical_boost: float:
	get: return _movement_component.launch_vertical_boost if _movement_component else 2.0
	set(val): if _movement_component: _movement_component.launch_vertical_boost = val

var is_carrying: bool:
	get: return _carry_component.is_carrying if _carry_component else false
	set(val):
		if _carry_component and is_instance_valid(_carry_component):
			_carry_component.is_carrying = val

var holding_rock: bool:
	get: return _carry_component.holding_rock if (_carry_component and is_instance_valid(_carry_component)) else false
	set(val):
		if _carry_component and is_instance_valid(_carry_component):
			_carry_component.holding_rock = val

var holding_shark_bait: bool:
	get: return _carry_component.holding_shark_bait if (_carry_component and is_instance_valid(_carry_component)) else false
	set(val):
		if _carry_component and is_instance_valid(_carry_component):
			_carry_component.holding_shark_bait = val

var is_slapped: bool:
	get: return _slap_component.is_slapped if (_slap_component and is_instance_valid(_slap_component)) else false

var _slap_cooldown_left: float:
	get: return (_slap_component._slap_cooldown_left if (_slap_component and is_instance_valid(_slap_component)) else 0.0) as float
	set(val):
		if _slap_component and is_instance_valid(_slap_component):
			_slap_component._slap_cooldown_left = val

var _slap_time_left: float:
	get: return (_slap_component._slap_time_left if (_slap_component and is_instance_valid(_slap_component)) else 0.0) as float
	set(val):
		if _slap_component and is_instance_valid(_slap_component):
			_slap_component._slap_time_left = val

var _slap_token: int:
	get: return (_slap_component._slap_token if (_slap_component and is_instance_valid(_slap_component)) else 0) as int
	set(val):
		if _slap_component and is_instance_valid(_slap_component):
			_slap_component._slap_token = val

var slap_duration: float:
	get: return (_slap_component.slap_duration if (_slap_component and is_instance_valid(_slap_component)) else 3.5) as float
	set(val):
		if _slap_component and is_instance_valid(_slap_component):
			_slap_component.slap_duration = val

var slap_range: float:
	get: return (_slap_component.slap_range if (_slap_component and is_instance_valid(_slap_component)) else 2.0) as float
	set(val):
		if _slap_component and is_instance_valid(_slap_component):
			_slap_component.slap_range = val

var slap_cooldown: float:
	get: return (_slap_component.slap_cooldown if (_slap_component and is_instance_valid(_slap_component)) else 1.0) as float
	set(val):
		if _slap_component and is_instance_valid(_slap_component):
			_slap_component.slap_cooldown = val

var sitting_heal: SittingHealComponent:
	get: return _sitting_heal

var slap_component: SlapComponent:
	get: return _slap_component

var gravity: float:
	get: return _gravity

const FALL_DEATH_Y: float = -3.0
const WATER_SURFACE_Y: float = -0.5
const UP = Vector3.UP


func _ready() -> void:
	randomize()

	contact_monitor = true
	max_contacts_reported = 4
	axis_lock_angular_x = true
	axis_lock_angular_y = true
	axis_lock_angular_z = true
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.0
	can_sleep = false

	_setup_collision_shape()
	_setup_meshes()
	_setup_input_actions()

	_setup_authority_from_name()

	camera.position = Vector3.ZERO

	_apply_player_visibility()

	if _movement_component:
		_movement_component.setup(self, head, fishing_mechanic, _sitting_heal, _slap_component, _net_sync, _camera_component)

	if _camera_component:
		_camera_component.setup(self, head, camera, hand_left, hand_right, spectate_camera, spectate_cam_camera, _players_container)

	if _net_sync:
		_net_sync.setup(self, fishing_mechanic)

	if _slap_component:
		_slap_component.setup(self, camera, _players_container)

	if _carry_component:
		_carry_component.setup(self, head, _rod_pivot, null, null, null, null, _interaction_component.rock_pickup_range)

	if _interaction_component:
		_interaction_component.setup(_carry_component, self, camera, head)

	_health_component.died.connect(_enter_spectate)
	_health_component.health_changed.connect(_on_health_changed)
	fishing_mechanic.reel_success.connect(_on_reel_success)
	fishing_mechanic.escape_launch.connect(_on_escape_launch)
	fishing_mechanic.escape_telegraph_changed.connect(_on_escape_telegraph_changed)

	var gm := get_node_or_null("/root/game_manager")
	if gm:
		gm.shop_toggled.connect(_on_shop_toggled)

	if multiplayer.has_multiplayer_peer():
		multiplayer.peer_connected.connect(_on_peer_connected)


func _exit_tree() -> void:
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)


func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	if _carry_component and _carry_component.holding_shark_bait:
		_carry_component.sync_holding_bait.rpc_id(id, true)


func _setup_collision_shape() -> void:
	if get_node_or_null("CollisionShape3D") != null:
		return
	var shape := CylinderShape3D.new()
	shape.height = 2.0
	shape.radius = 0.3
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	collision_shape.shape = shape
	collision_shape.position.y = 1.0
	add_child(collision_shape)


func _setup_meshes() -> void:
	var body_mesh_resource := CylinderMesh.new()
	body_mesh_resource.height = 2.0
	body_mesh_resource.top_radius = 0.3
	body_mesh_resource.bottom_radius = 0.3
	body_mesh.mesh = body_mesh_resource

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.2, 0.6, 1.0, 0.5)
	body_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	body_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	body_mesh.material_override = body_mat

	_setup_hand(hand_left, Vector3(-0.25, -0.2, -0.35))
	_setup_hand(hand_right, Vector3(0.25, -0.2, -0.35))

	_setup_fishing_rod()
	_rod_pivot = $Head/HandRight/FishingRod
	fishing_mechanic.set_rod_tip($Head/HandRight/FishingRod/RodTip)


func _setup_fishing_rod() -> void:
	var rod_pivot := Node3D.new()
	rod_pivot.name = "FishingRod"
	rod_pivot.rotation.x = deg_to_rad(45)

	var rod_mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.height = 0.8
	cyl.top_radius = 0.005
	cyl.bottom_radius = 0.015
	rod_mesh.mesh = cyl
	rod_mesh.rotation.x = deg_to_rad(-90)
	rod_mesh.position = Vector3(0, 0, -0.4)

	var rod_mat := StandardMaterial3D.new()
	rod_mat.albedo_color = Color(0.35, 0.2, 0.1)
	rod_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	rod_mesh.material_override = rod_mat

	rod_pivot.add_child(rod_mesh)

	var tip := Marker3D.new()
	tip.name = "RodTip"
	tip.position = Vector3(0, 0, -0.8)
	rod_pivot.add_child(tip)

	hand_right.add_child(rod_pivot)


func _setup_hand(hand: MeshInstance3D, position_offset: Vector3) -> void:
	var hand_mesh := SphereMesh.new()
	hand_mesh.radius = 0.08
	hand_mesh.height = 0.16
	hand.mesh = hand_mesh
	hand.position = position_offset

	var hand_mat := StandardMaterial3D.new()
	hand_mat.albedo_color = Color(1.0, 0.8, 0.6)
	hand_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hand.material_override = hand_mat


func _setup_input_actions() -> void:
	_ensure_action("move_forward", KEY_W)
	_ensure_action("move_back", KEY_S)
	_ensure_action("move_left", KEY_A)
	_ensure_action("move_right", KEY_D)
	_ensure_action("jump", KEY_SPACE)

	_ensure_action("cast_line")
	_remove_key_from_action("cast_line", KEY_SPACE)

	_remove_key_from_action("reel", KEY_SPACE)

	_ensure_action("interact")
	_remove_key_from_action("interact", KEY_SPACE)
	var interact_mouse := InputEventMouseButton.new()
	interact_mouse.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("interact", interact_mouse)


func _ensure_action(action: String, keycode: Key = KEY_NONE) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if keycode != KEY_NONE:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		InputMap.action_add_event(action, event)


func _remove_key_from_action(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		return
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == keycode:
			InputMap.action_erase_event(action, event)


func _process(delta: float) -> void:
	if player_state == PlayerState.SPECTATE:
		if _camera_component:
			_camera_component.tick_process(delta)
		return

	if player_state == PlayerState.FLOATING:
		return

	is_yelling = _voice_chat.is_yelling if _voice_chat != null else false

	if _interaction_component:
		_interaction_component.tick(delta, is_carrying, holding_rock, holding_shark_bait)


func _unhandled_input(event: InputEvent) -> void:
	if _interaction_component:
		if event.is_action_pressed("interact"):
			_interaction_component.handle_interact()
		elif event.is_action_pressed("cast_line"):
			_interaction_component.handle_cast_line(launch_speed)

	if event is InputEventMouseMotion and _is_local_authority() and player_state == PlayerState.ALIVE:
		if _movement_component:
			_movement_component._pending_yaw -= event.relative.x * mouse_sensitivity
			_movement_component._pending_pitch -= event.relative.y * mouse_sensitivity


func _physics_process(delta: float) -> void:
	if player_state == PlayerState.FLOATING and multiplayer.has_multiplayer_peer() and multiplayer.is_server() and not _is_local_authority():
		if _movement_component:
			_movement_component._float_time += delta
			if _movement_component._float_time >= float_timeout:
				if _health_component:
					_health_component.take_damage(_health_component.max_health)


func _current_max_speed() -> float:
	return _movement_component._current_max_speed() if _movement_component else walk_speed


func _is_grounded(state: PhysicsDirectBodyState3D) -> bool:
	return _movement_component._is_grounded(state) if _movement_component else false


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _movement_component:
		_movement_component.integrate_forces(state)


func _is_local_authority() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return true
	return get_multiplayer_authority() == multiplayer.get_unique_id()


func _enter_spectate() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server() and not _is_local_authority():
		return
	if is_slapped:
		_clear_slap()
	if assigned_fireplace and assigned_fireplace.has_method("release_seat_for_player"):
		assigned_fireplace.release_seat_for_player(self)
	if _sitting_heal:
		_sitting_heal.reset()
	player_state = PlayerState.SPECTATE
	camera.current = false
	spectate_cam_camera.current = true
	if _camera_component:
		_camera_component._spectate_yaw = 0.0
		_camera_component._spectate_pitch = 0.0
		_camera_component._spectate_target = _camera_component._find_spectate_target()
	is_yelling = false
	if multiplayer.has_multiplayer_peer():
		sync_yelling(false)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		if _net_sync:
			_net_sync._sync_player_state.rpc(PlayerState.SPECTATE)


func _update_spectate_camera(delta: float) -> void:
	if _camera_component:
		_camera_component._update_spectate_camera(delta)


func _find_spectate_target() -> Node3D:
	return _camera_component._find_spectate_target() if _camera_component else null


func _get_alive_players() -> Array[Node3D]:
	return _camera_component._get_alive_players() if _camera_component else []


func _cycle_spectate_target() -> void:
	if _camera_component:
		_camera_component.cycle_spectate_target()


func _on_restart() -> void:
	reset_for_restart()
	var hp := $HealthComponent as HealthComponent
	if hp:
		hp.reset_to_max()
	if _camera_component:
		_camera_component._spectate_target = null
	_respawn_at_spawn()
	if not _is_local_authority():
		return
	player_state = PlayerState.ALIVE
	if _camera_component:
		_camera_component._spectate_yaw = 0.0
		_camera_component._spectate_pitch = 0.0
	camera.current = true
	spectate_cam_camera.current = false
	set_process_unhandled_input(true)
	if _interaction_component:
		_interaction_component.set_prompt_visibility(true)


func _setup_authority_from_name() -> void:
	var owning_id := _parse_owner_id()
	set_multiplayer_authority(owning_id)

	spawn_index = 0
	for i in game_manager.players.size():
		if game_manager.players[i].id == owning_id:
			spawn_index = i
			break

	_respawn_at_spawn()


static func _spawn_positions() -> Array[Vector3]:
	return [
		Vector3(-2.25, 0, 2.5),
		Vector3(-0.75, 0, 2.5),
		Vector3(0.75, 0, 2.5),
		Vector3(2.25, 0, 2.5),
	]


func _respawn_at_spawn() -> void:
	var spawns := _spawn_positions()
	position = spawns[spawn_index] if spawn_index < spawns.size() else spawns[0]
	linear_velocity = Vector3.ZERO


func _check_fell_off_island() -> void:
	if _movement_component:
		_movement_component._check_fell_off_island()


@rpc("authority", "reliable", "call_remote")
func report_fell_off_island(_fell_position: Vector3) -> void:
	if _net_sync:
		_net_sync.report_fell_off_island(_fell_position)


func _apply_fall_death(_fell_position: Vector3) -> void:
	if _movement_component:
		_movement_component._apply_fall_death(_fell_position)


@rpc("authority", "reliable", "call_remote")
func report_entered_water(_fell_position: Vector3) -> void:
	if _net_sync:
		_net_sync.report_entered_water(_fell_position)


func _apply_enter_water(_fell_position: Vector3) -> void:
	if _movement_component:
		_movement_component._apply_enter_water(_fell_position)


func _enter_floating() -> void:
	if player_state != PlayerState.ALIVE:
		return
	if is_slapped:
		_clear_slap()
	if _movement_component:
		_movement_component._entered_water_reported = true
	if _carry_component:
		_carry_component.drop_carried_fish()
		_carry_component.holding_rock = false
		_carry_component.hide_held_rock_remote()
		if multiplayer.has_multiplayer_peer() and _is_local_authority():
			_carry_component.sync_holding_rock.rpc(false)
		_carry_component.clear_holding_shark_bait()
	fishing_mechanic.reset_for_restart()
	if _sitting_heal:
		_sitting_heal.reset()
	player_state = PlayerState.FLOATING
	if _movement_component:
		_movement_component._float_time = 0.0
		_movement_component._float_base_y = WATER_SURFACE_Y
	linear_velocity = Vector3.ZERO
	global_position.y = WATER_SURFACE_Y
	set_physics_process(true)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		if _net_sync:
			_net_sync._sync_floating_state.rpc()


func _process_floating(state: PhysicsDirectBodyState3D) -> void:
	if _movement_component:
		_movement_component._process_floating(state)


func _get_slap_target() -> Player:
	return _slap_component._get_slap_target() if _slap_component else null


func try_fish_slap() -> bool:
	return _slap_component._try_fish_slap() if (_slap_component and is_instance_valid(_slap_component)) else false


func _try_fish_slap() -> bool:
	return try_fish_slap()


func _find_player_by_id(id: int) -> Player:
	return _slap_component._find_player_by_id(id) if _slap_component else null


func apply_slap(duration: float = -1.0) -> void:
	if _slap_component:
		_slap_component.apply_slap(duration)


func _clear_slap() -> void:
	if _slap_component:
		_slap_component._clear_slap()


func _apply_player_visibility() -> void:
	if _is_local_authority():
		_enable_player()
	else:
		_disable_player()


func _parse_owner_id() -> int:
	if not name.begins_with("Player_"):
		return 1
	var id_str := name.trim_prefix("Player_")
	return int(id_str) if id_str.is_valid_int() else 1


func _enable_player() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true
	set_process(true)
	set_physics_process(true)
	freeze = false
	can_sleep = false
	set_process_unhandled_input(true)
	if mic_level_bar != null:
		mic_level_bar.visible = true
	if health_label != null:
		health_label.visible = true
	if _voice_chat != null:
		_voice_chat.set_process(true)
		if not _voice_chat.yelling_state_changed.is_connected(_on_yelling_state_changed):
			_voice_chat.yelling_state_changed.connect(_on_yelling_state_changed)
	if _interaction_component:
		_interaction_component.set_prompt_visibility(true)


func _disable_player() -> void:
	camera.current = false
	set_process(false)
	var keep_physics := player_state == PlayerState.FLOATING
	set_physics_process(keep_physics)
	if not keep_physics:
		freeze = true
		freeze_mode = FREEZE_MODE_KINEMATIC
	can_sleep = true
	set_process_unhandled_input(false)
	if mic_level_bar != null:
		mic_level_bar.visible = false
	if health_label != null:
		health_label.visible = false
	if _voice_chat != null:
		_voice_chat.set_process(false)
		if _voice_chat.yelling_state_changed.is_connected(_on_yelling_state_changed):
			_voice_chat.yelling_state_changed.disconnect(_on_yelling_state_changed)
	fishing_mechanic.is_local_render = false
	if _interaction_component:
		_interaction_component.set_prompt_visibility(false)


func _on_reel_success(_personal_count: int) -> void:
	start_carrying()


func _on_escape_launch(direction: Vector3, strength: float) -> void:
	if _movement_component:
		_movement_component._pending_launch = direction * strength
		_movement_component._pending_launch.y += launch_vertical_boost


func _on_escape_telegraph_changed(intensity: float) -> void:
	if not _rod_pivot:
		return
	_rod_pivot.rotation.x = deg_to_rad(45.0 + intensity * 25.0)


func _on_shop_toggled(is_open: bool) -> void:
	if _interaction_component:
		_interaction_component.on_shop_toggled(is_open)


func _on_health_changed(old: int, new: int) -> void:
	if _carry_component and _carry_component.is_carrying and new < old:
		_carry_component.drop_carried_fish()
	if _carry_component and _carry_component.holding_shark_bait and new < old:
		_carry_component.clear_holding_shark_bait()


func refresh_prompts() -> void:
	if _interaction_component:
		_interaction_component.refresh_prompts()


func _update_prompt_visibility(interactable = null) -> void:
	if _interaction_component and is_instance_valid(_interaction_component):
		_interaction_component._update_prompt_visibility(interactable)


func start_carrying() -> void:
	if _carry_component:
		_carry_component.start_carrying()


func deposit_carried_fish() -> void:
	if _carry_component:
		_carry_component.deposit_carried_fish()


func drop_carried_fish() -> void:
	if _carry_component:
		_carry_component.drop_carried_fish()


func start_holding_shark_bait() -> void:
	if _carry_component:
		_carry_component.start_holding_shark_bait()


func clear_holding_shark_bait() -> void:
	if _carry_component:
		_carry_component.clear_holding_shark_bait()


func _try_pickup_rock() -> bool:
	if _carry_component:
		return _carry_component.try_pickup_rock()
	return false


func _throw_rock() -> void:
	if _carry_component:
		_carry_component.throw_rock(launch_speed)


func toggle_sitting() -> void:
	if is_slapped:
		return
	if player_state == PlayerState.FLOATING and _sitting_heal and not _sitting_heal.is_sitting:
		return
	if _sitting_heal:
		_sitting_heal.toggle_sitting()


func reset_for_restart() -> void:
	if _slap_component and is_instance_valid(_slap_component):
		_slap_component.reset_for_restart()
	if _carry_component:
		if _carry_component.is_carrying:
			_carry_component.clear_carry()
		if _carry_component.holding_rock:
			_carry_component.holding_rock = false
			_carry_component.hide_held_rock_remote()
		if _carry_component.holding_shark_bait:
			_carry_component.clear_holding_shark_bait()
	if assigned_fireplace and assigned_fireplace.has_method("release_seat_for_player"):
		assigned_fireplace.release_seat_for_player(self)
	if _sitting_heal:
		_sitting_heal.reset()
	if _movement_component:
		_movement_component.reset_for_restart()
	player_state = PlayerState.ALIVE
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		if _net_sync:
			_net_sync._sync_player_state.rpc(PlayerState.ALIVE)
	if not _is_local_authority():
		set_physics_process(false)


var _held_fish: Node3D:
	get: return _carry_component._held_fish if (_carry_component and is_instance_valid(_carry_component)) else null

var _held_rock_mesh: MeshInstance3D:
	get: return _carry_component._held_rock_mesh if (_carry_component and is_instance_valid(_carry_component)) else null

var _held_bait_mesh: MeshInstance3D:
	get: return _carry_component._held_bait_mesh if (_carry_component and is_instance_valid(_carry_component)) else null

var _ray_hit_box: bool:
	get: return (_interaction_component._ray_hit_box if (_interaction_component and is_instance_valid(_interaction_component)) else false) as bool
	set(val):
		if _interaction_component and is_instance_valid(_interaction_component):
			_interaction_component._ray_hit_box = val

var _ray_rock: bool:
	get: return (_interaction_component._ray_rock if (_interaction_component and is_instance_valid(_interaction_component)) else false) as bool
	set(val):
		if _interaction_component and is_instance_valid(_interaction_component):
			_interaction_component._ray_rock = val

var _interact_prompt: CanvasLayer:
	get: return _interaction_component._interact_prompt if (_interaction_component and is_instance_valid(_interaction_component)) else null


func _show_held_rock_remote() -> void:
	if _carry_component and is_instance_valid(_carry_component):
		_carry_component._show_held_rock_remote()


func _hide_held_rock_remote() -> void:
	if _carry_component and is_instance_valid(_carry_component):
		_carry_component._hide_held_rock_remote()


func _on_yelling_state_changed(is_yelling: bool) -> void:
	if multiplayer.has_multiplayer_peer():
		sync_yelling(is_yelling)


@rpc("any_peer", "unreliable", "call_remote")
func sync_yelling(new_is_yelling: bool) -> void:
	if _net_sync:
		_net_sync.sync_yelling(new_is_yelling)


@rpc("authority", "unreliable", "call_remote")
func _sync_transform(pos: Vector3, rot: Vector3, head_rot: Vector3) -> void:
	if _net_sync:
		_net_sync._sync_transform(pos, rot, head_rot)


@rpc("authority", "reliable", "call_remote")
func _sync_fishing_state(state: int) -> void:
	if _net_sync:
		_net_sync._sync_fishing_state(state)


@rpc("authority", "reliable", "call_remote")
func _sync_cast_target(pos: Vector3) -> void:
	if _net_sync:
		_net_sync._sync_cast_target(pos)


@rpc("authority", "reliable", "call_remote")
func _sync_flight_duration(dur: float) -> void:
	if _net_sync:
		_net_sync._sync_flight_duration(dur)


@rpc("authority", "reliable", "call_remote")
func _sync_flight_start(pos: Vector3) -> void:
	if _net_sync:
		_net_sync._sync_flight_start(pos)


@rpc("any_peer", "reliable", "call_remote")
func _sync_floating_state() -> void:
	if _net_sync:
		_net_sync._sync_floating_state()


@rpc("any_peer", "reliable", "call_remote")
func _sync_player_state(state: int) -> void:
	if _net_sync:
		_net_sync._sync_player_state(state)
