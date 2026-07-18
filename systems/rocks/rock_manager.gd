extends Node3D

const WATER_HALF_SIZE: float = 25.0
const WATER_CENTER: Vector3 = Vector3(0, 0, -7)
const GROUND_HALF_SIZE: float = 40.0
const NO_ROCK_INDEX: int = -1
const _PLACEMENT_ATTEMPTS: int = 32
const _RESPAWN_TICK: float = 1.0

@export var rock_count: int = 15
@export var min_rock_spacing: float = 2.0
@export var respawn_delay: float = 15.0
@export var pickup_range: float = 2.5

var rocks: Array[Dictionary] = []
var rock_nodes: Array[StaticBody3D] = []
var _cooldowns: Array[float] = []

@onready var respawn_timer: Timer = $RespawnTimer


func _ready() -> void:
	respawn_timer.one_shot = false
	respawn_timer.timeout.connect(_on_respawn_tick)

	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_generate_rocks()
		_sync_state_to_clients()
	else:
		set_process(false)
		respawn_timer.stop()
		return


func get_nearest_available_point(from_position: Vector3, range: float) -> int:
	var best_index := NO_ROCK_INDEX
	var best_dist := range
	for i in range(rocks.size()):
		if not rocks[i]["available"]:
			continue
		var d := from_position.distance_to(rocks[i]["position"])
		if d <= best_dist:
			best_dist = d
			best_index = i
	return best_index


func is_point_available(index: int) -> bool:
	if index < 0 or index >= rocks.size():
		return false
	return rocks[index]["available"]


func set_rocks(new_rocks: Array) -> void:
	rocks.clear()
	for rock in new_rocks:
		rocks.append({"position": rock["position"], "available": rock.get("available", true)})
	_cooldowns.resize(rocks.size())
	for i in range(rocks.size()):
		_cooldowns[i] = 0.0
	_ensure_rock_nodes()
	_update_rock_visuals()


@rpc("any_peer", "reliable")
func request_pickup(rock_index: int) -> void:
	if not _is_valid_index(rock_index):
		return
	if not rocks[rock_index]["available"]:
		return

	rocks[rock_index]["available"] = false
	_cooldowns[rock_index] = respawn_delay
	_start_respawn_timer_if_needed()
	_update_rock_visuals()
	_sync_state_to_clients()


func reset_for_restart() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	respawn_timer.stop()
	_generate_rocks()
	_sync_state_to_clients()


func _generate_rocks() -> void:
	rocks.clear()
	for i in range(rock_count):
		rocks.append({"position": _pick_rock_position(), "available": true})
	_cooldowns.resize(rock_count)
	for i in range(rock_count):
		_cooldowns[i] = 0.0
	_ensure_rock_nodes()
	_update_rock_visuals()


func _pick_rock_position() -> Vector3:
	for _attempt in range(_PLACEMENT_ATTEMPTS):
		var candidate := _pick_random_rock_position()
		if _is_valid_rock_position(candidate):
			return candidate
	return _pick_random_rock_position()


func _pick_random_rock_position() -> Vector3:
	var cx := WATER_CENTER.x
	var cz := WATER_CENTER.z
	var wh := WATER_HALF_SIZE
	var gh := GROUND_HALF_SIZE
	var strip := randi() % 4
	match strip:
		0:
			return Vector3(randf_range(cx - gh, cx + gh), 0, randf_range(cz + wh, cz + gh))
		1:
			return Vector3(randf_range(cx - gh, cx + gh), 0, randf_range(cz - gh, cz - wh))
		2:
			return Vector3(randf_range(cx - gh, cx - wh), 0, randf_range(cz - wh, cz + wh))
		3:
			return Vector3(randf_range(cx + wh, cx + gh), 0, randf_range(cz - wh, cz + wh))
	return Vector3(0, 0, 0)


func _is_valid_rock_position(candidate: Vector3) -> bool:
	return _is_on_land(candidate) and _is_clear_of_other_rocks(candidate)


func _is_on_land(candidate: Vector3) -> bool:
	var cx: float = WATER_CENTER.x
	var cz: float = WATER_CENTER.z
	var wh: float = WATER_HALF_SIZE
	var gh: float = GROUND_HALF_SIZE
	return abs(candidate.x - cx) <= gh and abs(candidate.z - cz) <= gh and (abs(candidate.x - cx) > wh or abs(candidate.z - cz) > wh)


func _is_clear_of_other_rocks(candidate: Vector3) -> bool:
	for rock in rocks:
		if candidate.distance_to(rock["position"]) < min_rock_spacing:
			return false
	return true


func _ensure_rock_nodes() -> void:
	while rock_nodes.size() < rocks.size():
		var node := _create_rock_node()
		rock_nodes.append(node)
		add_child(node)
	for i in range(rock_nodes.size()):
		rock_nodes[i].visible = i < rocks.size()


func _update_rock_visuals() -> void:
	_ensure_rock_nodes()
	for i in range(rocks.size()):
		var rock: Dictionary = rocks[i]
		rock_nodes[i].position = rock["position"]
		var available: bool = rock["available"]
		rock_nodes[i].get_node("Mesh").visible = available
		rock_nodes[i].get_node("Collision").disabled = not available


func _create_rock_node() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 4
	body.collision_mask = 4

	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.5, 0.3, 0.5)
	collision.shape = shape
	body.add_child(collision)

	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.5, 0.3, 0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.5, 0.5)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)

	return body


func _start_respawn_timer_if_needed() -> void:
	if not respawn_timer.is_stopped():
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	respawn_timer.start(_RESPAWN_TICK)


func _on_respawn_tick() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var any_active := false
	for i in range(_cooldowns.size()):
		if _cooldowns[i] <= 0.0:
			continue
		_cooldowns[i] -= _RESPAWN_TICK
		if _cooldowns[i] <= 0.0:
			_cooldowns[i] = 0.0
			rocks[i]["available"] = true
		else:
			any_active = true
	_update_rock_visuals()
	_sync_state_to_clients()
	if not any_active:
		respawn_timer.stop()


func _is_valid_index(rock_index: int) -> bool:
	return rock_index >= 0 and rock_index < rocks.size()


func _sync_state_to_clients() -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	var positions: Array[Vector3] = []
	var available: Array[bool] = []
	for rock in rocks:
		positions.append(rock["position"])
		available.append(rock["available"])
	_apply_synced_state.rpc(positions, available)


@rpc("authority", "call_local", "reliable")
func _apply_synced_state(positions: Array[Vector3], available: Array[bool]) -> void:
	rocks.clear()
	for i in range(positions.size()):
		rocks.append({"position": positions[i], "available": available[i]})
	_cooldowns.resize(rocks.size())
	_ensure_rock_nodes()
	_update_rock_visuals()
