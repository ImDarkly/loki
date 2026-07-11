class_name Player extends CharacterBody3D

@export var move_speed: float = 5.0
@export var jump_height: float = 2.0
@export var mouse_sensitivity: float = 0.002
@export var fall_gravity_multiplier: float = 1.5
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
@export var jump_cut_multiplier: float = 0.5
@export var spawn_index: int = 0


@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var fishing_mechanic: Node3D = $FishingMechanic
@onready var hand_left: MeshInstance3D = $Head/HandLeft
@onready var hand_right: MeshInstance3D = $Head/HandRight
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var _voice_chat: Node = $VoiceChatManager
@onready var mic_level_bar: CanvasLayer = get_node_or_null("MicLevelBar")

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _jump_velocity: float

var _hand_base_left: Vector3
var _hand_base_right: Vector3
var _prev_yaw: float = 0.0
var _was_moving: bool = false
var _walk_squish_offset: float = 0.0
var _cam_home: Vector3
var _bounce_pos: float = 0.0
var _bounce_vel: float = 0.0
var _hand_bounce: float = 0.0
var is_yelling: bool = false

var _last_fish_state: int = -1
var _last_cast_target: Vector3 = Vector3.ZERO
var _sync_tick: int = 0


func _ready() -> void:
	randomize()

	_jump_velocity = sqrt(2.0 * _gravity * jump_height)

	_setup_collision_shape()
	_setup_meshes()
	_setup_input_actions()

	_setup_authority_from_name()

	camera.position = Vector3.ZERO
	_cam_home = Vector3.ZERO

	_apply_player_visibility()


func _setup_collision_shape() -> void:
	var shape := CylinderShape3D.new()
	shape.height = 2.0
	shape.radius = 0.3
	var collision_shape := CollisionShape3D.new()
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

	_hand_base_left = hand_left.position
	_hand_base_right = hand_right.position

	_setup_fishing_rod()
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
	is_yelling = _voice_chat.is_yelling if _voice_chat != null else false
	var speed := Vector2(velocity.x, velocity.z).length()
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

	camera.position = _cam_home + shake_pos + Vector3(0, _bounce_pos, 0)
	camera.rotation.z = shake_rot


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))

	if event.is_action_pressed("cast_line") and fishing_mechanic.can_cast():
		fishing_mechanic.cast(global_position, -global_transform.basis.z)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		var mult := fall_gravity_multiplier if velocity.y < 0 else 1.0
		velocity.y -= _gravity * mult * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = _jump_velocity
		_bounce_vel = -jump_bounce_impulse
		_hand_bounce = hand_jump_raise

	if Input.is_action_just_released("jump") and velocity.y > 0.0:
		velocity.y *= jump_cut_multiplier

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction != Vector3.ZERO:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)

	var was_on_floor := is_on_floor()
	move_and_slide()

	if not was_on_floor and is_on_floor():
		_hand_bounce = -hand_land_drop

	var is_moving := Vector2(velocity.x, velocity.z).length() > 0.1
	if is_moving and not _was_moving:
		_walk_squish_offset = -walk_squish_strength
	_walk_squish_offset = lerp(_walk_squish_offset, 0.0, walk_squish_decay * delta)
	_was_moving = is_moving

	var yaw_delta: float = fmod(rotation.y - _prev_yaw, TAU)
	if yaw_delta > PI:
		yaw_delta -= TAU
	elif yaw_delta < -PI:
		yaw_delta += TAU
	var yaw_sign: float = sign(yaw_delta)
	var speed_l: float = hand_follow_speed_left + yaw_sign * yaw_speed_variation
	var speed_r: float = hand_follow_speed_right - yaw_sign * yaw_speed_variation

	var pitch_factor: float = head.rotation.x / deg_to_rad(89.0)
	var target_y: float = _hand_base_left.y + pitch_factor * 0.04 + _walk_squish_offset + _hand_bounce
	hand_left.position.y = lerp(hand_left.position.y, target_y, speed_l * delta)
	hand_right.position.y = lerp(hand_right.position.y, target_y, speed_r * delta)

	var yaw_sway: float = -yaw_delta * 2.0
	hand_left.position.x = lerp(hand_left.position.x, _hand_base_left.x + yaw_sway, speed_l * delta)
	hand_right.position.x = lerp(hand_right.position.x, _hand_base_right.x + yaw_sway, speed_r * delta)

	_hand_bounce = lerp(_hand_bounce, 0.0, hand_bounce_decay * delta)

	_prev_yaw = rotation.y

	_sync_tick += 1
	if _sync_tick >= 2:
		_sync_tick = 0
		rpc("_sync_transform", global_position, rotation, head.rotation)

	var fs: int = fishing_mechanic.current_state
	if fs != _last_fish_state:
		_last_fish_state = fs
		rpc("_sync_fishing_state", fs)

	var ct: Vector3 = fishing_mechanic.cast_target_position
	if ct != _last_cast_target:
		_last_cast_target = ct
		rpc("_sync_cast_target", ct)


func _setup_authority_from_name() -> void:
	var owning_id := _parse_owner_id()
	set_multiplayer_authority(owning_id)

	var spawn_positions := [
		Vector3(-2.25, 0, 2.5),
		Vector3(-0.75, 0, 2.5),
		Vector3(0.75, 0, 2.5),
		Vector3(2.25, 0, 2.5),
	]

	spawn_index = 0
	for i in game_manager.players.size():
		if game_manager.players[i].id == owning_id:
			spawn_index = i
			break

	position = spawn_positions[spawn_index] if spawn_index < spawn_positions.size() else spawn_positions[0]


func _apply_player_visibility() -> void:
	if get_multiplayer_authority() == multiplayer.get_unique_id():
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
	set_process_unhandled_input(true)
	if mic_level_bar != null:
		mic_level_bar.visible = true
	if _voice_chat != null:
		_voice_chat.set_process(true)
		if not _voice_chat.yelling_state_changed.is_connected(_on_yelling_state_changed):
			_voice_chat.yelling_state_changed.connect(_on_yelling_state_changed)


func _disable_player() -> void:
	camera.current = false
	set_process(false)
	set_physics_process(false)
	set_process_unhandled_input(false)
	if mic_level_bar != null:
		mic_level_bar.visible = false
	if _voice_chat != null:
		_voice_chat.set_process(false)
		if _voice_chat.yelling_state_changed.is_connected(_on_yelling_state_changed):
			_voice_chat.yelling_state_changed.disconnect(_on_yelling_state_changed)
	fishing_mechanic.is_local_render = false


func _on_yelling_state_changed(is_yelling: bool) -> void:
	sync_yelling.rpc(is_yelling)


@rpc("any_peer", "unreliable", "call_remote")
func sync_yelling(new_is_yelling: bool) -> void:
	is_yelling = new_is_yelling


@rpc("authority", "unreliable", "call_remote")
func _sync_transform(pos: Vector3, rot: Vector3, head_rot: Vector3) -> void:
	global_position = pos
	rotation = rot
	head.rotation = head_rot


@rpc("authority", "unreliable", "call_remote")
func _sync_fishing_state(state: int) -> void:
	fishing_mechanic.current_state = state


@rpc("authority", "unreliable", "call_remote")
func _sync_cast_target(pos: Vector3) -> void:
	fishing_mechanic.cast_target_position = pos
