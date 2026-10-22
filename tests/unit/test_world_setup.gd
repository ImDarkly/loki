extends GutTest

var _world: Node3D


func before_each() -> void:
	_world = autofree(load("res://world/world_setup.gd").new())


func test_dressing_contains_only_sourced_meshes_without_physics() -> void:
	_world._setup_island_dressing()
	var dressing := _world.get_node_or_null("IslandDressing")
	assert_not_null(dressing)
	if dressing == null:
		return
	assert_gt(dressing.get_child_count(), 20)
	for child in dressing.get_children():
		assert_true(child is MeshInstance3D)
		assert_eq(child.get_child_count(), 0, "Dressing cannot contain hidden collision or navigation nodes")
		if child is MeshInstance3D:
			assert_not_null(child.mesh)
			assert_false(child.material_override.emission_enabled)
			assert_eq(child.material_override.roughness, 1.0)


func test_transformed_rock_bounds_keep_routes_decks_and_interactions_clear() -> void:
	_world._setup_island_dressing()
	var dressing := _world.get_node_or_null("IslandDressing")
	assert_not_null(dressing)
	if dressing == null:
		return
	var layout := MapConfig.layout
	var crowns := 0
	var supports := 0
	var shore_rocks := 0
	var bay_rocks := 0
	var slab_bounds := AABB()
	var support_bounds: Array[AABB] = []
	for rock: MeshInstance3D in dressing.get_children():
		if str(rock.name).begins_with("ShoreRock"):
			shore_rocks += 1
		if str(rock.name).begins_with("BayRock"):
			bay_rocks += 1
		var bounds: AABB = rock.transform * rock.get_aabb()
		if str(rock.name).contains("ArchCrown"):
			crowns += 1
			slab_bounds = bounds
			assert_gt(bounds.position.y, 3.0, "Arch underside clears a standing player")
			continue
		if str(rock.name).contains("ArchSupport"):
			supports += 1
			support_bounds.append(bounds)
		var footprint := Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z))
		if not str(rock.name).contains("ArchSupport"):
			assert_gte(footprint.position.y, layout.decks["Dock"].end.y + _world.dock_clearance_depth - 0.0001, "The broad dock side stays open")
			var arch_point := Vector2(layout.channel.get_center().x + _world.arch_offset.x, layout.channel.position.y + _world.arch_offset.z)
			assert_gte(arch_point.distance_to(arch_point.clamp(footprint.position, footprint.end)), _world.arch_clearance_radius - 0.0001, "Incidental stones leave the arch silhouette clear")
		assert_false(footprint.intersects(layout.channel), "Bay opening remains visibly open")
		for deck: Rect2 in layout.decks.values():
			assert_false(footprint.intersects(deck.grow(0.4)), "Deck and ladder access remain clear")
		for spawn in layout.spawn_positions():
			assert_false(footprint.grow(0.4).has_point(Vector2(spawn.x, spawn.z)))
		for pad in layout.pads:
			assert_false(footprint.intersects(Rect2(pad - layout.pad_size * 0.5, layout.pad_size)))
		assert_false(footprint.intersects(Rect2(layout.fireplace - layout.fireplace_size * 0.5, layout.fireplace_size)))
		for route in layout.path_segments():
			var direction: Vector2 = (route[1] - route[0]).normalized()
			var side := direction.orthogonal() * layout.path_width * 0.5
			var corridor := PackedVector2Array([route[0] + side, route[1] + side, route[1] - side, route[0] - side])
			assert_true(Geometry2D.intersect_polygons(corridor, layout.rect_polygon(footprint)).is_empty(), "Full route width remains visible")
	assert_eq(crowns, 1, "One flattened sourced stone spans the arch")
	assert_eq(supports, 2)
	assert_lt(slab_bounds.size.y / slab_bounds.size.x, 0.15, "The crown reads as a flat slab")
	for support in support_bounds:
		assert_lte(slab_bounds.position.x, support.get_center().x)
		assert_gte(slab_bounds.end.x, support.get_center().x)
	assert_gt(shore_rocks, 15, "Outer shore dressing is present")
	assert_gt(bay_rocks, 3, "Inner bay dressing is present")


func test_shores_use_five_natural_variants_with_clustered_irregular_spacing() -> void:
	_world._setup_island_dressing()
	var dressing := _world.get_node_or_null("IslandDressing")
	assert_not_null(dressing)
	if dressing == null:
		return
	var meshes: Dictionary = {}
	var scales: Dictionary = {}
	var headings: Dictionary = {}
	var centers: Array[Vector2] = []
	var angles: Array[float] = []
	var west_rocks := 0
	var east_rocks := 0
	for rock: MeshInstance3D in dressing.get_children():
		if str(rock.name).begins_with("Arch"):
			continue
		meshes[rock.mesh] = true
		scales[snappedf(rock.scale.x, 0.01)] = true
		headings[snappedf(rock.rotation.y, 0.01)] = true
		assert_almost_eq(rock.scale.x, rock.scale.y, 0.00001, "Uniform scale preserves the source silhouette")
		assert_almost_eq(rock.scale.x, rock.scale.z, 0.00001)
		if str(rock.name).begins_with("ShoreRock"):
			var bounds: AABB = rock.transform * rock.get_aabb()
			var center := Vector2(bounds.get_center().x, bounds.get_center().z)
			centers.append(center)
			angles.append((center - MapConfig.layout.island_center).angle())
			if center.x < MapConfig.layout.island_center.x:
				west_rocks += 1
			else:
				east_rocks += 1
	assert_eq(meshes.size(), 5, "All five actual mesh resources appear on the shores")
	assert_gt(scales.size(), 10)
	assert_gt(headings.size(), 10)
	assert_gt(west_rocks, 5, "Clusters dress the west coast")
	assert_gt(east_rocks, 5, "Clusters dress the east coast")
	var close_neighbors := 0
	for i in range(centers.size()):
		for j in range(i + 1, centers.size()):
			if centers[i].distance_to(centers[j]) < 2.0:
				close_neighbors += 1
	assert_gt(close_neighbors, 5, "Small stones cluster beside boulders")
	angles.sort()
	var minimum_gap := TAU
	var maximum_gap := 0.0
	for i in range(1, angles.size()):
		var gap: float = angles[i] - angles[i - 1]
		minimum_gap = minf(minimum_gap, gap)
		maximum_gap = maxf(maximum_gap, gap)
	assert_gt(maximum_gap, minimum_gap * 5.0, "Shore rocks do not form an evenly spaced ring")


func test_rocks_share_a_subtle_matte_earth_and_slate_palette() -> void:
	_world._setup_island_dressing()
	var dressing := _world.get_node_or_null("IslandDressing")
	assert_not_null(dressing)
	if dressing == null:
		return
	var uses: Dictionary = {}
	var colors: Dictionary = {}
	for rock: MeshInstance3D in dressing.get_children():
		var material: StandardMaterial3D = rock.material_override
		uses[material] = uses.get(material, 0) + 1
		colors[material.albedo_color] = true
		assert_eq(material.roughness, 1.0)
		assert_false(material.emission_enabled)
		assert_lte(absf(material.albedo_color.b - material.albedo_color.r), 0.050001, "Rock tints stay neutral")
	assert_gte(uses.size(), 3)
	assert_lte(uses.size(), 4, "Palette resources are shared rather than allocated per stone")
	assert_eq(colors.size(), uses.size(), "Palette entries have distinct tints")
	for count: int in uses.values():
		assert_gt(count, 1)


func test_local_cosmetic_seed_reproduces_the_same_meshes_and_transforms() -> void:
	_world._setup_island_dressing()
	var another: Node3D = autofree(load("res://world/world_setup.gd").new())
	another._setup_island_dressing()
	var first := _world.get_node_or_null("IslandDressing")
	var second := another.get_node_or_null("IslandDressing")
	assert_not_null(first)
	assert_not_null(second)
	if first == null or second == null:
		return
	assert_eq(first.get_child_count(), second.get_child_count())
	for i in range(first.get_child_count()):
		assert_eq(first.get_child(i).mesh, second.get_child(i).mesh)
		assert_eq(first.get_child(i).transform, second.get_child(i).transform)


func test_dressing_preserves_existing_geometry_and_positions() -> void:
	_world.setup_ground()
	_world.setup_ground_collision()
	_world._setup_layout()
	var transforms: Dictionary = {}
	for child: Node3D in _world.get_children():
		transforms[child] = child.transform
	var shape: ConcavePolygonShape3D = _world.get_node("IslandCollision").get_child(0).shape
	var faces := shape.get_faces()
	var spawns := MapConfig.layout.spawn_positions().duplicate()
	var storage := MapConfig.layout.storage_position()
	_world._setup_island_dressing()
	for child: Node3D in transforms:
		assert_eq(child.transform, transforms[child], str(child.name))
	assert_eq(shape.get_faces(), faces)
	assert_eq(MapConfig.layout.spawn_positions(), spawns)
	assert_eq(MapConfig.layout.storage_position(), storage)


func test_horizon_fog_preserves_regular_compatibility_settings() -> void:
	_world.setup_environment()
	var environment: Environment = _world.get_node("WorldEnvironment").environment
	assert_true(environment.fog_enabled)
	assert_false(environment.volumetric_fog_enabled)
	assert_gt(environment.fog_density, 0.02)
	assert_almost_eq(environment.fog_density, _world.fog_density, 0.000001)
	assert_almost_eq(environment.fog_sky_affect, 0.05, 0.000001)


class FogRoundManager extends Node:
	var fishing_active := false
	var round_duration := 1000000.0


func test_fog_matches_shader_horizon_colors_at_light_endpoints() -> void:
	add_child(_world)
	_world.set_process(false)
	_world._round_manager = autofree(FogRoundManager.new())
	var environment: Environment = _world.get_node("WorldEnvironment").environment
	for endpoint in [[-PI * 0.5, "horizon_day"], [0.0, "horizon_sunset"], [PI * 0.5, "horizon_night"]]:
		_world._directional_light.rotation.x = endpoint[0]
		_world._process(0.0)
		var expected: Color = _world._sky_material.get_shader_parameter(endpoint[1])
		_assert_color_close(environment.fog_light_color, expected)


func test_fog_follows_fishing_sunset_night_and_shop_snapback() -> void:
	add_child(_world)
	_world.set_process(false)
	var round_manager: FogRoundManager = autofree(FogRoundManager.new())
	_world._round_manager = round_manager
	var environment: Environment = _world.get_node("WorldEnvironment").environment
	var initial_day := environment.fog_light_color
	round_manager.fishing_active = true
	_world._process(0.0)
	var sunset: Color = _world._sky_material.get_shader_parameter("horizon_sunset")
	_assert_color_close(environment.fog_light_color, sunset)
	_world._fishing_anchor_msec = Time.get_ticks_msec() - 500000000
	_world._process(0.0)
	var night: Color = _world._sky_material.get_shader_parameter("horizon_night")
	_assert_color_close(environment.fog_light_color, night)
	round_manager.fishing_active = false
	_world._process(0.0)
	_assert_color_close(environment.fog_light_color, initial_day)


func _assert_color_close(actual: Color, expected: Color) -> void:
	for channel in range(3):
		assert_almost_eq(actual[channel], expected[channel], 0.000001)
