class_name MoonArc
extends Node3D

const ARC_RADIUS: float = 35.0
const ARC_HEIGHT: float = 22.0

var _round_manager: Node = null
var _last_fishing_active: bool = false
var _local_anchor_time: int = 0

@onready var mesh_instance_3d: MeshInstance3D = $MeshInstance3D
var sprite_3d: MeshInstance3D:
	get:
		return mesh_instance_3d


func _ready() -> void:
	if mesh_instance_3d:
		mesh_instance_3d.visible = false
	else:
		visible = false


func _process(_delta: float) -> void:
	if _round_manager == null:
		_round_manager = get_node_or_null("/root/main/RoundManager")

	if _round_manager:
		var current_fishing: bool = _round_manager.get("fishing_active") if _round_manager.has_method("get") else false
		if current_fishing and not _last_fishing_active:
			_local_anchor_time = Time.get_ticks_msec()
			if mesh_instance_3d:
				mesh_instance_3d.visible = true
			else:
				visible = true
		elif not current_fishing and _last_fishing_active:
			if mesh_instance_3d:
				mesh_instance_3d.visible = false
			else:
				visible = false

		_last_fishing_active = current_fishing

		if current_fishing:
			var elapsed_msec := Time.get_ticks_msec() - _local_anchor_time
			var duration_sec: float = float(_round_manager.get("round_duration")) if _round_manager.has_method("get") and "round_duration" in _round_manager else 900.0
			var duration_msec: float = duration_sec * 1000.0
			var progress: float = float(elapsed_msec) / duration_msec if duration_msec > 0.0 else 0.0
			position = calculate_arc_position(progress)
	else:
		if mesh_instance_3d:
			mesh_instance_3d.visible = false
		else:
			visible = false


static func calculate_arc_position(progress: float, center: Vector3 = MapConfig.MAP_CENTER, radius: float = ARC_RADIUS, height: float = ARC_HEIGHT) -> Vector3:
	var clamped_progress: float = clamp(progress, 0.0, 1.0)
	var theta: float = clamped_progress * PI
	return center + Vector3(cos(theta) * radius, sin(theta) * height, 0.0)
