class_name MapLayout extends Resource

@export var island_center := Vector2(0, 16)
@export var island_half_extents := Vector2(20, 17)
@export var bay_center := Vector2(0, 26)
@export var bay_radius: float = 7.0
@export var channel := Rect2(-3, 30, 6, 6)
@export var path_width: float = 2.5
@export var deck_height: float = 0.0
@export var rail_height: float = 1.1
@export var rail_thickness: float = 0.15
@export var creature_water_center := Vector2(0, 27)
@export var creature_water_radius: float = 5.0
@export var shark_radius: float = 30.0
@export var fishable_radius: float = 40.0
@export var ocean_radius: float = 120.0
@export var decks: Dictionary = {
	"Dock": Rect2(-4, -3, 8, 6), "ShipPier": Rect2(-11.5, -1.5, 4, 3),
	"Ship": Rect2(-20, -2, 8, 4), "ShoreConnector": Rect2(-10.75, 1.5, 2.5, 2),
	"Gangway": Rect2(-12, -1.25, 0.5, 2.5), "CreaturePier": Rect2(-1, 19, 2, 4),
}
@export var pads: Array[Vector2] = [Vector2(-6, 10.4), Vector2(-12, 18), Vector2(6, 6)]
@export var pad_size := Vector2(6, 6)
@export var plaza := Vector2(0, 6)
@export var plaza_radius: float = 3.0
@export var fireplace := Vector2(11, 10.2)
@export var fireplace_size := Vector2(4, 4)
@export var ladders: Array[Vector2] = [Vector2(0, -3), Vector2(-9.5, -1.5)]
@export var ladder_size := Vector2(0.8, 1.5)
@export var storage_offset := Vector2(-1, 0)
@export var spawn_offsets: Array[Vector2] = [Vector2(-1, -0.5), Vector2(1, -0.5), Vector2(-1, 0.5), Vector2(1, 0.5)]
@export var fishing_centers: Array[Vector2] = [
	Vector2(-3.5, -6.1), Vector2(-1.2, -6.9), Vector2(1.2, -6.9), Vector2(3.5, -6.1),
	Vector2(-10.9, -5.1), Vector2(-7.7, -9.2), Vector2(7.7, -9.2), Vector2(10.9, -5.1),
]
@export var fishing_radius: float = 1.0
@export var ship_details: Array[Dictionary] = [
	{"name": "ShipHull", "offset": Vector3(0, -0.55, 0), "size": Vector3(7.6, 0.48, 3.6)},
	{"name": "ShipCabin", "offset": Vector3(-2.8, 0.65, 0.95), "size": Vector3(1.4, 1.3, 1.5)},
	{"name": "ShipMast", "offset": Vector3(2, 1.8, 1.2), "size": Vector3(0.18, 3.6, 0.18)},
	{"name": "ShipCrate1", "offset": Vector3(-2.7, 0.3, -1.2), "size": Vector3(0.6, 0.6, 0.6)},
	{"name": "ShipCrate2", "offset": Vector3(-1.7, 0.25, -1.2), "size": Vector3(0.5, 0.5, 0.5)},
	{"name": "ShipCrate3", "offset": Vector3(2.9, 0.325, -1.2), "size": Vector3(0.65, 0.65, 0.65)},
]
@export var lantern_count: int = 5
@export var lantern_offset := Vector3(0.25, 0.85, 0.4)
@export var lantern_spacing: float = 0.7
@export var lantern_size := Vector3.ONE * 0.25
@export var water_height: float = -0.5
@export var marker_lift: float = 0.02
@export var marker_thickness: float = 0.01

var _land_polygons: Array[PackedVector2Array] = []
var _walkable_polygons: Array[PackedVector2Array] = []


func point3(point: Vector2, height: float = 0.0) -> Vector3:
	return Vector3(point.x, height, point.y)


func _ellipse(center: Vector2, radii: Vector2) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for i in range(128):
		var angle := TAU * float(i) / 128.0
		polygon.append(center + Vector2(cos(angle), sin(angle)) * radii)
	return polygon


func rect_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])


func land_polygons() -> Array[PackedVector2Array]:
	if _land_polygons.is_empty():
		var opening := Geometry2D.merge_polygons(_ellipse(bay_center, Vector2.ONE * bay_radius), rect_polygon(channel))
		_land_polygons = Geometry2D.clip_polygons(_ellipse(island_center, island_half_extents), opening[0])
		# Mesh.get_faces quantizes to 1e-4; triangulate at that precision so tiny ears cannot flip in collision.
		for polygon_index in range(_land_polygons.size()):
			var polygon := _land_polygons[polygon_index]
			for i in range(polygon.size()):
				polygon[i] = polygon[i].snapped(Vector2.ONE * 0.0001)
			_land_polygons[polygon_index] = polygon
	return _land_polygons


func walkable_polygons() -> Array[PackedVector2Array]:
	if _walkable_polygons.is_empty():
		_walkable_polygons = land_polygons().duplicate()
		for rect: Rect2 in decks.values():
			var addition := rect_polygon(rect)
			var remaining: Array[PackedVector2Array] = []
			for polygon in _walkable_polygons:
				var merged := Geometry2D.merge_polygons(polygon, addition)
				if merged.size() == 1:
					addition = merged[0]
				else:
					remaining.append(polygon)
			remaining.append(addition)
			_walkable_polygons = remaining
	return _walkable_polygons


func _edge_distance(point: Vector2, polygon: PackedVector2Array) -> float:
	var distance := INF
	for i in range(polygon.size()):
		distance = minf(distance, point.distance_to(Geometry2D.get_closest_point_to_segment(point, polygon[i], polygon[(i + 1) % polygon.size()])))
	return distance


func _contains(point: Vector2, polygons: Array[PackedVector2Array], inset: float) -> bool:
	for polygon in polygons:
		if Geometry2D.is_point_in_polygon(point, polygon) and (inset <= 0.0 or _edge_distance(point, polygon) >= inset - 0.001):
			return true
	return false


func is_land(point: Vector3, inset: float = 0.0) -> bool:
	return _contains(Vector2(point.x, point.z), land_polygons(), inset)


func is_walkable(point: Vector3, inset: float = 0.0) -> bool:
	return _contains(Vector2(point.x, point.z), walkable_polygons(), inset)


func nearest_walkable(point: Vector3, inset: float = 0.4) -> Vector3:
	var flat := Vector2(point.x, point.z)
	if _contains(flat, walkable_polygons(), inset):
		return point3(flat, deck_height)
	var best := plaza
	var best_distance := INF
	for polygon in walkable_polygons():
		for inner in Geometry2D.offset_polygon(polygon, -inset):
			if Geometry2D.is_polygon_clockwise(inner):
				continue
			for i in range(inner.size()):
				var candidate := Geometry2D.get_closest_point_to_segment(flat, inner[i], inner[(i + 1) % inner.size()])
				var distance := flat.distance_squared_to(candidate)
				if distance < best_distance:
					best = candidate
					best_distance = distance
	return point3(best, deck_height)


func near_walkable(point: Vector3, tolerance: float) -> bool:
	var nearest := nearest_walkable(point, 0.0)
	return Vector2(point.x, point.z).distance_to(Vector2(nearest.x, nearest.z)) <= tolerance


func nearest_water(point: Vector3) -> Vector3:
	var flat := Vector2(point.x, point.z)
	var best := flat
	var best_distance := INF
	for polygon in land_polygons():
		for i in range(polygon.size()):
			var edge := polygon[(i + 1) % polygon.size()] - polygon[i]
			var candidate := Geometry2D.get_closest_point_to_segment(flat, polygon[i], polygon[(i + 1) % polygon.size()])
			candidate += Vector2(edge.y, -edge.x).normalized() * 0.01
			if flat.distance_squared_to(candidate) < best_distance:
				best = candidate
				best_distance = flat.distance_squared_to(candidate)
	return point3(best, point.y)


func spawn_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []
	var pier: Rect2 = decks["ShipPier"]
	for offset in spawn_offsets:
		positions.append(point3(pier.get_center() + offset, deck_height))
	return positions


func storage_position() -> Vector3:
	var ship: Rect2 = decks["Ship"]
	return point3(ship.get_center() + storage_offset, deck_height)


func ship_boxes() -> Array[Dictionary]:
	var boxes: Array[Dictionary] = []
	var ship: Rect2 = decks["Ship"]
	for detail in ship_details:
		boxes.append({"name": detail["name"], "position": point3(ship.get_center(), deck_height) + detail["offset"], "size": detail["size"]})
	return boxes


func lantern_boxes() -> Array[Dictionary]:
	var boxes: Array[Dictionary] = []
	var pier: Rect2 = decks["CreaturePier"]
	for i in range(lantern_count):
		var position := Vector3(pier.end.x, deck_height, pier.position.y) + lantern_offset + Vector3(0, 0, i * lantern_spacing)
		boxes.append({"name": "QuotaLantern%d" % (i + 1), "position": position, "size": lantern_size})
	return boxes


func marker_discs() -> Array[Dictionary]:
	return [
		{"name": "PlazaMarker", "position": point3(plaza, deck_height + marker_lift), "radius": plaza_radius, "height": marker_thickness},
		{"name": "CreatureWaterMarker", "position": point3(creature_water_center, water_height + marker_lift), "radius": creature_water_radius, "height": marker_thickness},
	]


func path_segments() -> Array[PackedVector2Array]:
	var paths: Array[PackedVector2Array] = []
	var dock: Rect2 = decks["Dock"]
	var connector: Rect2 = decks["ShoreConnector"]
	var creature: Rect2 = decks["CreaturePier"]
	for endpoint: Vector2 in [dock.get_center(), Vector2(connector.get_center().x, connector.end.y), fireplace, Vector2(creature.get_center().x, creature.position.y)]:
		paths.append(PackedVector2Array([plaza, endpoint]))
	for pad in pads:
		paths.append(PackedVector2Array([plaza, pad]))
	return paths


func rock_position_allowed(point: Vector3, inset: float) -> bool:
	if not is_land(point, inset):
		return false
	var flat := Vector2(point.x, point.z)
	if flat.distance_to(plaza) <= plaza_radius + inset:
		return false
	for path in path_segments():
		if flat.distance_to(Geometry2D.get_closest_point_to_segment(flat, path[0], path[1])) < path_width * 0.5 + inset:
			return false
	for pad in pads:
		if Rect2(pad - pad_size * 0.5, pad_size).grow(inset).has_point(flat):
			return false
	return not Rect2(fireplace - fireplace_size * 0.5, fireplace_size).grow(inset).has_point(flat)


func is_creature_water(point: Vector3) -> bool:
	return Vector2(point.x, point.z).distance_to(creature_water_center) <= creature_water_radius


func ground_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for polygon in land_polygons():
		var triangles := Geometry2D.triangulate_polygon(polygon)
		for index in triangles:
			surface.add_vertex(point3(polygon[index], deck_height))
		for i in range(polygon.size()):
			var a := point3(polygon[i], deck_height)
			var b := point3(polygon[(i + 1) % polygon.size()], deck_height)
			for vertex: Vector3 in [a, b - Vector3.UP, b, a, a - Vector3.UP, b - Vector3.UP]:
				surface.add_vertex(vertex)
	surface.generate_normals()
	return surface.commit()
