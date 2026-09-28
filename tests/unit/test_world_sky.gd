extends GutTest


var world_setup: Node3D
var _main: Node3D
var round_manager: Node


func before_each() -> void:
	_main = Node3D.new()
	_main.name = "main"
	get_node("/root").add_child(_main)

	round_manager = Node3D.new()
	round_manager.name = "RoundManager"
	round_manager.set("fishing_active", false)
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
