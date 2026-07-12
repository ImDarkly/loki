extends Node3D

enum State { INACTIVE, APPROACHING, ATTACKING, RETREATING, WAITING }

signal fish_fled
signal quota_penalty(amount: int)

@export var initial_spawn_delay: float = 60.0
@export var respawn_interval_min: float = 180.0
@export var respawn_interval_max: float = 300.0
@export var initial_swim_speed: float = 3.0
@export var attack_range: float = 2.0
@export var initial_return_delay: float = 4.0
@export var speed_multiplier: float = 1.3
@export var delay_multiplier: float = 0.7
@export var min_swim_speed: float = 8.0
@export var min_return_delay: float = 0.5
@export var min_spawn_distance_from_player: float = 12.0
@export var shark_bite_damage: int = 2

const WATER_HALF_SIZE: float = 25.0
const WATER_CENTER: Vector3 = Vector3(0, 0, -7)

var current_state: State = State.INACTIVE
var player_ref: Node3D = null
var swim_speed: float
var return_delay: float
var shark_node: MeshInstance3D = null
var spawn_position: Vector3
@onready var spawn_timer: Timer = $SpawnTimer
@onready var return_timer: Timer = $ReturnTimer


func _ready() -> void:
	_reset_escalation()

	if not multiplayer.is_server():
		set_physics_process(false)
		spawn_timer.stop()
		return_timer.stop()
		return

	spawn_timer.one_shot = true
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)

	return_timer.one_shot = true
	return_timer.timeout.connect(_on_return_timer_timeout)

	spawn_timer.start(initial_spawn_delay)


func set_player_ref(player: Node3D) -> void:
	player_ref = player


func _reset_escalation() -> void:
	swim_speed = initial_swim_speed
	return_delay = initial_return_delay


func _on_spawn_timer_timeout() -> void:
	if not multiplayer.is_server():
		return
	if current_state == State.INACTIVE or current_state == State.WAITING:
		if _get_nearest_player() == null:
			return
		_spawn_shark()
		current_state = State.APPROACHING
		_sync_state_to_clients()


func _on_return_timer_timeout() -> void:
	if not multiplayer.is_server():
		return
	if current_state == State.WAITING:
		_spawn_shark()
		current_state = State.APPROACHING
		_sync_state_to_clients()


func _spawn_shark() -> void:
	var target_player := _get_nearest_player()
	if target_player == null:
		return

	spawn_position = _pick_spawn_position(target_player)

	if not is_instance_valid(shark_node):
		shark_node = _create_shark_mesh()
		add_child(shark_node)

	shark_node.position = spawn_position
	shark_node.visible = true

	var dir := _direction_to_player(spawn_position, target_player)
	if dir.length_squared() > 0.001:
		shark_node.look_at(shark_node.position + dir, Vector3.UP)
	_sync_state_to_clients()


func _pick_spawn_position(target_player: Node3D) -> Vector3:
	var player_pos := target_player.global_position
	var half := WATER_HALF_SIZE
	var cx := WATER_CENTER.x
	var cz := WATER_CENTER.z

	for attempt in 10:
		var pos := _random_perimeter_point(half, cx, cz)
		var dist := Vector2(pos.x - player_pos.x, pos.z - player_pos.z).length()
		if dist >= min_spawn_distance_from_player:
			return pos

	var best_pos := _random_perimeter_point(half, cx, cz)
	var best_dist := 0.0
	for _i in 20:
		var pos := _random_perimeter_point(half, cx, cz)
		var dist := Vector2(pos.x - player_pos.x, pos.z - player_pos.z).length()
		if dist > best_dist:
			best_dist = dist
			best_pos = pos
	return best_pos


func _random_perimeter_point(half: float, cx: float, cz: float) -> Vector3:
	var edge := randi() % 4
	match edge:
		0:
			return Vector3(randf_range(cx - half, cx + half), 0, cz - half)
		1:
			return Vector3(randf_range(cx - half, cx + half), 0, cz + half)
		2:
			return Vector3(cx - half, 0, randf_range(cz - half, cz + half))
		3:
			return Vector3(cx + half, 0, randf_range(cz - half, cz + half))
	return WATER_CENTER


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

	return mi


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	match current_state:
		State.APPROACHING:
			_process_approaching(delta)
		State.RETREATING:
			_process_retreating(delta)


func _process_approaching(delta: float) -> void:
	var target_player := _get_nearest_player()
	if target_player == null or not is_instance_valid(shark_node):
		return

	if _has_yelling_player():
		_apply_escalation()
		current_state = State.RETREATING
		_sync_state_to_clients()
		return

	var target := Vector3(target_player.global_position.x, 0, target_player.global_position.z)
	var current := Vector3(shark_node.position.x, 0, shark_node.position.z)
	var dist := current.distance_to(target)

	if dist <= attack_range:
		_trigger_attack()
		return

	var direction := (target - current).normalized()
	var step: float = minf(swim_speed * delta, dist)
	shark_node.position += direction * step

	if direction.length_squared() > 0.001:
		shark_node.look_at(shark_node.position + direction, Vector3.UP)
	_sync_state_to_clients()


func _process_retreating(delta: float) -> void:
	if not is_instance_valid(shark_node):
		return

	var target := Vector3(spawn_position.x, 0, spawn_position.z)
	var current := Vector3(shark_node.position.x, 0, shark_node.position.z)
	var direction := (target - current).normalized()
	var new_pos := shark_node.position + direction * swim_speed * delta
	shark_node.position = new_pos

	if direction.length_squared() > 0.001:
		shark_node.look_at(shark_node.position + direction, Vector3.UP)

	var half := WATER_HALF_SIZE
	var cx := WATER_CENTER.x
	var cz := WATER_CENTER.z
	if abs(new_pos.x - cx) > half or abs(new_pos.z - cz) > half:
		shark_node.visible = false
		current_state = State.WAITING
		return_timer.start(return_delay)
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


func _has_yelling_player() -> bool:
	for player in _get_player_nodes():
		if _player_is_yelling(player):
			return true
	if not is_instance_valid(player_ref):
		return false
	var hp := player_ref.get_node_or_null("HealthComponent") as HealthComponent
	if hp == null or not hp.is_alive():
		return false
	return _player_is_yelling(player_ref)


func _player_is_yelling(player: Object) -> bool:
	if player == null:
		return false
	var yelling = player.get("is_yelling")
	return yelling == true


func _apply_escalation() -> void:
	swim_speed = min(swim_speed * speed_multiplier, min_swim_speed)
	return_delay = max(return_delay * delay_multiplier, min_return_delay)


func _trigger_attack() -> void:
	current_state = State.ATTACKING
	var target_player := _get_nearest_player()
	if target_player != null:
		var target_client_id := _get_player_client_id(target_player)
		_broadcast_fish_fled_rpc.rpc(target_client_id)
		var health := target_player.get_node_or_null("HealthComponent") as HealthComponent
		if health:
			health.take_damage(shark_bite_damage)
	fish_fled.emit()
	_reset_escalation()
	if is_instance_valid(shark_node):
		shark_node.visible = false
	var interval := randf_range(respawn_interval_min, respawn_interval_max)
	current_state = State.WAITING
	spawn_timer.start(interval)
	_sync_state_to_clients()


@rpc("authority", "call_local", "reliable")
func _broadcast_fish_fled_rpc(target_client_id: int) -> void:
	for player in _get_player_nodes():
		var mechanic := player.get_node_or_null("FishingMechanic")
		if mechanic:
			mechanic.on_fish_fled(target_client_id)


func _sync_state_to_clients() -> void:
	if not multiplayer.is_server():
		return
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
	if not multiplayer.is_server():
		return
	_reset_escalation()
	if is_instance_valid(shark_node):
		shark_node.visible = false
	current_state = State.INACTIVE
	spawn_timer.start(initial_spawn_delay)
	_sync_state_to_clients()


func _get_player_client_id(player: Node3D) -> int:
	if not (player is Player):
		return -1
	if player.spawn_index < game_manager.players.size():
		return game_manager.players[player.spawn_index].id
	return -1
