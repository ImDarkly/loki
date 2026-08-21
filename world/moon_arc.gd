class_name MoonArc
extends Node3D

const ARC_RADIUS: float = 30.0
const ARC_HEIGHT: float = 15.0


static func calculate_arc_position(progress: float, center: Vector3 = MapConfig.MAP_CENTER, radius: float = ARC_RADIUS, height: float = ARC_HEIGHT) -> Vector3:
	var clamped_progress := clamp(progress, 0.0, 1.0)
	var theta := clamped_progress * PI
	return center + Vector3(cos(theta) * radius, sin(theta) * height, 0.0)
