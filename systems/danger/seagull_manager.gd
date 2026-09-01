extends Node3D

enum State { INACTIVE, ROAMING, APPROACHING, ATTACKING, RETREATING, WAITING }

@export var flight_altitude: float = 6.0
@export var roaming_altitude: float = 12.0
@export var roam_radius: float = 6.0
@export var roam_duration_min: float = 10.0
@export var roam_duration_max: float = 15.0
@export var flight_speed: float = 4.0
@export var repel_radius: float = 2.0
@export var arrival_range: float = 2.0
@export var theft_amount: int = 1
@export var spawn_interval_min: float = 30.0
@export var spawn_interval_max: float = 60.0
@export var return_interval_min: float = 45.0
@export var return_interval_max: float = 90.0

var current_state: State = State.INACTIVE
var seagull_node: MeshInstance3D = null
var spawn_position: Vector3
var _roam_center: Vector3
var _roam_angle: float = 0.0
var _storage_box: Node3D = null
var _sync_tick: int = 0
var _round_manager: Node = null
var _last_fishing_active: bool = true
@onready var spawn_timer: Timer = $SpawnTimer
@onready var return_timer: Timer = $ReturnTimer
@onready var roam_timer: Timer = $RoamTimer


func _ready() -> void:
	if OS.is_debug_build():
		var dbg = get_node_or_null("/root/DebugOverlay")
		if dbg:
			dbg.register_system(name, self)

	_storage_box = get_node_or_null("../StorageBox") as Node3D
	_round_manager = get_node_or_null("../RoundManager")
	if _round_manager and "fishing_active" in _round_manager:
		_last_fishing_active = _round_manager.fishing_active
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		set_physics_process(false)
		spawn_timer.stop()
		return_timer.stop()
		if has_node("RoamTimer"):
			$RoamTimer.stop()
		return

	spawn_timer.one_shot = true
	if not spawn_timer.timeout.is_connected(_on_spawn_timer_timeout):
		spawn_timer.timeout.connect(_on_spawn_timer_timeout)

	return_timer.one_shot = true
	if not return_timer.timeout.is_connected(_on_return_timer_timeout):
		return_timer.timeout.connect(_on_return_timer_timeout)

	roam_timer.one_shot = true
	if not roam_timer.timeout.is_connected(_on_roam_timer_timeout):
		roam_timer.timeout.connect(_on_roam_timer_timeout)

	spawn_timer.start(randf_range(spawn_interval_min, spawn_interval_max))


func _get_quota_manager() -> Node:
	return get_node_or_null("../QuotaManager")


func _can_spawn() -> bool:
	var qm := _get_quota_manager()
	if qm == null:
		return true
	if "shared_quota" in qm:
		return int(qm.shared_quota) > 0
	return true


func _on_roam_timer_timeout() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if current_state == State.ROAMING:
		current_state = State.APPROACHING
		_sync_state_to_clients()


func _on_spawn_timer_timeout() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if _round_manager and "fishing_active" in _round_manager and not _round_manager.fishing_active:
		return
	if not _can_spawn():
		if current_state != State.WAITING:
			current_state = State.WAITING
		return_timer.start(randf_range(return_interval_min, return_interval_max))
		_sync_state_to_clients()
		return
	if current_state == State.INACTIVE or current_state == State.WAITING:
		_spawn_seagull()
		current_state = State.ROAMING
		roam_timer.start(randf_range(roam_duration_min, roam_duration_max))
		_sync_state_to_clients()


func _on_return_timer_timeout() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if _round_manager and "fishing_active" in _round_manager and not _round_manager.fishing_active:
		return
	if not _can_spawn():
		return_timer.start(randf_range(return_interval_min, return_interval_max))
		_sync_state_to_clients()
		return
	if current_state == State.WAITING:
		_spawn_seagull()
		current_state = State.ROAMING
		roam_timer.start(randf_range(roam_duration_min, roam_duration_max))
		_sync_state_to_clients()


func _spawn_seagull() -> void:
	var storage_box := _get_storage_box()
	if storage_box != null:
		_roam_center = Vector3(storage_box.global_position.x, roaming_altitude, storage_box.global_position.z)
	else:
		_roam_center = Vector3(MapConfig.MAP_CENTER.x, roaming_altitude, MapConfig.MAP_CENTER.z)
	_roam_angle = randf() * TAU
	spawn_position = _roam_center + Vector3(cos(_roam_angle) * roam_radius, 0, sin(_roam_angle) * roam_radius)
	spawn_position.y = roaming_altitude

	if not is_instance_valid(seagull_node):
		seagull_node = _create_seagull_mesh()
		add_child(seagull_node)

	seagull_node.position = spawn_position
	seagull_node.visible = true

	if is_instance_valid(seagull_node):
		var tangent := Vector3(-sin(_roam_angle), 0, cos(_roam_angle))
		if tangent.length_squared() > 0.001:
			seagull_node.look_at(seagull_node.position + tangent, Vector3.UP)


func _get_storage_box() -> Node3D:
	if is_instance_valid(_storage_box):
		return _storage_box
	_storage_box = get_node_or_null("../StorageBox") as Node3D
	return _storage_box


func _direction_to_storage(from: Vector3, storage_box: Node3D) -> Vector3:
	if not is_instance_valid(storage_box):
		return Vector3.ZERO
	var target := Vector3(storage_box.global_position.x, flight_altitude, storage_box.global_position.z)
	return (target - Vector3(from.x, flight_altitude, from.z)).normalized()


func _create_seagull_mesh() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var body_len: float = 0.5
	var body_w: float = 0.15
	var body_h: float = 0.12
	var wing_span: float = 0.7
	var wing_chord: float = 0.28
	var y_body: float = 0.0

	# Body — simple diamond prism top view, two triangles per side
	# Top face
	st.set_normal(Vector3(0, 1, 0))
	st.add_vertex(Vector3(0, y_body, -body_len * 0.5))
	st.add_vertex(Vector3(-body_w, y_body, 0))
	st.add_vertex(Vector3(body_w, y_body, 0))
	st.set_normal(Vector3(0, 1, 0))
	st.add_vertex(Vector3(0, y_body, body_len * 0.5))
	st.add_vertex(Vector3(body_w, y_body, 0))
	st.add_vertex(Vector3(-body_w, y_body, 0))

	# Bottom face
	st.set_normal(Vector3(0, -1, 0))
	st.add_vertex(Vector3(0, y_body - body_h, -body_len * 0.5))
	st.add_vertex(Vector3(body_w, y_body - body_h, 0))
	st.add_vertex(Vector3(-body_w, y_body - body_h, 0))
	st.set_normal(Vector3(0, -1, 0))
	st.add_vertex(Vector3(0, y_body - body_h, body_len * 0.5))
	st.add_vertex(Vector3(-body_w, y_body - body_h, 0))
	st.add_vertex(Vector3(body_w, y_body - body_h, 0))

	# Left wing
	st.set_normal(Vector3(0, 1, 0))
	st.add_vertex(Vector3(-body_w, y_body, 0.08))
	st.add_vertex(Vector3(-wing_span, y_body + 0.04, -0.12))
	st.add_vertex(Vector3(-wing_span, y_body + 0.04, wing_chord * 0.5))
	st.set_normal(Vector3(0, -1, 0))
	st.add_vertex(Vector3(-body_w, y_body - 0.02, 0.08))
	st.add_vertex(Vector3(-wing_span, y_body - 0.02, wing_chord * 0.5))
	st.add_vertex(Vector3(-wing_span, y_body - 0.02, -0.12))

	# Right wing
	st.set_normal(Vector3(0, 1, 0))
	st.add_vertex(Vector3(body_w, y_body, 0.08))
	st.add_vertex(Vector3(wing_span, y_body + 0.04, wing_chord * 0.5))
	st.add_vertex(Vector3(wing_span, y_body + 0.04, -0.12))
	st.set_normal(Vector3(0, -1, 0))
	st.add_vertex(Vector3(body_w, y_body - 0.02, 0.08))
	st.add_vertex(Vector3(wing_span, y_body - 0.02, -0.12))
	st.add_vertex(Vector3(wing_span, y_body - 0.02, wing_chord * 0.5))

	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.92, 0.92)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.mesh = mesh
	return mi


func _physics_process(delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if _round_manager == null:
		_round_manager = get_node_or_null("../RoundManager")
		if _round_manager and "fishing_active" in _round_manager:
			_last_fishing_active = _round_manager.fishing_active
	if _round_manager and "fishing_active" in _round_manager:
		var fa: bool = _round_manager.fishing_active
		if fa != _last_fishing_active:
			if fa:
				_on_fishing_resumed()
			else:
				_on_fishing_paused()
			_last_fishing_active = fa
		if not fa and current_state != State.RETREATING:
			return
	match current_state:
		State.ROAMING:
			_process_roaming(delta)
		State.APPROACHING:
			_process_approaching(delta)
		State.RETREATING:
			_process_retreating(delta)


func _process_roaming(delta: float) -> void:
	if not is_instance_valid(seagull_node):
		return
	var storage_box := _get_storage_box()
	if storage_box != null:
		_roam_center = Vector3(storage_box.global_position.x, roaming_altitude, storage_box.global_position.z)
	else:
		_roam_center = Vector3(MapConfig.MAP_CENTER.x, roaming_altitude, MapConfig.MAP_CENTER.z)
	var angular_speed := flight_speed / maxf(roam_radius, 0.1)
	_roam_angle += angular_speed * delta
	var new_pos := Vector3(
		_roam_center.x + cos(_roam_angle) * roam_radius,
		roaming_altitude,
		_roam_center.z + sin(_roam_angle) * roam_radius
	)
	seagull_node.position = new_pos
	var tangent := Vector3(-sin(_roam_angle), 0, cos(_roam_angle))
	if tangent.length_squared() > 0.001:
		seagull_node.look_at(seagull_node.position + tangent, Vector3.UP)
	_sync_tick += 1
	if _sync_tick % 5 == 0:
		_sync_state_to_clients()


func _process_approaching(delta: float) -> void:
	var storage_box := _get_storage_box()
	if storage_box == null or not is_instance_valid(seagull_node):
		return

	var target := Vector3(storage_box.global_position.x, flight_altitude, storage_box.global_position.z)
	var current := Vector3(seagull_node.position.x, flight_altitude, seagull_node.position.z)
	var dist := current.distance_to(target)

	if dist <= arrival_range:
		_trigger_attack()
		return

	var direction := (target - current).normalized()
	var step: float = minf(flight_speed * delta, dist)
	var new_pos := seagull_node.position + direction * step
	new_pos.y = move_toward(seagull_node.position.y, flight_altitude, flight_speed * delta)
	seagull_node.position = new_pos

	if direction.length_squared() > 0.001:
		seagull_node.look_at(seagull_node.position + direction, Vector3.UP)
	_sync_tick += 1
	if _sync_tick % 5 == 0:
		_sync_state_to_clients()


func _process_retreating(delta: float) -> void:
	if not is_instance_valid(seagull_node):
		return

	var target := Vector3(spawn_position.x, spawn_position.y, spawn_position.z)
	var current := Vector3(seagull_node.position.x, seagull_node.position.y, seagull_node.position.z)
	var dist_to_spawn := current.distance_to(target)
	var direction := (target - current).normalized()
	var step := minf(flight_speed * delta, dist_to_spawn)
	var new_pos := seagull_node.position + direction * step
	seagull_node.position = new_pos

	if direction.length_squared() > 0.001:
		seagull_node.look_at(seagull_node.position + direction, Vector3.UP)

	var reached_spawn := new_pos.distance_to(target) <= 0.1
	if reached_spawn or not MapConfig.is_within_radius(new_pos, MapConfig.MAP_CENTER, MapConfig.FISHABLE_BAND_RADIUS):
		seagull_node.visible = false
		current_state = State.WAITING
		if _round_manager == null or not ("fishing_active" in _round_manager) or _round_manager.fishing_active:
			return_timer.start(randf_range(return_interval_min, return_interval_max))
		_sync_state_to_clients()
		return
	_sync_tick += 1
	if _sync_tick % 5 == 0:
		_sync_state_to_clients()


func _trigger_retreat() -> void:
	current_state = State.RETREATING
	_sync_state_to_clients()


func _trigger_attack() -> void:
	current_state = State.ATTACKING
	var qm := _get_quota_manager()
	if qm and qm.has_method("apply_penalty"):
		qm.apply_penalty(theft_amount)
	if multiplayer.has_multiplayer_peer():
		_notify_seagull_stole.rpc(theft_amount)
	else:
		_notify_seagull_stole(theft_amount)
	if is_instance_valid(seagull_node):
		seagull_node.visible = false
	current_state = State.WAITING
	return_timer.start(randf_range(return_interval_min, return_interval_max))
	_sync_state_to_clients()


@rpc("authority", "call_local", "reliable")
func _notify_seagull_stole(amount: int) -> void:
	var nl := get_node_or_null("/root/main/NotificationLabel") as NotificationLabel
	if nl == null:
		nl = get_node_or_null("../NotificationLabel") as NotificationLabel
	if nl and nl.has_method("show_message"):
		nl.show_message("Seagull stole %d fish!" % amount)


func _on_fishing_paused() -> void:
	if current_state == State.ROAMING or current_state == State.APPROACHING or current_state == State.ATTACKING:
		_trigger_retreat()
	spawn_timer.stop()
	return_timer.stop()
	roam_timer.stop()


func _on_fishing_resumed() -> void:
	match current_state:
		State.INACTIVE:
			spawn_timer.start(randf_range(spawn_interval_min, spawn_interval_max))
		State.WAITING:
			return_timer.start(randf_range(return_interval_min, return_interval_max))
		_:
			pass


@rpc("any_peer", "unreliable", "call_remote")
func repel(hit_origin: Vector3, hit_direction: Vector3) -> void:
	if (current_state != State.ROAMING and current_state != State.APPROACHING) or not is_instance_valid(seagull_node):
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	var seagull_pos := seagull_node.global_position
	var v := seagull_pos - hit_origin
	var dir_norm := hit_direction.normalized()
	var t := v.dot(dir_norm)

	if t < 0:
		return

	var closest_point := hit_origin + t * dir_norm
	if seagull_pos.distance_to(closest_point) <= repel_radius:
		_trigger_retreat()


func _sync_state_to_clients() -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	var has_seagull := is_instance_valid(seagull_node)
	var seagull_pos := seagull_node.position if has_seagull else spawn_position
	_apply_synced_state.rpc(current_state, seagull_pos, spawn_position, has_seagull and seagull_node.visible)


@rpc("authority", "call_local", "reliable")
func _apply_synced_state(state_value: int, seagull_pos: Vector3, synced_spawn_position: Vector3, seagull_visible: bool) -> void:
	current_state = state_value
	spawn_position = synced_spawn_position
	if not is_instance_valid(seagull_node):
		seagull_node = _create_seagull_mesh()
		add_child(seagull_node)
	seagull_node.position = seagull_pos
	seagull_node.visible = seagull_visible


func reset_for_restart() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if is_instance_valid(seagull_node):
		seagull_node.visible = false
	current_state = State.INACTIVE
	spawn_timer.stop()
	return_timer.stop()
	roam_timer.stop()
	spawn_timer.start(randf_range(spawn_interval_min, spawn_interval_max))
	_sync_state_to_clients()


func get_debug_state() -> Dictionary:
	return {
		"state": State.keys()[current_state] if current_state < State.size() else str(current_state),
		"seagull_visible": is_instance_valid(seagull_node) and seagull_node.visible,
		"spawn": str(spawn_position)
	}
