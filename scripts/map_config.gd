class_name MapConfig

const MAP_CENTER: Vector3 = Vector3(0, 0, -7)
const ISLAND_RADIUS: float = 10.0
const FISHABLE_BAND_RADIUS: float = 25.0
const OCEAN_RADIUS: float = 120.0  # seam for the ocean redesign; unused until then
const GROUND_HALF_SIZE: float = 40.0  # transient square land plane until the island redesign lands


static func is_within_radius(point: Vector3, center: Vector3, radius: float) -> bool:
	var flat_point := Vector2(point.x, point.z)
	var flat_center := Vector2(center.x, center.z)
	return flat_point.distance_to(flat_center) <= radius