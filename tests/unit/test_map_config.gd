extends GutTest


func test_island_boundary_exactly_at() -> void:
	assert_true(
		MapConfig.is_within_radius(MapConfig.MAP_CENTER + Vector3(MapConfig.ISLAND_RADIUS, 0, 0), MapConfig.MAP_CENTER, MapConfig.ISLAND_RADIUS),
		"Island boundary at exactly radius should be inside"
	)


func test_island_boundary_just_inside() -> void:
	assert_true(
		MapConfig.is_within_radius(MapConfig.MAP_CENTER + Vector3(MapConfig.ISLAND_RADIUS - 0.01, 0, 0), MapConfig.MAP_CENTER, MapConfig.ISLAND_RADIUS),
		"Point just inside island radius should be inside"
	)


func test_island_boundary_just_outside() -> void:
	assert_false(
		MapConfig.is_within_radius(MapConfig.MAP_CENTER + Vector3(MapConfig.ISLAND_RADIUS + 0.01, 0, 0), MapConfig.MAP_CENTER, MapConfig.ISLAND_RADIUS),
		"Point just outside island radius should be outside"
	)


func test_fishable_band_boundary_exactly_at() -> void:
	assert_true(
		MapConfig.is_within_radius(MapConfig.MAP_CENTER + Vector3(0, 0, MapConfig.FISHABLE_BAND_RADIUS), MapConfig.MAP_CENTER, MapConfig.FISHABLE_BAND_RADIUS),
		"Fishable band boundary at exactly radius should be inside"
	)


func test_fishable_band_boundary_just_inside() -> void:
	assert_true(
		MapConfig.is_within_radius(MapConfig.MAP_CENTER + Vector3(0, 0, MapConfig.FISHABLE_BAND_RADIUS - 0.01), MapConfig.MAP_CENTER, MapConfig.FISHABLE_BAND_RADIUS),
		"Point just inside fishable band radius should be inside"
	)


func test_fishable_band_boundary_just_outside() -> void:
	assert_false(
		MapConfig.is_within_radius(MapConfig.MAP_CENTER + Vector3(0, 0, MapConfig.FISHABLE_BAND_RADIUS + 0.01), MapConfig.MAP_CENTER, MapConfig.FISHABLE_BAND_RADIUS),
		"Point just outside fishable band radius should be outside"
	)


func test_height_does_not_affect_boundary_checks() -> void:
	var flat := MapConfig.MAP_CENTER + Vector3(MapConfig.ISLAND_RADIUS - 0.01, 0, 0)
	var raised := MapConfig.MAP_CENTER + Vector3(MapConfig.ISLAND_RADIUS - 0.01, 5.0, 0)
	assert_eq(
		MapConfig.is_within_radius(raised, MapConfig.MAP_CENTER, MapConfig.ISLAND_RADIUS),
		MapConfig.is_within_radius(flat, MapConfig.MAP_CENTER, MapConfig.ISLAND_RADIUS),
		"Y offset should not change the inside/outside result"
	)