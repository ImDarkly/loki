class_name MapConfig

static var layout: MapLayout = preload("res://scripts/island_layout.tres")

static var MAP_CENTER: Vector3:
	get:
		return layout.point3(layout.island_center)
static var FISHABLE_BAND_RADIUS: float:
	get:
		return layout.fishable_radius
static var OCEAN_RADIUS: float:
	get:
		return layout.ocean_radius


static func is_within_radius(point: Vector3, center: Vector3, radius: float) -> bool:
	var flat_point := Vector2(point.x, point.z)
	var flat_center := Vector2(center.x, center.z)
	return flat_point.distance_to(flat_center) <= radius
