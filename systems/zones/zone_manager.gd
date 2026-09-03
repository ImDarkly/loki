extends Node3D

const NO_ZONE_INDEX: int = -1

@export var min_zone_count: int = 6
@export var max_zone_count: int = 9
@export var zone_radius: float = 1.0
@export var water_boundary_margin: float = 1.5
@export var min_zone_spacing: float = 2.0
@export var reshuffle_interval_min: float = 90.0
@export var reshuffle_interval_max: float = 180.0
@export var yell_scare_radius: float = 8.0
@export var yell_rescare_interval: float = 1.5

var zones: Array[Dictionary] = []
var zone_nodes: Array[MeshInstance3D] = []
var zone_occupant_counts: Array[int] = []
var _peer_zone_occupancy: Dictionary = {}
var _previously_yelling: Dictionary = {}

@onready var reshuffle_timer: Timer = $ReshuffleTimer
@onready var yell_scare_timer: Timer = $YellScareTimer


func _ready() -> void:
	var dbg = get_node_or_null("/root/DebugOverlay")
	if dbg:
		dbg.register_system(name, self)

	reshuffle_timer.one_shot = true
	reshuffle_timer.timeout.connect(_on_reshuffle_timer_timeout)
	yell_scare_timer.timeout.connect(_on_yell_scare_tick)

	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		_generate_zones()
		_start_reshuffle_timer()
		_sync_state_to_clients()
	else:
		set_process(false)
		reshuffle_timer.stop()
		yell_scare_timer.stop()
		return


func _process(_delta: float) -> void:
	_update_yell_scare_state()


func _on_peer_disconnected(id: int) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	_clear_peer_occupancy(id)


func get_zone_index_for_point(point: Vector3) -> int:
	for i in range(zones.size()):
		var zone := zones[i]
		if point.distance_to(zone["center"]) <= zone["radius"]:
			return i
	return NO_ZONE_INDEX


func get_no_zone_index() -> int:
	return NO_ZONE_INDEX


func set_zones(new_zones: Array) -> void:
	zones.clear()
	for zone in new_zones:
		zones.append(zone)
	_rebuild_occupancy_state()
	_update_zone_visuals()


func _generate_zones() -> void:
	zones.clear()
	var count := randi_range(min_zone_count, max_zone_count)
	for _i in range(count):
		zones.append({"center": _pick_zone_center(), "radius": zone_radius})
	zone_occupant_counts.resize(zones.size())
	for i in range(zone_occupant_counts.size()):
		zone_occupant_counts[i] = 0
	_ensure_zone_nodes()
	_update_zone_visuals()


func _pick_zone_center() -> Vector3:
	for _attempt in range(32):
		var candidate := _pick_random_zone_center()
		if _is_valid_zone_position(candidate):
			return candidate

	return MapConfig.MAP_CENTER


func _is_valid_zone_position(candidate: Vector3) -> bool:
	return _is_within_water_boundary(candidate) and _is_clear_of_other_zones(candidate, -1)


@rpc("any_peer", "reliable")
func enter_zone(zone_index: int, peer_id: int = -1) -> void:
	if not _is_valid_zone_index(zone_index):
		return
	var resolved_peer_id := _resolve_peer_id(peer_id)
	if resolved_peer_id == -1:
		return
	_increment_occupancy(zone_index, resolved_peer_id)


@rpc("any_peer", "reliable")
func leave_zone(zone_index: int, peer_id: int = -1) -> void:
	if not _is_valid_zone_index(zone_index):
		return
	var resolved_peer_id := _resolve_peer_id(peer_id)
	if resolved_peer_id == -1:
		return
	_decrement_occupancy(zone_index, resolved_peer_id)


func _resolve_peer_id(peer_id: int) -> int:
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id != 0:
		return sender_id
	if peer_id != -1:
		return peer_id
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		return multiplayer.get_unique_id()
	return -1


func _is_valid_zone_index(zone_index: int) -> bool:
	return zone_index >= 0 and zone_index < zones.size()


func _increment_occupancy(zone_index: int, peer_id: int) -> void:
	zone_occupant_counts[zone_index] += 1
	var peer_occupancy: Dictionary = _peer_zone_occupancy.get(peer_id, {})
	peer_occupancy[zone_index] = int(peer_occupancy.get(zone_index, 0)) + 1
	_peer_zone_occupancy[peer_id] = peer_occupancy


func _decrement_occupancy(zone_index: int, peer_id: int) -> void:
	var peer_occupancy: Dictionary = _peer_zone_occupancy.get(peer_id, {})
	var current_count := int(peer_occupancy.get(zone_index, 0))
	if current_count <= 0:
		return
	zone_occupant_counts[zone_index] = maxi(zone_occupant_counts[zone_index] - 1, 0)
	if current_count == 1:
		peer_occupancy.erase(zone_index)
	else:
		peer_occupancy[zone_index] = current_count - 1
	if peer_occupancy.is_empty():
		_peer_zone_occupancy.erase(peer_id)
	else:
		_peer_zone_occupancy[peer_id] = peer_occupancy


func _clear_peer_occupancy(peer_id: int) -> void:
	var peer_occupancy: Dictionary = _peer_zone_occupancy.get(peer_id, {})
	if peer_occupancy.is_empty():
		return
	for zone_index in peer_occupancy.keys():
		var count := int(peer_occupancy[zone_index])
		zone_occupant_counts[int(zone_index)] = maxi(zone_occupant_counts[int(zone_index)] - count, 0)
	_peer_zone_occupancy.erase(peer_id)


func _rebuild_occupancy_state() -> void:
	zone_occupant_counts.resize(zones.size())
	for i in range(zone_occupant_counts.size()):
		zone_occupant_counts[i] = 0
	_peer_zone_occupancy.clear()


func _start_reshuffle_timer() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var interval := randf_range(reshuffle_interval_min, reshuffle_interval_max)
	reshuffle_timer.start(interval)


func _on_reshuffle_timer_timeout() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	_reshuffle_unoccupied_zones()
	_sync_state_to_clients()
	_start_reshuffle_timer()


func _reshuffle_unoccupied_zones() -> void:
	for i in range(zones.size()):
		if zone_occupant_counts[i] > 0:
			continue
		var next_center := _pick_zone_center_excluding(i)
		zones[i]["center"] = next_center
	_update_zone_visuals()


func _pick_zone_center_excluding(zone_index: int) -> Vector3:
	for _attempt in range(32):
		var candidate := _pick_random_zone_center()
		if _is_valid_zone_position_excluding(candidate, zone_index):
			return candidate

	return zones[zone_index]["center"]


func _is_valid_zone_position_excluding(candidate: Vector3, excluded_index: int) -> bool:
	return _is_within_water_boundary(candidate) and _is_clear_of_other_zones(candidate, excluded_index)


func scare(source_position: Vector3, radius: float) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var affected: Array[int] = []
	for i in range(zones.size()):
		if _flat_distance(source_position, zones[i]["center"]) <= radius:
			affected.append(i)
	if affected.is_empty():
		return
	for i in affected:
		var next_center := _pick_farthest_zone_center(source_position, i)
		if next_center != zones[i]["center"]:
			zones[i]["center"] = next_center
		_interrupt_zone_occupants(i)
	_update_zone_visuals()
	_sync_state_to_clients()


func _pick_farthest_zone_center(source_position: Vector3, zone_index: int) -> Vector3:
	var current_center: Vector3 = zones[zone_index]["center"]
	var best := current_center
	var best_dist := _flat_distance(source_position, current_center)
	for _attempt in range(32):
		var candidate := _pick_random_zone_center()
		if not _is_valid_zone_position_excluding(candidate, zone_index):
			continue
		var dist := _flat_distance(source_position, candidate)
		if dist > best_dist:
			best = candidate
			best_dist = dist
	return best


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _interrupt_zone_occupants(zone_index: int) -> void:
	for peer_id in _peer_zone_occupancy.keys():
		var peer_zones: Dictionary = _peer_zone_occupancy[peer_id]
		if not peer_zones.has(zone_index):
			continue
		# .rpc() reaches remote clients; -1 bypasses the owner filter for single-player.
		if multiplayer.has_multiplayer_peer():
			_broadcast_fish_fled_rpc.rpc(peer_id)
		else:
			_broadcast_fish_fled_rpc(-1)


func _update_yell_scare_state() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var anyone_yelling := false
	for player in _get_player_nodes():
		var player_id := player.get_instance_id()
		var now_yelling: bool = player.get(&"is_yelling") == true
		if now_yelling and not _previously_yelling.get(player_id, false):
			scare(player.global_position, yell_scare_radius)
		if now_yelling:
			anyone_yelling = true
		_previously_yelling[player_id] = now_yelling
	if not anyone_yelling:
		yell_scare_timer.stop()
		_previously_yelling.clear()
		return
	if yell_scare_timer.is_stopped():
		yell_scare_timer.start(yell_rescare_interval)


# Returns yeller count so direct-call tests can assert firing without a running timer.
func _on_yell_scare_tick() -> int:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return 0
	var count := 0
	for player in _get_player_nodes():
		if player.get(&"is_yelling") == true:
			scare(player.global_position, yell_scare_radius)
			count += 1
	return count


func _get_player_nodes() -> Array[Node3D]:
	var players_container := get_node_or_null("../Players")
	if players_container == null:
		return []
	var players: Array[Node3D] = []
	for child in players_container.get_children():
		if child.get_node_or_null("FishingMechanic") != null:
			players.append(child)
	return players


@rpc("authority", "call_local", "reliable")
func _broadcast_fish_fled_rpc(target_client_id: int) -> void:
	for player in _get_player_nodes():
		var mechanic := player.get_node_or_null("FishingMechanic")
		if mechanic:
			mechanic.on_fish_fled(target_client_id)


func _placement_bounds() -> Dictionary:
	return {
		"outer": MapConfig.FISHABLE_BAND_RADIUS - zone_radius - water_boundary_margin,
		"inner": MapConfig.ISLAND_RADIUS + zone_radius + water_boundary_margin,
	}


func _is_within_water_boundary(candidate: Vector3) -> bool:
	var bounds := _placement_bounds()
	if not MapConfig.is_within_radius(candidate, MapConfig.MAP_CENTER, bounds["outer"]):
		return false
	# Zones must sit in the water ring outside the island, not on dry land.
	return not MapConfig.is_within_radius(candidate, MapConfig.MAP_CENTER, bounds["inner"])


func _is_clear_of_other_zones(candidate: Vector3, excluded_index: int) -> bool:
	for i in range(zones.size()):
		if i == excluded_index:
			continue
		var zone := zones[i]
		if candidate.distance_to(zone["center"]) < min_zone_spacing:
			return false
	return true


func _pick_random_zone_center() -> Vector3:
	var bounds := _placement_bounds()
	var outer: float = bounds["outer"]
	var inner: float = bounds["inner"]
	var r := sqrt(randf() * (outer * outer - inner * inner) + inner * inner)
	var angle := randf() * TAU
	var offset := Vector2(cos(angle), sin(angle)) * r
	return Vector3(MapConfig.MAP_CENTER.x + offset.x, 0, MapConfig.MAP_CENTER.z + offset.y)


func _ensure_zone_nodes() -> void:
	while zone_nodes.size() < zones.size():
		var zone_node := _create_zone_marker()
		zone_nodes.append(zone_node)
		add_child(zone_node)
	for i in range(zone_nodes.size()):
		zone_nodes[i].visible = i < zones.size()


func _update_zone_visuals() -> void:
	_ensure_zone_nodes()
	for i in range(zones.size()):
		var zone := zones[i]
		zone_nodes[i].position = zone["center"]
		zone_nodes[i].scale = Vector3(zone["radius"], 1.0, zone["radius"])


func _create_zone_marker() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)

	var segments := 32
	var inner_radius := 0.82
	var outer_radius := 1.0
	for i in range(segments + 1):
		var angle := TAU * float(i) / float(segments)
		var dir := Vector2(cos(angle), sin(angle))
		st.add_vertex(Vector3(dir.x * inner_radius, 0.03, dir.y * inner_radius))
		st.add_vertex(Vector3(dir.x * outer_radius, 0.03, dir.y * outer_radius))

	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.8, 1.0, 0.28)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.mesh = mesh
	mi.material_override = mat
	return mi


func _sync_state_to_clients() -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	var centers: Array[Vector3] = []
	var radii: Array[float] = []
	for zone in zones:
		centers.append(zone["center"])
		radii.append(zone["radius"])
	_apply_synced_state.rpc(centers, radii)


@rpc("authority", "call_local", "reliable")
func _apply_synced_state(centers: Array[Vector3], radii: Array[float]) -> void:
	zones.clear()
	for i in range(centers.size()):
		zones.append({"center": centers[i], "radius": radii[i]})
	_rebuild_occupancy_state()
	_ensure_zone_nodes()
	_update_zone_visuals()


func reset_for_restart() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	_rebuild_occupancy_state()
	reshuffle_timer.stop()
	_start_reshuffle_timer()
	_sync_state_to_clients()


func get_debug_state() -> Dictionary:
	var occupied_zones_count := 0
	var total_occ := 0
	for count in zone_occupant_counts:
		if count > 0:
			occupied_zones_count += 1
		total_occ += count
	return {
		"zone_count": zones.size(),
		"occupied_zones": occupied_zones_count,
		"total_occupants": total_occ,
		"reshuffle_timer_left": max(0, int(ceil(reshuffle_timer.time_left))) if is_instance_valid(reshuffle_timer) else 0,
		"yell_scare_timer_left": max(0, int(ceil(yell_scare_timer.time_left))) if is_instance_valid(yell_scare_timer) else 0
	}


func get_debug_actions() -> Array[Dictionary]:
	return [
		{"id": "reshuffle_zones", "label": "Reshuffle Zones"},
		{"id": "regen_zones", "label": "Regenerate Zones"},
		{"id": "clear_occupancy", "label": "Clear Occupancy"}
	]


func debug_action(action_id: String) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	match action_id:
		"reshuffle_zones":
			_debug_reshuffle_zones()
		"regen_zones":
			_debug_regen_zones()
		"clear_occupancy":
			_debug_clear_occupancy()


func _debug_reshuffle_zones() -> void:
	_reshuffle_unoccupied_zones()
	_sync_state_to_clients()


func _debug_regen_zones() -> void:
	_generate_zones()
	reshuffle_timer.stop()
	_start_reshuffle_timer()
	_sync_state_to_clients()


func _debug_clear_occupancy() -> void:
	_rebuild_occupancy_state()
	_sync_state_to_clients()
