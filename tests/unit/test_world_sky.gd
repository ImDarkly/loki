extends GutTest


var world_setup: Node3D
var _main: Node3D
var round_manager: Node


class MockRoundManager extends Node:
	var fishing_active := false


func before_each() -> void:
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


func after_each() -> void:
	if world_setup and is_instance_valid(world_setup):
		world_setup.queue_free()
	world_setup = null
	if _main and is_instance_valid(_main):
		_main.free()
	_main = null


func test_world_environment_sky_material_is_shader() -> void:
	var world_env := world_setup.get_node_or_null("WorldEnvironment") as WorldEnvironment
	assert_true(is_instance_valid(world_env), "WorldEnvironment should be instantiated")
	assert_true(is_instance_valid(world_env.environment), "Environment should be set")
	assert_true(is_instance_valid(world_env.environment.sky), "Sky should be set")
	assert_true(world_env.environment.sky.sky_material is ShaderMaterial, "Sky sky_material should be ShaderMaterial")


func test_light_holds_daytime_rotation_across_frames() -> void:
	var light: DirectionalLight3D = world_setup._directional_light
	assert_true(is_instance_valid(light), "DirectionalLight3D should exist")
	
	assert_almost_eq(light.rotation.x, -0.4, 0.001, "Light rotation X should be -0.4")
	assert_almost_eq(light.rotation.y, 0.5, 0.001, "Light rotation Y should be 0.5")
	assert_almost_eq(light.rotation.z, 0.0, 0.001, "Light rotation Z should be 0.0")
	assert_eq(light.light_energy, 1.0, "Light energy should be 1.0")
	assert_eq(light.light_color, Color.WHITE, "Light color should be white")

	round_manager.fishing_active = false
	world_setup._process(0.01)
	assert_almost_eq(light.rotation.x, -0.4, 0.001, "Light rotation X should hold across frames")
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


func test_star_noise_tuned_to_sparse_points_not_blotches() -> void:
	# Night stars pass through smoothstep(0.9, 0.95) in main.gdshader, so the
	# stars_01 texture must contain sparse pixels above 0.9. Cellular with the
	# default distance return never clears 0.9 (flat 0.345 readback at 1024²),
	# so stars_01 uses high-frequency simplex whose peaks clear the threshold.
	# NOTE: in this Godot build TYPE_SIMPLEX == 0, TYPE_CELLULAR == 2.
	var stars_1 := load("res://world/sky/stars_01.tres") as NoiseTexture2D
	var stars_2 := load("res://world/sky/stars_02.tres") as NoiseTexture2D
	assert_true(is_instance_valid(stars_1), "stars_01.tres should load")
	assert_true(is_instance_valid(stars_2), "stars_02.tres should load")
	var noise_1 := stars_1.noise as FastNoiseLite
	var noise_2 := stars_2.noise as FastNoiseLite
	assert_true(is_instance_valid(noise_1), "stars_01 noise should be FastNoiseLite")
	assert_true(is_instance_valid(noise_2), "stars_02 noise should be FastNoiseLite")
	assert_eq(noise_1.noise_type, FastNoiseLite.TYPE_SIMPLEX, "stars_01 should use simplex noise for sparse peaks")
	assert_eq(noise_2.noise_type, FastNoiseLite.TYPE_SIMPLEX, "stars_02 should use simplex noise for fine grain")
	assert_true(noise_1.frequency >= 0.3, "stars_01 frequency should be high-frequency (got %s)" % noise_1.frequency)
	assert_true(noise_2.frequency >= 0.3, "stars_02 frequency should be fine grain, not low-freq blotches (got %s)" % noise_2.frequency)
	assert_almost_eq(noise_1.frequency, 0.8, 0.001, "stars_01 frequency locked at 0.8")
	assert_almost_eq(noise_2.frequency, 0.4, 0.001, "stars_02 frequency locked at 0.4")
	assert_eq(noise_1.fractal_octaves, 2, "stars_01 octaves locked at 2")
	# Minified sky lookups average ~2 texels/px: with mipmaps on, mip1 peaks
	# collapse to max 0.8696 and smoothstep(0.9, 0.95) yields zero stars on
	# screen despite 1:1 texels passing. stars_01 must ship without mipmaps so
	# the GPU samples the base level and sparse peaks survive as points.
	assert_false(stars_1.generate_mipmaps, "stars_01 must disable mipmaps so minified lookups keep peaks above the star threshold")
	# stars_02 is only a low-amplitude gradient (night_noise*0.01, night tint
	# modulation) with no threshold: mip smoothing is beneficial there, so it
	# intentionally keeps mipmaps. Do not "fix" it the same way.
	assert_true(stars_2.generate_mipmaps, "stars_02 keeps mipmaps for smooth gradient sampling")


func test_wind_speed_tuned_slower_than_shader_default() -> void:
	var wind: Vector2 = world_setup._sky_material.get_shader_parameter("wind_speed")
	assert_almost_eq(wind.x, 0.025, 0.001, "wind_speed.x tuned slower than 0.5 default")
	assert_almost_eq(wind.y, 0.025, 0.001, "wind_speed.y tuned slower than 0.5 default")
	var tiling = world_setup._sky_material.get_shader_parameter("cloud_tiling")
	assert_null(tiling, "cloud_tiling should keep shader default (no override)")
