extends Node3D

enum State { INACTIVE, APPROACHING, ATTACKING, RETREATING, WAITING }

signal fish_fled
signal quota_penalty(amount: int)

@export var respawn_interval_min: float = 45.0
@export var respawn_interval_max: float = 90.0
@export var initial_swim_speed: float = 3.0
@export var attack_range: float = 2.0
@export var repel_radius: float = 2.0
@export var min_spawn_distance_from_player: float = 12.0
@export var bait_priority_range: float = 25.0
@export var shark_bite_damage: int = 2
@export var show_attack_radius: bool = false

var current_state: State = State.INACTIVE
var player_ref: Node3D = null
var shark_node: MeshInstance3D = null
var spawn_position: Vector3
var _is_targeting_bait: bool = false
var _bait_target_position: Vector3 = Vector3.ZERO
var _bait_manager: SharkBaitManager = null
var _debug_spawn_override: Vector3 = Vector3.INF
@onready var spawn_timer: Timer = $SpawnTimer
@onready var return_timer: Timer = $ReturnTimer


func set_bait_manager_for_test(m: SharkBaitManager) -> void:
	_bait_manager = m


func _resolve_bait_manager() -> SharkBaitManager:
	var m := get_node_or_null("../SharkBaitManager") as SharkBaitManager
	if m != null:
		return m
	return get_node_or_null("/root/main/SharkBaitManager") as SharkBaitManager


func _ready() -> void:
	var dbg = get_node_or_null("/root/DebugOverlay")
	if dbg:
		dbg.register_system(name, self)

	_bait_manager = _resolve_bait_manager()

	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		set_physics_process(false)
		spawn_timer.stop()
		return_timer.stop()
		return

	spawn_timer.one_shot = true
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)

	return_timer.one_shot = true
	return_timer.timeout.connect(_on_return_timer_timeout)

	spawn_timer.start(randf_range(30.0, 60.0))


func set_player_ref(player: Node3D) -> void:
	player_ref = player


func _on_spawn_timer_timeout() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if current_state == State.INACTIVE or current_state == State.WAITING:
		if _get_nearest_player() == null:
			return
		_spawn_shark()
		current_state = State.APPROACHING
		_sync_state_to_clients()


func _on_return_timer_timeout() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if current_state == State.WAITING:
		_spawn_shark()
		current_state = State.APPROACHING
		_sync_state_to_clients()


func _get_shark_bait_manager() -> SharkBaitManager:
	if is_instance_valid(_bait_manager):
		return _bait_manager
	_bait_manager = _resolve_bait_manager()
	return _bait_manager


func _is_bait_qualified(spawn_pos: Vector3) -> bool:
	var bm := _get_shark_bait_manager()
	if bm == null or not bm.is_placed:
		return false
	if bm.bait_fill_count != bm.fill_cost:
		return false
	var bait_pos: Vector3 = bm.placed_position
	var d := Vector2(spawn_pos.x - bait_pos.x, spawn_pos.z - bait_pos.z).length()
	return d <= bait_priority_range


func _try_lock_bait(spawn_pos: Vector3) -> bool:
	if _is_bait_qualified(spawn_pos):
		var bm := _get_shark_bait_manager()
		_bait_target_position = Vector3(bm.placed_position.x, 0, bm.placed_position.z)
		_is_targeting_bait = true
		return true
	_is_targeting_bait = false
	return false


func _spawn_shark() -> void:
	var target_player := _get_nearest_player()
	if target_player == null:
		return

	if _debug_spawn_override.is_finite() and _debug_spawn_override != Vector3.INF:
		spawn_position = _debug_spawn_override
	else:
		spawn_position = _pick_spawn_position(target_player)

	_try_lock_bait(spawn_position)

	if not is_instance_valid(shark_node):
		shark_node = _create_shark_mesh()
		add_child(shark_node)

	shark_node.position = spawn_position
	shark_node.visible = true

	var dir: Vector3
	if _is_targeting_bait:
		dir = (Vector3(_bait_target_position.x, 0, _bait_target_position.z) - Vector3(spawn_position.x, 0, spawn_position.z)).normalized()
	else:
		dir = _direction_to_player(spawn_position, target_player)
	if dir.length_squared() > 0.001:
		shark_node.look_at(shark_node.position + dir, Vector3.UP)
	_sync_state_to_clients()


func _pick_spawn_position(target_player: Node3D) -> Vector3:
	var player_pos := target_player.global_position

	for attempt in 10:
		var pos := _random_perimeter_point()
		var dist := Vector2(pos.x - player_pos.x, pos.z - player_pos.z).length()
		if dist >= min_spawn_distance_from_player:
			return pos

	var best_pos := _random_perimeter_point()
	var best_dist := 0.0
	for _i in 20:
		var pos := _random_perimeter_point()
		var dist := Vector2(pos.x - player_pos.x, pos.z - player_pos.z).length()
		if dist > best_dist:
			best_dist = dist
			best_pos = pos
	return best_pos


func _random_perimeter_point() -> Vector3:
	var angle := randf() * TAU
	var dir := Vector2(cos(angle), sin(angle))
	return Vector3(
		MapConfig.MAP_CENTER.x + dir.x * MapConfig.FISHABLE_BAND_RADIUS,
		0,
		MapConfig.MAP_CENTER.z + dir.y * MapConfig.FISHABLE_BAND_RADIUS
	)


func _create_shark_mesh() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var h: float = 0.35
	var hw: float = 0.3
	var d: float = 0.03

	st.set_normal(Vector3(0, 0, -1))
	st.add_vertex(Vector3(0, h, -d / 2.0))
	st.add_vertex(Vector3(-hw, 0.05, -d / 2.0))
	st.add_vertex(Vector3(hw, 0.05, -d / 2.0))

	st.set_normal(Vector3(0, 0, 1))
	st.add_vertex(Vector3(0, h, d / 2.0))
	st.add_vertex(Vector3(hw, 0.05, d / 2.0))
	st.add_vertex(Vector3(-hw, 0.05, d / 2.0))

	var mesh := st.commit()

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.35, 0.35)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.mesh = mesh

	if show_attack_radius:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = attack_range - 0.05
		torus.outer_radius = attack_range + 0.05
		torus.ring_segments = 32
		torus.rings = 8
		ring.mesh = torus
		var ring_mat := StandardMaterial3D.new()
		ring_mat.albedo_color = Color(1.0, 0.2, 0.2, 0.35)
		ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring.material_override = ring_mat
		mi.add_child(ring)

	return mi


func _physics_process(delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	match current_state:
		State.APPROACHING:
			_process_approaching(delta)
		State.RETREATING:
			_process_retreating(delta)


func _process_approaching(delta: float) -> void:
	if not is_instance_valid(shark_node):
		return

	var target: Vector3
	if _is_targeting_bait:
		target = Vector3(_bait_target_position.x, 0, _bait_target_position.z)
	else:
		var target_player := _get_nearest_player()
		if target_player == null:
			return
		target = Vector3(target_player.global_position.x, 0, target_player.global_position.z)
	var current := Vector3(shark_node.position.x, 0, shark_node.position.z)
	var dist := current.distance_to(target)

	if dist <= attack_range:
		_trigger_attack()
		return

	var direction := (target - current).normalized()
	var step: float = minf(initial_swim_speed * delta, dist)
	var new_pos := shark_node.position + direction * step
	if MapConfig.is_within_radius(new_pos, MapConfig.MAP_CENTER, MapConfig.ISLAND_RADIUS):
		new_pos = _clamp_to_island_edge(new_pos)
	shark_node.position = new_pos

	if direction.length_squared() > 0.001:
		shark_node.look_at(shark_node.position + direction, Vector3.UP)
	_sync_state_to_clients()


func _clamp_to_island_edge(pos: Vector3) -> Vector3:
	var flat := Vector2(pos.x - MapConfig.MAP_CENTER.x, pos.z - MapConfig.MAP_CENTER.z)
	if flat.length_squared() <= 0.0001:
		return MapConfig.MAP_CENTER + Vector3(MapConfig.ISLAND_RADIUS, 0, 0)
	flat = flat.normalized() * MapConfig.ISLAND_RADIUS
	return Vector3(MapConfig.MAP_CENTER.x + flat.x, pos.y, MapConfig.MAP_CENTER.z + flat.y)


func _process_retreating(delta: float) -> void:
	if not is_instance_valid(shark_node):
		return

	var target := Vector3(spawn_position.x, 0, spawn_position.z)
	var current := Vector3(shark_node.position.x, 0, shark_node.position.z)
	var direction := (target - current).normalized()
	var step := initial_swim_speed * delta
	var new_pos := shark_node.position + direction * step
	shark_node.position = new_pos

	if direction.length_squared() > 0.001:
		shark_node.look_at(shark_node.position + direction, Vector3.UP)

	var reached_spawn := new_pos.distance_to(target) <= step
	if reached_spawn or not MapConfig.is_within_radius(new_pos, MapConfig.MAP_CENTER, MapConfig.FISHABLE_BAND_RADIUS):
		shark_node.visible = false
		current_state = State.WAITING
		return_timer.start(randf_range(45.0, 90.0))
	_sync_state_to_clients()


@rpc("any_peer", "unreliable", "call_remote")
func repel(hit_origin: Vector3, hit_direction: Vector3) -> void:
	if current_state != State.APPROACHING or not is_instance_valid(shark_node):
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	var shark_pos := shark_node.global_position
	var v := shark_pos - hit_origin
	var dir_norm := hit_direction.normalized()
	var t := v.dot(dir_norm)

	if t < 0:
		return

	var closest_point := hit_origin + t * dir_norm
	if shark_pos.distance_to(closest_point) <= repel_radius:
		_trigger_retreat()


func _trigger_retreat() -> void:
	current_state = State.RETREATING
	_sync_state_to_clients()


func _direction_to_player(from: Vector3, target_player: Node3D) -> Vector3:
	if not is_instance_valid(target_player):
		return Vector3.ZERO
	var target := Vector3(target_player.global_position.x, 0, target_player.global_position.z)
	return (target - Vector3(from.x, 0, from.z)).normalized()


func _get_nearest_player() -> Node3D:
	var players := _get_player_nodes()
	if players.is_empty():
		if not is_instance_valid(player_ref):
			return null
		var hp := player_ref.get_node_or_null("HealthComponent") as HealthComponent
		if hp == null or not hp.is_alive():
			return null
		return player_ref

	var origin := Vector3.ZERO
	if is_instance_valid(shark_node):
		origin = shark_node.global_position
	var best_player: Node3D = null
	var best_dist := INF
	for player in players:
		var dist := origin.distance_to(player.global_position)
		if dist < best_dist:
			best_dist = dist
			best_player = player
	return best_player


func _get_player_nodes() -> Array[Node3D]:
	var players_container := get_node_or_null("../Players")
	if players_container == null:
		return []
	var players: Array[Node3D] = []
	for child in players_container.get_children():
		var player := child as Player
		if player == null:
			continue
		var hp := player.get_node_or_null("HealthComponent") as HealthComponent
		if hp == null or not hp.is_alive():
			continue
		players.append(player)
	return players




func _trigger_attack() -> void:
	if _is_targeting_bait:
		current_state = State.ATTACKING
		var bm := _get_shark_bait_manager()
		if bm != null:
			bm.consume_by_shark()
		if is_instance_valid(shark_node):
			shark_node.visible = false
		current_state = State.WAITING
		_is_targeting_bait = false
		_bait_target_position = Vector3.ZERO
		return_timer.start(randf_range(45.0, 90.0))
		_sync_state_to_clients()
		return
	current_state = State.ATTACKING
	var target_player := _get_nearest_player()
	if target_player != null:
		var target_client_id := _get_player_client_id(target_player)
		if multiplayer.has_multiplayer_peer():
			_broadcast_fish_fled_rpc.rpc(target_client_id)
		else:
			_broadcast_fish_fled_rpc(target_client_id)
		var health := target_player.get_node_or_null("HealthComponent") as HealthComponent
		if health:
			health.take_damage(shark_bite_damage)
	fish_fled.emit()
	if is_instance_valid(shark_node):
		shark_node.visible = false
	current_state = State.WAITING
	return_timer.start(randf_range(45.0, 90.0))
	_sync_state_to_clients()


@rpc("authority", "call_local", "reliable")
func _broadcast_fish_fled_rpc(target_client_id: int) -> void:
	for player in _get_player_nodes():
		var mechanic := player.get_node_or_null("FishingMechanic")
		if mechanic:
			mechanic.on_fish_fled(target_client_id)


func _sync_state_to_clients() -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	# Bait targeting (_is_targeting_bait / _bait_target_position) intentionally not
	# synced: physics and _spawn_shark are server-gated, clients receive
	# authoritative position via _apply_synced_state. Sync bait state if
	# client-side prediction is ever added.
	var has_shark := is_instance_valid(shark_node)
	var shark_pos := shark_node.position if has_shark else spawn_position
	_apply_synced_state.rpc(current_state, shark_pos, spawn_position, has_shark and shark_node.visible)


@rpc("authority", "call_local", "reliable")
func _apply_synced_state(state_value: int, shark_pos: Vector3, synced_spawn_position: Vector3, shark_visible: bool) -> void:
	current_state = state_value
	spawn_position = synced_spawn_position
	if not is_instance_valid(shark_node):
		shark_node = _create_shark_mesh()
		add_child(shark_node)
	shark_node.position = shark_pos
	shark_node.visible = shark_visible


func reset_for_restart() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	_is_targeting_bait = false
	_bait_target_position = Vector3.ZERO
	if is_instance_valid(shark_node):
		shark_node.visible = false
	current_state = State.INACTIVE
	return_timer.stop()
	spawn_timer.start(randf_range(30.0, 60.0))
	_sync_state_to_clients()


func _get_player_client_id(player: Node3D) -> int:
	if not (player is Player):
		return -1
	if player.spawn_index < game_manager.players.size():
		return game_manager.players[player.spawn_index].id
	return -1


func get_debug_state() -> Dictionary:
	return {
		"state": State.keys()[current_state] if current_state < State.size() else str(current_state),
		"targeting_bait": _is_targeting_bait,
		"shark_visible": is_instance_valid(shark_node) and shark_node.visible,
		"spawn": str(spawn_position),
		"spawn_timer_left": max(0, int(ceil(spawn_timer.time_left))) if is_instance_valid(spawn_timer) else 0,
		"return_timer_left": max(0, int(ceil(return_timer.time_left))) if is_instance_valid(return_timer) else 0,
		"shark_pos": str(shark_node.position) if is_instance_valid(shark_node) else str(Vector3.ZERO)
	}


func get_debug_actions() -> Array[Dictionary]:
	return [
		{"id": "force_spawn", "label": "Force Spawn"},
		{"id": "force_retreat", "label": "Force Retreat"},
		{"id": "force_attack", "label": "Force Attack"},
		{"id": "reset_inactive", "label": "Reset Inactive"}
	]


func debug_action(action_id: String) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	match action_id:
		"force_spawn":
			_debug_force_spawn()
		"force_retreat":
			_debug_force_retreat()
		"force_attack":
			_debug_force_attack()
		"reset_inactive":
			_debug_reset_inactive()


func _debug_force_spawn() -> void:
	if _get_nearest_player() == null:
		return
	spawn_timer.stop()
	return_timer.stop()
	_spawn_shark()
	current_state = State.APPROACHING
	_sync_state_to_clients()


func _debug_force_retreat() -> void:
	if current_state == State.INACTIVE or current_state == State.WAITING:
		if _get_nearest_player() == null:
			return
		spawn_timer.stop()
		return_timer.stop()
		_spawn_shark()
		current_state = State.APPROACHING
	_trigger_retreat()


func _debug_force_attack() -> void:
	if current_state == State.INACTIVE or current_state == State.WAITING:
		if _get_nearest_player() == null:
			return
		spawn_timer.stop()
		return_timer.stop()
		_spawn_shark()
		current_state = State.APPROACHING
	_trigger_attack()


func _debug_reset_inactive() -> void:
	reset_for_restart()
