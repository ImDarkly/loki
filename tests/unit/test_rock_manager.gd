extends GutTest

var manager: Node3D


func before_each() -> void:
	var scene: PackedScene = load("res://systems/rocks/rock_manager.tscn")
	manager = autofree(scene.instantiate())
	add_child(manager)
	await get_tree().process_frame

	manager.call("set_rocks", [
		{"position": Vector3(30, 0, 0), "available": true},
		{"position": Vector3(-30, 0, 10), "available": true}
	])


func test_point_availability_after_pickup() -> void:
	assert_true(manager.is_point_available(0))
	manager.request_pickup(0)
	assert_false(manager.is_point_available(0))


func test_generated_rocks_stay_on_land_and_clear_routes() -> void:
	manager._generate_rocks()
	assert_eq(manager.rocks.size(), 15)
	for rock in manager.rocks:
		assert_true(MapConfig.layout.rock_position_allowed(rock["position"], manager.ROCK_HALF_EXTENT), str(rock["position"]))
	for i in range(manager.rocks.size()):
		for j in range(i):
			assert_gte(manager.rocks[i]["position"].distance_to(manager.rocks[j]["position"]), manager.min_rock_spacing)


func test_pickup_of_unavailable_is_noop() -> void:
	manager.request_pickup(0)
	assert_false(manager.is_point_available(0))
	manager.request_pickup(0)
	assert_false(manager.is_point_available(0))


func test_nearest_available_found() -> void:
	assert_eq(manager.get_nearest_available_point(Vector3(28, 0, 0), 10.0), 0)


func test_nearest_available_out_of_range() -> void:
	assert_eq(manager.get_nearest_available_point(Vector3(0, 0, 0), 5.0), -1)


func test_nearest_available_skips_depleted() -> void:
	manager.request_pickup(0)
	assert_eq(manager.get_nearest_available_point(Vector3(28, 0, 0), 100.0), 1)


func test_nearest_available_sentinel_when_all_depleted() -> void:
	manager.request_pickup(0)
	manager.request_pickup(1)
	assert_eq(manager.get_nearest_available_point(Vector3(0, 0, 0), 100.0), -1)


func test_respawn_after_delay() -> void:
	manager.request_pickup(0)
	assert_false(manager.is_point_available(0))
	manager._cooldowns[0] = 1.0
	manager._on_respawn_tick()
	assert_true(manager.is_point_available(0))


func test_placement_respects_minimum_spacing() -> void:
	manager.min_rock_spacing = 10.0
	manager.call("set_rocks", [
		{"position": Vector3(30, 0, 0), "available": true},
		{"position": Vector3(-30, 0, 0), "available": true}
	])
	assert_false(manager._is_clear_of_other_rocks(Vector3(35, 0, 0)))
	assert_true(manager._is_clear_of_other_rocks(Vector3(35, 0, 10)))


func test_get_debug_state_keys_and_types() -> void:
	var st = manager.get_debug_state()
	assert_true(st.has("rock_count"))
	assert_true(st.has("available"))
	assert_true(st.has("respawn_timer_left"))
	assert_true(st.has("cooldowns_active"))
	assert_eq(typeof(st["rock_count"]), TYPE_INT)
	assert_eq(typeof(st["available"]), TYPE_INT)
	assert_eq(typeof(st["respawn_timer_left"]), TYPE_INT)
	assert_eq(typeof(st["cooldowns_active"]), TYPE_INT)


func test_get_debug_actions_ids_and_labels() -> void:
	var acts = manager.get_debug_actions()
	assert_eq(acts.size(), 2)
	var map = {}
	for act in acts:
		map[act["id"]] = act["label"]
	assert_eq(map.get("respawn_all"), "Respawn All")
	assert_eq(map.get("clear_all"), "Clear All")


func test_debug_actions_execution() -> void:
	assert_true(manager.is_point_available(0))
	manager.debug_action("clear_all")
	assert_false(manager.is_point_available(0), "clear_all should make rocks unavailable")
	manager.debug_action("respawn_all")
	assert_true(manager.is_point_available(0), "respawn_all should restore rock availability")


func test_debug_action_client_noop() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", 1)
	manager.multiplayer.multiplayer_peer = peer
	manager.debug_action("clear_all")
	assert_true(manager.is_point_available(0), "Client should no-op debug_action")
	manager.multiplayer.multiplayer_peer = null


func test_rock_manager_registers_with_debug_overlay() -> void:
	var dbg = get_node_or_null("/root/DebugOverlay")
	assert_not_null(dbg, "DebugOverlay autoload missing")
	assert_true(dbg._systems.has(manager.name), "RockManager should register with DebugOverlay")


func test_sourced_rock_fits_pickup_collision_and_hides_until_respawn() -> void:
	var rock := manager.rock_nodes[0] as StaticBody3D
	var visual := rock.get_node("Mesh") as MeshInstance3D
	var collision := rock.get_node("Collision") as CollisionShape3D
	assert_not_null(visual.mesh, "Pickup rock must remain visible without optional assets")
	assert_eq(collision.shape.size, Vector3(0.5, 0.3, 0.5))
	assert_eq(rock.collision_layer, 4)
	assert_eq(rock.collision_mask, 4)
	if visual.mesh:
		var bounds: AABB = visual.transform * visual.mesh.get_aabb()
		var expected_size := Vector3(0.5, 0.3, 0.5) if visual.material_override else Vector3(0.325, 0.195, 0.325)
		assert_almost_eq(bounds.size, expected_size, Vector3.ONE * 0.001)
		assert_true(AABB(-collision.shape.size * 0.5, collision.shape.size).encloses(bounds), "Smaller rock stays inside pickup collision")
		assert_almost_eq(bounds.get_center(), Vector3.ZERO, Vector3.ONE * 0.001)
	manager.request_pickup(0)
	assert_false(visual.visible)
	assert_true(collision.disabled)
	manager._cooldowns[0] = 1.0
	manager._on_respawn_tick()
	assert_true(visual.visible)
	assert_false(collision.disabled)


func test_missing_and_unusable_rock_slots_keep_primitives_and_valid_variants() -> void:
	var first_mesh := SphereMesh.new()
	var fourth_mesh := SphereMesh.new()
	var flat_mesh := PlaneMesh.new()
	manager._rock_meshes.clear()
	for mesh in [first_mesh, null, flat_mesh, fourth_mesh, null]:
		manager._rock_meshes.append(mesh)
	for node in manager.rock_nodes:
		node.free()
	manager.rock_nodes.clear()
	var points: Array = []
	for i in range(6):
		points.append({"position": Vector3(i * 3, 0, 0), "available": true})
	manager.set_rocks(points)
	for i in [1, 2, 4]:
		var visual := manager.rock_nodes[i].get_node("Mesh") as MeshInstance3D
		assert_true(visual.mesh is BoxMesh)
		assert_eq(visual.mesh.size, Vector3(0.5, 0.3, 0.5))
		assert_eq(visual.scale, Vector3.ONE)
		assert_eq(visual.position, Vector3.ZERO)
		var material := visual.material_override as StandardMaterial3D
		assert_not_null(material)
		if material:
			assert_eq(material.albedo_color, Color(0.5, 0.5, 0.5))
			assert_eq(material.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED)
		manager.request_pickup(i)
		assert_false(visual.visible)
		manager._cooldowns[i] = 1.0
		manager._on_respawn_tick()
		assert_true(visual.visible)
	assert_eq(manager.rock_nodes[0].get_node("Mesh").mesh, first_mesh)
	assert_eq(manager.rock_nodes[3].get_node("Mesh").mesh, fourth_mesh)
	assert_eq(manager.rock_nodes[5].get_node("Mesh").mesh, first_mesh)
	assert_null(manager.rock_nodes[0].get_node("Mesh").material_override)


func test_pickup_rocks_cycle_five_shapes_and_keep_each_shape_after_respawn() -> void:
	for variant in range(1, 6):
		if not ResourceLoader.exists("res://world/assets/quaternius_pirate/Environment_Rock_%d.gltf" % variant):
			pending("Install and import all five Pirate Kit rock variants to check visual variety")
			return
	var points: Array = []
	for i in range(6):
		points.append({"position": Vector3(i * 3, 0, 0), "available": true})
	manager.set_rocks(points)
	var meshes: Array[Mesh] = []
	for i in range(5):
		var rock := manager.rock_nodes[i] as StaticBody3D
		var visual := rock.get_node("Mesh") as MeshInstance3D
		var collision := rock.get_node("Collision") as CollisionShape3D
		assert_not_null(visual.mesh)
		if not visual.mesh:
			return
		assert_false(meshes.has(visual.mesh), "First five pickup rocks should each have a distinct sourced shape")
		meshes.append(visual.mesh)
		assert_eq(collision.shape.size, Vector3(0.5, 0.3, 0.5))
		assert_eq(rock.collision_layer, 4)
		assert_eq(rock.collision_mask, 4)
		var bounds: AABB = visual.transform * visual.mesh.get_aabb()
		assert_almost_eq(bounds.size, Vector3(0.325, 0.195, 0.325), Vector3.ONE * 0.001)
		assert_true(AABB(-collision.shape.size * 0.5, collision.shape.size).encloses(bounds), "Every variant stays inside pickup collision")
		assert_almost_eq(bounds.get_center(), Vector3.ZERO, Vector3.ONE * 0.001)
		manager.request_pickup(i)
		assert_false(visual.visible)
		manager._cooldowns[i] = 1.0
		manager._on_respawn_tick()
		assert_true(visual.visible)
		assert_eq(visual.mesh, meshes[i], "Respawning should keep the same rock shape")
	assert_eq(manager.rock_nodes[5].get_node("Mesh").mesh, meshes[0], "Sixth pickup rock should reuse the first shape")
