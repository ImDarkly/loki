extends Node3D

const WATER_HALF_SIZE: float = 25.0
const WATER_CENTER: Vector3 = Vector3(0, 0, -7)
const NO_ZONE_INDEX: int = -1

@export var min_zone_count: int = 6
@export var max_zone_count: int = 9
@export var zone_radius: float = 1.0
@export var min_spawn_distance_from_edge: float = 1.5
@export var min_spawn_distance_between_zones: float = 2.0

var zones: Array[Dictionary] = []
var zone_nodes: Array[MeshInstance3D] = []


func _ready() -> void:
	if not multiplayer.is_server():
		set_process(false)
		return

	_generate_zones()
	_sync_state_to_clients()


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
	_update_zone_visuals()


func _generate_zones() -> void:
	zones.clear()
	var count := randi_range(min_zone_count, max_zone_count)
	for _i in range(count):
		zones.append({"center": _pick_zone_center(), "radius": zone_radius})
		_ensure_zone_nodes()
	_update_zone_visuals()


func _pick_zone_center() -> Vector3:
	var half := WATER_HALF_SIZE - zone_radius - min_spawn_distance_from_edge
	var cx := WATER_CENTER.x
	var cz := WATER_CENTER.z

	for _attempt in range(32):
		var candidate := Vector3(
			randf_range(cx - half, cx + half),
			0,
			randf_range(cz - half, cz + half)
		)
		if _is_valid_zone_position(candidate):
			return candidate

	return Vector3(cx, 0, cz)


func _is_valid_zone_position(candidate: Vector3) -> bool:
	for zone in zones:
		if candidate.distance_to(zone["center"]) < zone_radius * 2.0 + min_spawn_distance_between_zones:
			return false
	return true


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
	if not multiplayer.is_server():
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
	_ensure_zone_nodes()
	_update_zone_visuals()


func reset_for_restart() -> void:
	if not multiplayer.is_server():
		return
	_sync_state_to_clients()
