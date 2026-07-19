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
@export var launch_speed: float = 15.0
@export var max_cast_range: float = 20.0


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

enum PlayerState { ALIVE, SPECTATE }

var player_state: PlayerState = PlayerState.ALIVE
var _spectate_yaw: float = 0.0
var _spectate_pitch: float = 0.0
var _spectate_target: Node3D = null
var _spectate_target_index: int = 0

var _last_fish_state: int = -1
var _last_cast_target: Vector3 = Vector3.ZERO
var _last_flight_duration: float = 0.0
var _last_flight_start: Vector3 = Vector3.ZERO
var _sync_tick: int = 0
var _rod_pivot: Node3D = null

var is_carrying: bool = false
var holding_rock: bool = false
var _held_fish: Node3D = null
var _held_rock_mesh: Node3D = null
var _ray_hit_box: bool = false
var _ray_rock: bool = false
var _interact_prompt: CanvasLayer = null
var _quota_manager_ref: Node3D = null
var _rock_manager_ref: Node = null
var _danger_manager_ref: Node = null
var _is_shop_open: bool = false
@export var interact_range: float = 3.0
@export var rock_pickup_range: float = 3.0

const INTERACTABLE_LAYER: int = 1 << 5


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

	_health_component.died.connect(_enter_spectate)
	_health_component.health_changed.connect(_on_health_changed)
	fishing_mechanic.reel_success.connect(_on_reel_success)
	
	get_node("/root/game_manager").shop_toggled.connect(_on_shop_toggled)

	_setup_interact_prompt()

	var qm := get_node_or_null("/root/main/QuotaManager")
	if qm:
		_quota_manager_ref = qm

	var rm := get_node_or_null("/root/main/RockManager")
	if rm:
		_rock_manager_ref = rm
	
	var dm := get_node_or_null("/root/main/DangerManager")
	if dm:
		_danger_manager_ref = dm

	call_deferred("_apply_upgrade_effects_on_ready")


func _apply_upgrade_effects_on_ready() -> void:
	var cm := get_node_or_null("/root/main/CoinManager") as CoinManager
	if cm:
		cm.apply_upgrade_effects_to_player(self)


func _setup_interact_prompt() -> void:
	_interact_prompt = CanvasLayer.new()
	_interact_prompt.name = "InteractPrompt"
	_interact_prompt.layer = 130
	var label := Label.new()
	label.name = "PromptLabel"
	label.text = "Deposit Fish [Right Click]"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.offset_left = -150
	label.offset_top = -25
	label.offset_right = 150
	label.offset_bottom = 25
	var font_size := 24
	label.add_theme_font_size_override("font_size", font_size)
	label.visible = false
	_interact_prompt.add_child(label)

	var rock_label := Label.new()
	rock_label.name = "RockPromptLabel"
	rock_label.text = "Pick up rock [Left Click]"
	rock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rock_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	rock_label.offset_left = -150
	rock_label.offset_top = -60
	rock_label.offset_right = 150
	rock_label.offset_bottom = -10
	rock_label.add_theme_font_size_override("font_size", font_size)
	rock_label.visible = false
	_interact_prompt.add_child(rock_label)

	add_child(_interact_prompt)


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
		_update_spectate_camera(delta)
		return

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

	if not multiplayer.has_multiplayer_peer() or get_multiplayer_authority() == multiplayer.get_unique_id():
		_update_interact_raycast()
		_update_rock_raycast()


func _update_interact_raycast() -> void:
	var space_state := get_world_3d().direct_space_state
	if space_state == null:
		return
	var origin := camera.global_position
	var dir := -camera.global_transform.basis.z
	var params := PhysicsRayQueryParameters3D.new()
	params.from = origin
	params.to = origin + dir * interact_range
	params.collision_mask = INTERACTABLE_LAYER
	var result := space_state.intersect_ray(params)

	var hit_node = result.get("collider") if result else null
	var interactable = hit_node.get_node_or_null("InteractableComponent") if hit_node and hit_node.has_method("get_node_or_null") else null
	_ray_hit_box = interactable != null and interactable.is_enabled

	_update_prompt_visibility(interactable)


func _update_prompt_visibility(interactable = null) -> void:
	if not is_instance_valid(_interact_prompt):
		return
	var label := _interact_prompt.get_node_or_null("PromptLabel") as Label
	if not label:
		return
	
	if _ray_hit_box and interactable and not _is_shop_open and is_carrying:
		label.text = interactable.prompt_text
		label.add_theme_color_override("font_color", interactable.prompt_color)
		label.visible = true
	else:
		label.visible = false


func _update_rock_raycast() -> void:
	if is_carrying or holding_rock:
		if _ray_rock:
			_ray_rock = false
			_update_rock_prompt_visibility()
		return
	if not _rock_manager_ref:
		return
	var space_state := get_world_3d().direct_space_state
	if space_state == null:
		return
	var origin := camera.global_position
	var dir := -camera.global_transform.basis.z
	var params := PhysicsRayQueryParameters3D.new()
	params.from = origin
	params.to = origin + dir * rock_pickup_range
	params.collision_mask = 4
	var result := space_state.intersect_ray(params)
	var hit_rock := false
	if result:
		var rock_index: int = _rock_manager_ref.get_nearest_available_point(result.position, 2.0)
		hit_rock = rock_index != -1
	if hit_rock != _ray_rock:
		_ray_rock = hit_rock
		_update_rock_prompt_visibility()


func _update_rock_prompt_visibility() -> void:
	if not is_instance_valid(_interact_prompt):
		return
	var label := _interact_prompt.get_node_or_null("RockPromptLabel") as Label
	if not label:
		return
	label.visible = _ray_rock and not _is_shop_open


func _try_pickup_rock() -> bool:
	if is_carrying:
		return false
	if not _rock_manager_ref:
		return false
	var space_state := get_world_3d().direct_space_state
	if not space_state:
		return false
	var origin := camera.global_position
	var dir := -camera.global_transform.basis.z
	var params := PhysicsRayQueryParameters3D.new()
	params.from = origin
	params.to = origin + dir * rock_pickup_range
	params.collision_mask = 4
	var result := space_state.intersect_ray(params)
	if not result:
		return false
	var rock_index: int = _rock_manager_ref.get_nearest_available_point(result.position, 2.0)
	if rock_index == -1:
		return false
	_rock_manager_ref.request_pickup(rock_index)
	holding_rock = true
	_show_held_rock_remote()
	if multiplayer.has_multiplayer_peer():
		sync_holding_rock.rpc(true)
	_update_rock_prompt_visibility()
	return true


func _throw_rock() -> void:
	var rock := RigidBody3D.new()
	rock.name = "ThrownRock"
	rock.gravity_scale = 1.0

	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.25, 0.15, 0.25)
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.5, 0.5)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	rock.add_child(mi)

	var cs := CollisionShape3D.new()
	cs.shape = BoxShape3D.new()
	cs.shape.size = Vector3(0.25, 0.15, 0.25)
	rock.add_child(cs)

	var rock_pos := camera.global_position + (-camera.global_transform.basis.z * 0.5)
	rock.position = rock_pos
	var throw_dir := -camera.global_transform.basis.z
	rock.linear_velocity = throw_dir * launch_speed + Vector3(0, 3, 0)
	rock.angular_velocity = Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5))
	get_tree().root.add_child(rock)
	
	if _danger_manager_ref:
		if multiplayer.has_multiplayer_peer():
			_danger_manager_ref.repel.rpc(rock_pos, throw_dir)
		else:
			_danger_manager_ref.repel(rock_pos, throw_dir)

	var cleanup := Timer.new()
	cleanup.one_shot = true
	cleanup.timeout.connect(rock.queue_free)
	rock.add_child(cleanup)
	cleanup.start(5.0)

	holding_rock = false
	_hide_held_rock_remote()
	if multiplayer.has_multiplayer_peer():
		sync_holding_rock.rpc(false)


func _unhandled_input(event: InputEvent) -> void:
	if player_state == PlayerState.SPECTATE:
		if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_spectate_yaw -= event.relative.x * mouse_sensitivity
			_spectate_pitch -= event.relative.y * mouse_sensitivity
			_spectate_pitch = clamp(_spectate_pitch, deg_to_rad(-89.0), deg_to_rad(89.0))
			spectate_camera.rotation.y = _spectate_yaw
			spectate_camera.rotation.x = _spectate_pitch
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_cycle_spectate_target()
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))

	if event.is_action_pressed("cast_line"):
		if holding_rock:
			_throw_rock()
		elif not is_carrying and _try_pickup_rock():
			pass
		elif not is_carrying and fishing_mechanic.can_cast():
			var rod_tip: Vector3 = fishing_mechanic.get_rod_tip_position()
			var dir := -camera.global_transform.basis.z
			var v := dir * launch_speed
			var discriminant: float = v.y * v.y + 2.0 * _gravity * rod_tip.y
			var flight_time := (v.y + sqrt(max(discriminant, 0.0))) / _gravity
			flight_time = max(flight_time, 0.1)
			var target := Vector3(rod_tip.x + v.x * flight_time, 0.0, rod_tip.z + v.z * flight_time)
			var offset := Vector2(target.x - global_position.x, target.z - global_position.z)
			if offset.length() > max_cast_range:
				offset = offset.normalized() * max_cast_range
				target.x = global_position.x + offset.x
				target.z = global_position.z + offset.y
			fishing_mechanic.cast(target, flight_time)

	if event.is_action_pressed("interact") and _ray_hit_box:
		var space_state := get_world_3d().direct_space_state
		var origin := camera.global_position
		var dir := -camera.global_transform.basis.z
		var params := PhysicsRayQueryParameters3D.new()
		params.from = origin
		params.to = origin + dir * interact_range
		params.collision_mask = INTERACTABLE_LAYER
		var result := space_state.intersect_ray(params)
		
		if result and result.collider:
			var interactable = result.collider.get_node_or_null("InteractableComponent")
			if interactable and interactable.is_enabled:
				interactable.interacted.emit(self)
				if is_carrying and result.collider.is_in_group("storage_box"):
					deposit_carried_fish()


func _physics_process(delta: float) -> void:
	if player_state == PlayerState.SPECTATE:
		if not is_on_floor():
			velocity.y -= _gravity * delta
		else:
			velocity.x = 0.0
			velocity.z = 0.0
		move_and_slide()
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
		return

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

	var fd: float = fishing_mechanic._current_flight_duration
	if fd != _last_flight_duration:
		_last_flight_duration = fd
		rpc("_sync_flight_duration", fd)

	var fsp: Vector3 = fishing_mechanic._flight_start_position
	if fsp != _last_flight_start:
		_last_flight_start = fsp
		rpc("_sync_flight_start", fsp)


func _enter_spectate() -> void:
	if get_multiplayer_authority() != multiplayer.get_unique_id():
		return
	player_state = PlayerState.SPECTATE
	camera.current = false
	spectate_cam_camera.current = true
	_spectate_yaw = 0.0
	_spectate_pitch = 0.0
	_spectate_target = _find_spectate_target()
	is_yelling = false
	sync_yelling.rpc(false)


func _update_spectate_camera(delta: float) -> void:
	if _spectate_target == null or not is_instance_valid(_spectate_target):
		_spectate_target = _find_spectate_target()
	elif _spectate_target != self:
		var hp := _spectate_target.get_node_or_null("HealthComponent") as HealthComponent
		if hp == null or not hp.is_alive():
			_spectate_target = _find_spectate_target()
	var target := _spectate_target if _spectate_target != null else self
	spectate_camera.global_position = target.global_position
	spectate_cam_camera.look_at(target.global_position + Vector3(0, 1.0, 0))


func _find_spectate_target() -> Node3D:
	if _players_container == null:
		return null
	for child in _players_container.get_children():
		if child == self:
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
		if child == self:
			continue
		var hp := child.get_node_or_null("HealthComponent") as HealthComponent
		if hp and hp.is_alive():
			alive.append(child)
	return alive


func _cycle_spectate_target() -> void:
	var alive := _get_alive_players()
	if alive.is_empty():
		_spectate_target = null
		return
	var current_index := alive.find(_spectate_target)
	if current_index == -1:
		current_index = _spectate_target_index
	_spectate_target_index = (current_index + 1) % alive.size()
	_spectate_target = alive[_spectate_target_index]


func _on_restart() -> void:
	reset_for_restart()
	var hp := $HealthComponent as HealthComponent
	if hp:
		hp.reset_to_max()
	_spectate_target = null
	if get_multiplayer_authority() != multiplayer.get_unique_id():
		return
	player_state = PlayerState.ALIVE
	_spectate_yaw = 0.0
	_spectate_pitch = 0.0
	camera.current = true
	spectate_cam_camera.current = false
	set_process_unhandled_input(true)
	if is_instance_valid(_interact_prompt):
		_interact_prompt.visible = true


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
	if health_label != null:
		health_label.visible = true
	if _voice_chat != null:
		_voice_chat.set_process(true)
		if not _voice_chat.yelling_state_changed.is_connected(_on_yelling_state_changed):
			_voice_chat.yelling_state_changed.connect(_on_yelling_state_changed)
	if is_instance_valid(_interact_prompt):
		_interact_prompt.visible = true


func _disable_player() -> void:
	camera.current = false
	set_process(false)
	set_physics_process(false)
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
	if is_instance_valid(_interact_prompt):
		_interact_prompt.visible = false


func _on_reel_success(_personal_count: int) -> void:
	start_carrying()

func _on_shop_toggled(is_open: bool) -> void:
	_is_shop_open = is_open
	_update_prompt_visibility()
	_update_rock_prompt_visibility()


func _on_health_changed(old: int, new: int) -> void:
	if is_carrying and new < old:
		drop_carried_fish()


func start_carrying() -> void:
	is_carrying = true
	_show_held_fish_remote()
	if multiplayer.has_multiplayer_peer():
		sync_carrying.rpc(true)
	_update_prompt_visibility()


func deposit_carried_fish() -> void:
	if not is_carrying:
		return
	if is_instance_valid(_quota_manager_ref) and (not multiplayer.has_multiplayer_peer() or multiplayer.is_server()):
		_quota_manager_ref.report_catch(1)
	elif is_instance_valid(_quota_manager_ref):
		_quota_manager_ref.report_catch.rpc(1)
	_clear_carry()


func drop_carried_fish() -> void:
	if not is_carrying:
		return
	_clear_carry()


func _clear_carry() -> void:
	is_carrying = false
	_hide_held_fish_remote()
	if multiplayer.has_multiplayer_peer():
		sync_carrying.rpc(false)
	_update_prompt_visibility()


func reset_for_restart() -> void:
	if is_carrying:
		_clear_carry()
	if holding_rock:
		holding_rock = false
		_hide_held_rock_remote()


func _on_yelling_state_changed(is_yelling: bool) -> void:
	if multiplayer.has_multiplayer_peer():
		sync_yelling.rpc(is_yelling)


@rpc("any_peer", "unreliable", "call_remote")
func sync_yelling(new_is_yelling: bool) -> void:
	is_yelling = new_is_yelling


@rpc("authority", "reliable", "call_remote")
func sync_holding_rock(val: bool) -> void:
	holding_rock = val
	if val:
		_show_held_rock_remote()
	else:
		_hide_held_rock_remote()
	_update_rock_prompt_visibility()


@rpc("any_peer", "unreliable", "call_remote")
func sync_carrying(val: bool) -> void:
	is_carrying = val
	if val:
		_show_held_fish_remote()
	else:
		_hide_held_fish_remote()
	_update_prompt_visibility()
	_update_rock_prompt_visibility()


func _show_held_fish_remote() -> void:
	if is_instance_valid(_held_fish):
		return
	_rod_pivot.visible = false
	_held_fish = MeshInstance3D.new()
	var fish_mesh := BoxMesh.new()
	fish_mesh.size = Vector3(0.3, 0.1, 0.5)
	_held_fish.mesh = fish_mesh
	var fish_mat := ORMMaterial3D.new()
	fish_mat.albedo_color = Color(1.0, 0.5, 0.0)
	fish_mat.shading_mode = ORMMaterial3D.SHADING_MODE_UNSHADED
	_held_fish.material_override = fish_mat
	_held_fish.position = Vector3(0, -0.1, -0.5)
	head.add_child(_held_fish)


func _hide_held_fish_remote() -> void:
	if is_instance_valid(_held_fish):
		_held_fish.queue_free()
		_held_fish = null
	_rod_pivot.visible = true


func _show_held_rock_remote() -> void:
	if is_instance_valid(_held_rock_mesh):
		return
	_rod_pivot.visible = false
	_held_rock_mesh = MeshInstance3D.new()
	var rock_mesh := BoxMesh.new()
	rock_mesh.size = Vector3(0.25, 0.15, 0.25)
	_held_rock_mesh.mesh = rock_mesh
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.5, 0.5, 0.5)
	rock_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_held_rock_mesh.material_override = rock_mat
	_held_rock_mesh.position = Vector3(0, -0.1, -0.5)
	head.add_child(_held_rock_mesh)


func _hide_held_rock_remote() -> void:
	if is_instance_valid(_held_rock_mesh):
		_held_rock_mesh.queue_free()
		_held_rock_mesh = null
	_rod_pivot.visible = true


@rpc("authority", "unreliable", "call_remote")
func _sync_transform(pos: Vector3, rot: Vector3, head_rot: Vector3) -> void:
	global_position = pos
	rotation = rot
	head.rotation = head_rot


@rpc("authority", "reliable", "call_remote")
func _sync_fishing_state(state: int) -> void:
	fishing_mechanic.current_state = state


@rpc("authority", "reliable", "call_remote")
func _sync_cast_target(pos: Vector3) -> void:
	fishing_mechanic.cast_target_position = pos


@rpc("authority", "reliable", "call_remote")
func _sync_flight_duration(dur: float) -> void:
	fishing_mechanic._current_flight_duration = dur


@rpc("authority", "reliable", "call_remote")
func _sync_flight_start(pos: Vector3) -> void:
	fishing_mechanic._flight_start_position = pos
