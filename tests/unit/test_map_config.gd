extends GutTest


func test_oval_land_and_bay_boundaries() -> void:
	assert_true(MapConfig.layout.is_land(Vector3(19.9, 0, 16)))
	assert_false(MapConfig.layout.is_land(Vector3(20.1, 0, 16)))
	assert_true(MapConfig.layout.is_land(Vector3(0, 0, -0.9)))
	assert_false(MapConfig.layout.is_land(Vector3(0, 0, -1.1)))
	assert_false(MapConfig.layout.is_land(Vector3(0, 0, 26)))
	assert_true(MapConfig.layout.is_land(Vector3(8, 0, 26)))
	assert_false(MapConfig.layout.is_land(Vector3(0, 0, 32)))
	assert_false(MapConfig.layout.is_land(Vector3(2.9, 0, 32.5)))
	assert_true(MapConfig.layout.is_land(Vector3(4, 0, 32)))


func test_decks_are_walkable_but_not_natural_land() -> void:
	for point in [Vector3(-16, 0, 0), Vector3(-11.75, 0, 0), Vector3(-9.5, 0, 2), Vector3(0, 0, 22.5)]:
		assert_true(MapConfig.layout.is_walkable(point), str(point))
	assert_false(MapConfig.layout.is_land(Vector3(-16, 0, 0)))
	assert_false(MapConfig.layout.is_land(Vector3(0, 0, 22.5)))
	assert_false(MapConfig.layout.is_walkable(Vector3(2, 0, 24)))


func test_four_spawn_positions_fit_ship_pier() -> void:
	var positions := MapConfig.layout.spawn_positions()
	assert_eq(positions.size(), 4)
	assert_eq(positions[0], Vector3(-10.5, 0, -0.5))
	assert_eq(positions[3], Vector3(-8.5, 0, 0.5))
	for position in positions:
		assert_true(MapConfig.layout.is_walkable(position, 0.4))


func test_rescue_projects_to_safe_shore_or_deck_with_inset() -> void:
	for origin in [Vector3(20.5, -1, 16), Vector3(0, -1, 26), Vector3(-16, -1, -2.5), Vector3(1.5, -1, 22)]:
		var destination := MapConfig.layout.nearest_walkable(origin, 0.4)
		assert_true(MapConfig.layout.is_walkable(destination, 0.39), str(destination))
		assert_almost_eq(destination.y, 0.0, 0.001)
	assert_false(MapConfig.layout.near_walkable(Vector3(0, 0, 26), 0.75))
	assert_true(MapConfig.layout.near_walkable(Vector3(-16, 0, -2.5), 0.75))


func test_rock_placement_excludes_bay_paths_and_building_pads() -> void:
	assert_false(MapConfig.layout.rock_position_allowed(Vector3(0, 0, 26), 0.25))
	assert_false(MapConfig.layout.rock_position_allowed(Vector3(0, 0, 12), 0.25))
	assert_false(MapConfig.layout.rock_position_allowed(Vector3(-12, 0, 18), 0.25))
	assert_false(MapConfig.layout.rock_position_allowed(Vector3(11, 0, 10.2), 0.25))
	assert_true(MapConfig.layout.rock_position_allowed(Vector3(15, 0, 20), 0.25))


func test_shark_projection_stays_in_water_at_outer_and_bay_shores() -> void:
	for point in [Vector3(19.5, 0, 16), Vector3(8, 0, 26), Vector3(0, 0, 18.5)]:
		var projected := MapConfig.layout.nearest_water(point)
		assert_false(MapConfig.layout.is_land(projected), str(projected))


func test_mesh_and_collision_share_faces_and_leave_bay_open() -> void:
	var world = autofree(load("res://world/world_setup.gd").new())
	world.setup_ground()
	world.setup_ground_collision()
	var mesh: Mesh = world.get_node("IslandGround").mesh
	var shape: ConcavePolygonShape3D = world.get_node("IslandCollision").get_child(0).shape
	assert_eq(mesh.get_faces(), shape.get_faces())
	var faces := mesh.get_faces()
	for i in range(0, faces.size(), 3):
		if faces[i].y == 0.0 and faces[i + 1].y == 0.0 and faces[i + 2].y == 0.0:
			var centroid := (faces[i] + faces[i + 1] + faces[i + 2]) / 3.0
			assert_true(MapConfig.layout.is_land(centroid), "Ground triangles cannot fill the bay or opening")


func test_ground_triangles_face_up_and_cliffs_face_outward() -> void:
	var mesh := MapConfig.layout.ground_mesh()
	_assert_ground_winding(mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	_assert_ground_winding(mesh.get_faces())


func _assert_ground_winding(vertices: PackedVector3Array) -> void:
	var top_faces := 0
	var cliff_faces := 0
	for i in range(0, vertices.size(), 3):
		var a := vertices[i]
		var b := vertices[i + 1]
		var c := vertices[i + 2]
		# Godot's front faces wind clockwise; shading normals may blend at cliffs.
		var face_normal := (c - a).cross(b - a).normalized()
		if vertices[i].y == MapConfig.layout.deck_height and vertices[i + 1].y == MapConfig.layout.deck_height and vertices[i + 2].y == MapConfig.layout.deck_height:
			top_faces += 1
			assert_gt(face_normal.dot(Vector3.UP), 0.99, "Every top triangle must face up with normal culling")
		else:
			cliff_faces += 1
			assert_almost_eq(face_normal.y, 0.0, 0.001, "Every cliff face must be vertical")
			var center := (a + b + c) / 3.0
			assert_false(MapConfig.layout.is_land(center + face_normal * 0.001), "Cliff front must face water, including bay and channel edges")
			assert_true(MapConfig.layout.is_land(center - face_normal * 0.001), "Cliff back must face natural land")
	assert_gt(top_faces, 0)
	assert_gt(cliff_faces, 0)


func test_ship_details_stay_inside_footprint_and_are_visual_only() -> void:
	var world = autofree(load("res://world/world_setup.gd").new())
	world._setup_layout()
	var ship: Rect2 = MapConfig.layout.decks["Ship"]
	var details: Array[Dictionary] = MapConfig.layout.ship_boxes()
	assert_eq(details.size(), 6)
	for detail in details:
		var position: Vector3 = detail["position"]
		var size: Vector3 = detail["size"]
		var footprint := Rect2(Vector2(position.x - size.x * 0.5, position.z - size.z * 0.5), Vector2(size.x, size.z))
		assert_true(ship.encloses(footprint), str(detail["name"]))
		var node: Node3D = world.get_node(NodePath(detail["name"]))
		assert_false(node is CollisionObject3D)
		assert_eq(node.find_children("*", "CollisionShape3D", true, false).size(), 0)
	assert_eq(MapConfig.layout.storage_position(), Vector3(-17, 0, 0))
	assert_eq(MapConfig.layout.spawn_positions()[0], Vector3(-10.5, 0, -0.5))


func test_flat_markers_show_plaza_and_creature_water_without_collision() -> void:
	var world = autofree(load("res://world/world_setup.gd").new())
	world._setup_layout()
	var plaza: MeshInstance3D = world.get_node("PlazaMarker")
	var creature: MeshInstance3D = world.get_node("CreatureWaterMarker")
	assert_eq(plaza.position, Vector3(0, 0.02, 6))
	assert_eq(creature.position, Vector3(0, -0.48, 27))
	assert_almost_eq((plaza.mesh as CylinderMesh).top_radius, 3.0, 0.001)
	assert_almost_eq((creature.mesh as CylinderMesh).top_radius, 5.0, 0.001)
	assert_eq(plaza.find_children("*", "CollisionShape3D", true, false).size(), 0)
	assert_eq(creature.find_children("*", "CollisionShape3D", true, false).size(), 0)
	assert_false((creature.material_override as StandardMaterial3D).emission_enabled)


func test_layout_helpers_read_ship_and_lantern_exports() -> void:
	var layout := MapLayout.new()
	layout.ship_details = [{"name": "ShipCabin", "offset": Vector3(1, 2, 0), "size": Vector3(1, 1, 1)}]
	assert_eq(layout.ship_boxes()[0]["position"], Vector3(-15, 2, 0))
	layout.lantern_offset = Vector3(0.5, 2, 1)
	layout.lantern_spacing = 0.5
	layout.lantern_size = Vector3(0.2, 0.4, 0.2)
	var lanterns := layout.lantern_boxes()
	assert_eq(lanterns[0]["position"], Vector3(1.5, 2, 20))
	assert_eq(lanterns[4]["position"], Vector3(1.5, 2, 22))
	assert_eq(lanterns[0]["size"], Vector3(0.2, 0.4, 0.2))


func test_height_does_not_change_land_or_deck_queries() -> void:
	assert_eq(MapConfig.layout.is_land(Vector3(10, 0, 16)), MapConfig.layout.is_land(Vector3(10, 20, 16)))
	assert_eq(MapConfig.layout.is_walkable(Vector3(-16, 0, 0)), MapConfig.layout.is_walkable(Vector3(-16, 20, 0)))


func test_physics_supports_spawns_connectors_and_pier_but_not_bay() -> void:
	var world = autofree(load("res://world/world_setup.gd").new())
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var points := MapConfig.layout.spawn_positions()
	points.append_array([Vector3(-16, 0, 0), Vector3(-11.75, 0, 0), Vector3(-9.5, 0, 2), Vector3(0, 0, 22.5)])
	for point in points:
		var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2, point - Vector3.UP * 2, 1)
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
		assert_false(hit.is_empty(), "Physical support at %s" % point)
		if not hit.is_empty():
			assert_almost_eq(hit["position"].y, 0.0, 0.01)
	for point in [Vector3(0, 0, 26), Vector3(0, 0, 32)]:
		var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.2, point - Vector3.UP * 2, 1)
		assert_true(world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "Open water at %s" % point)
