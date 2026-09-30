extends GutTest


var world_setup: Node3D
var _main: Node3D
var round_manager: Node


class MockRoundManager extends Node:
	var fishing_active := false
	var round_duration := 10.0


func before_each() -> void:
	print("before_each start")
	var old_main := get_node_or_null("/root/main")
	if old_main:
		old_main.free()
	_main = Node3D.new()
	_main.name = "main"
	get_node("/root").add_child(_main)

	round_manager = MockRoundManager.new()
	round_manager.name = "RoundManager"
	_main.add_child(round_manager)

	var world_setup_script = load("res://world/world_setup.gd")
	world_setup = world_setup_script.new() as Node3D
	_main.add_child(world_setup)
	await get_tree().process_frame
	print("before_each end")


func after_each() -> void:
	var main := get_node_or_null("/root/main")
	if main:
		main.queue_free()
	world_setup = null
	_main = null
	round_manager = null


func test_world_environment_sky_material_is_shader() -> void:
	var world_env := world_setup.get_node_or_null("WorldEnvironment") as WorldEnvironment
	assert_true(is_instance_valid(world_env), "WorldEnvironment should be instantiated")
	assert_true(is_instance_valid(world_env.environment), "Environment should be set")
	assert_true(is_instance_valid(world_env.environment.sky), "Sky should be set")
	assert_true(world_env.environment.sky.sky_material is ShaderMaterial, "Sky sky_material should be ShaderMaterial")


func test_light_holds_daytime_rotation_across_frames() -> void:
	var light: DirectionalLight3D = world_setup._directional_light
	assert_true(is_instance_valid(light), "DirectionalLight3D should exist")
	
	assert_almost_eq(light.rotation.x, -1.0, 0.001, "Light rotation X should be -1.0")
	assert_almost_eq(light.rotation.y, 0.5, 0.001, "Light rotation Y should be 0.5")
	assert_almost_eq(light.rotation.z, 0.0, 0.001, "Light rotation Z should be 0.0")
	assert_eq(light.light_energy, 1.0, "Light energy should be 1.0")
	assert_eq(light.light_color, Color.WHITE, "Light color should be white")

	round_manager.fishing_active = false
	world_setup._process(0.01)
	assert_almost_eq(light.rotation.x, -1.0, 0.001, "Light rotation X should hold across frames")
	assert_eq(light.light_energy, 1.0, "Light energy should hold across frames")
	assert_eq(light.light_color, Color.WHITE, "Light color should hold across frames")


func test_toggling_mock_snaps_ground_water_albedos_while_light_unchanged() -> void:
	var light: DirectionalLight3D = world_setup._directional_light
	var ground_mat: ORMMaterial3D = world_setup._ground_mat
	var water_mat: ORMMaterial3D = world_setup._water_mat

	# Day initial
	round_manager.fishing_active = false
	world_setup._process(0.01)
	assert_eq(ground_mat.albedo_color, Color(0.90, 0.56, 0.31), "Ground albedo should be day")
	assert_eq(water_mat.albedo_color, Color(0.04, 0.54, 0.56), "Water albedo should be day")
	assert_eq(light.light_energy, 1.0, "Light energy unchanged")
	assert_eq(light.light_color, Color.WHITE, "Light color unchanged")

	# Night transition
	round_manager.fishing_active = true
	world_setup._process(0.01)
	assert_eq(ground_mat.albedo_color, Color(0.24, 0.21, 0.27), "Ground albedo should snap to night")
	assert_eq(water_mat.albedo_color, Color(0.04, 0.37, 0.40), "Water albedo should snap to night")
	assert_eq(light.light_energy, 1.0, "Light energy remains unchanged (no drift)")
	assert_eq(light.light_color, Color.WHITE, "Light color remains unchanged (no drift)")

	# Return to day
	round_manager.fishing_active = false
	world_setup._process(0.01)
	assert_eq(ground_mat.albedo_color, Color(0.90, 0.56, 0.31), "Ground albedo returns to day")
	assert_eq(water_mat.albedo_color, Color(0.04, 0.54, 0.56), "Water albedo returns to day")


func test_no_procedural_sky_material_remains() -> void:
	var world_env := world_setup.get_node_or_null("WorldEnvironment") as WorldEnvironment
	assert_false(world_env.environment.sky.sky_material is ProceduralSkyMaterial, "No ProceduralSkyMaterial should remain")


func test_star_noise_matches_b9a5709_baseline() -> void:
	# b9a5709 baseline star noise parameters with wind-only deviation.
	# NoiseTexture2D.generate_mipmaps defaults to true in Godot 4.6, and
	# b9a5709 .tres files have no explicit generate_mipmaps line.
	var stars_1 := load("res://world/sky/stars_01.tres") as NoiseTexture2D
	var stars_2 := load("res://world/sky/stars_02.tres") as NoiseTexture2D
	assert_true(is_instance_valid(stars_1), "stars_01.tres should load")
	assert_true(is_instance_valid(stars_2), "stars_02.tres should load")
	var noise_1 := stars_1.noise as FastNoiseLite
	var noise_2 := stars_2.noise as FastNoiseLite
	assert_true(is_instance_valid(noise_1), "stars_01 noise should be FastNoiseLite")
	assert_true(is_instance_valid(noise_2), "stars_02 noise should be FastNoiseLite")
	assert_eq(noise_1.noise_type, FastNoiseLite.TYPE_SIMPLEX, "stars_01 should use simplex noise")
	assert_eq(noise_2.noise_type, FastNoiseLite.TYPE_SIMPLEX, "stars_02 should use simplex noise")
	assert_almost_eq(noise_1.frequency, 0.08, 0.001, "stars_01 frequency at b9a5709 baseline 0.08")
	assert_almost_eq(noise_2.frequency, 0.02, 0.001, "stars_02 frequency at b9a5709 baseline 0.02")
	assert_eq(noise_1.fractal_octaves, 4, "stars_01 octaves at b9a5709 baseline 4")
	assert_eq(noise_2.fractal_octaves, 2, "stars_02 octaves at b9a5709 baseline 2")
	assert_true(stars_1.generate_mipmaps, "stars_01 generate_mipmaps inherits engine default true at b9a5709 baseline")
	assert_true(stars_2.generate_mipmaps, "stars_02 generate_mipmaps inherits engine default true at b9a5709 baseline")


func test_wind_speed_tuned_slower_than_shader_default() -> void:
	var wind: Vector2 = world_setup._sky_material.get_shader_parameter("wind_speed")
	assert_almost_eq(wind.x, 0.025, 0.001, "wind_speed.x tuned slower than 0.5 default")
	assert_almost_eq(wind.y, 0.025, 0.001, "wind_speed.y tuned slower than 0.5 default")
	var tiling = world_setup._sky_material.get_shader_parameter("cloud_tiling")
	assert_null(tiling, "cloud_tiling should keep shader default (no override)")


func test_pitch_for_progress_values() -> void:
	var world_setup_script = load("res://world/world_setup.gd")
	assert_almost_eq(world_setup_script.pitch_for_progress(0.0), 0.0, 0.001, "0 -> 0.0")
	assert_almost_eq(world_setup_script.pitch_for_progress(0.25), 0.725, 0.001, "0.25 -> 0.725")
	assert_almost_eq(world_setup_script.pitch_for_progress(0.5), 1.45, 0.001, "0.5 -> 1.45")
	assert_almost_eq(world_setup_script.pitch_for_progress(0.75), 0.725, 0.001, "0.75 -> 0.725")
	assert_almost_eq(world_setup_script.pitch_for_progress(1.0), 0.0, 0.001, "1.0 -> 0.0")
	assert_almost_eq(world_setup_script.pitch_for_progress(-0.5), 0.0, 0.001, "clamping negative -> 0.0")
	assert_almost_eq(world_setup_script.pitch_for_progress(1.5), 0.0, 0.001, "clamping positive -> 0.0")
	var slope_sunset = (world_setup_script.pitch_for_progress(0.5) - world_setup_script.pitch_for_progress(0.0)) / 0.5
	var slope_sunrise = (world_setup_script.pitch_for_progress(1.0) - world_setup_script.pitch_for_progress(0.5)) / 0.5
	assert_almost_eq(slope_sunset, 2.9, 0.001, "Sunset slope is 2.9")
	assert_almost_eq(slope_sunrise, -2.9, 0.001, "Sunrise slope is -2.9")
	assert_true(slope_sunset != slope_sunrise, "Sweep is asymmetric")


func test_yaw_for_progress_values() -> void:
	var world_setup_script = load("res://world/world_setup.gd")
	assert_almost_eq(world_setup_script.yaw_for_progress(0.0), world_setup_script.YAW_WEST, 0.001, "0 -> YAW_WEST")
	assert_almost_eq(world_setup_script.yaw_for_progress(0.5), world_setup_script.SWEEP_YAW, 0.001, "0.5 -> SWEEP_YAW")
	assert_almost_eq(world_setup_script.yaw_for_progress(1.0), world_setup_script.YAW_EAST, 0.001, "1.0 -> YAW_EAST")
	assert_true(world_setup_script.yaw_for_progress(0.75) < world_setup_script.yaw_for_progress(0.25), "Yaw decreases monotonically")
	assert_almost_eq(world_setup_script.YAW_WEST - world_setup_script.YAW_EAST, PI, 0.001, "Yaw span is PI")
	assert_almost_eq(world_setup_script.yaw_for_progress(-0.5), world_setup_script.YAW_WEST, 0.001, "Clamping negative -> YAW_WEST")
	assert_almost_eq(world_setup_script.yaw_for_progress(1.5), world_setup_script.YAW_EAST, 0.001, "Clamping positive -> YAW_EAST")


func test_fishing_sweep_and_shop_snapback() -> void:
	var light: DirectionalLight3D = world_setup._directional_light
	round_manager.round_duration = 10.0

	round_manager.fishing_active = true
	world_setup._process(0.01)
	assert_almost_eq(light.rotation.x, 0.0, 0.001, "Pitch at start should be 0.0")
	assert_almost_eq(light.rotation.y, world_setup.YAW_WEST, 0.001, "Yaw at start should be YAW_WEST")
	assert_almost_eq(light.rotation.z, 0.0, 0.001, "Z should be 0.0")

	world_setup._fishing_anchor_msec = Time.get_ticks_msec() - 5000
	world_setup._process(0.01)
	assert_almost_eq(light.rotation.x, 1.45, 0.001, "Pitch at 50% should be 1.45")
	assert_almost_eq(light.rotation.y, world_setup.SWEEP_YAW, 0.001, "Yaw at 50% should be SWEEP_YAW (0.5)")

	world_setup._fishing_anchor_msec = Time.get_ticks_msec() - 10000
	world_setup._process(0.01)
	assert_almost_eq(light.rotation.x, 0.0, 0.001, "Pitch at 100% should be 0.0")
	assert_almost_eq(light.rotation.y, world_setup.YAW_EAST, 0.001, "Yaw at 100% should be YAW_EAST")

	round_manager.fishing_active = false
	world_setup._process(0.01)
	assert_almost_eq(light.rotation.x, -1.0, 0.001, "Snaps back to DAY_PITCH (-1.0)")
	assert_almost_eq(light.rotation.y, world_setup.SWEEP_YAW, 0.001, "Yaw snaps back to SWEEP_YAW (0.5)")
	assert_almost_eq(light.rotation.z, 0.0, 0.001, "Z stays 0.0")


func test_moon_elevation_and_antipodal() -> void:
	var world_setup_script = load("res://world/world_setup.gd")
	var pitch_mid = world_setup_script.pitch_for_progress(0.5)
	assert_almost_eq(sin(pitch_mid), sin(1.45), 0.001, "Moon elevation uses sin(pitch)")
	var moon_pos_start = MoonArc.calculate_arc_position(0.0)
	assert_true(moon_pos_start.x > MapConfig.MAP_CENTER.x, "Antipodal relationship verified")


class MockNoDurationManager extends Node:
	var fishing_active := false


func test_fishing_sweep_round_duration_fallback() -> void:
	var no_dur_manager = MockNoDurationManager.new()
	no_dur_manager.name = "RoundManager"
	_main.remove_child(round_manager)
	round_manager.free()
	round_manager = no_dur_manager
	_main.add_child(round_manager)

	var light: DirectionalLight3D = world_setup._directional_light
	no_dur_manager.fishing_active = true
	world_setup._process(0.01)
	assert_almost_eq(light.rotation.x, 0.0, 0.001, "Fallback 900s duration uses 0.0 at start")


func test_shift_anchor_methods() -> void:
	world_setup._fishing_anchor_msec = 1000
	world_setup.shift_anchor(30000)
	assert_eq(world_setup._fishing_anchor_msec, 31000, "WorldSetup anchor shifts correctly")

	var moon := world_setup.get_node_or_null("MoonArc") as MoonArc
	if is_instance_valid(moon):
		moon._local_anchor_time = 1000
		moon.shift_anchor(-30000)
		assert_eq(moon._local_anchor_time, -29000, "MoonArc anchor shifts correctly")
