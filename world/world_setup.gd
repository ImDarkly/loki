extends Node3D


func _ready() -> void:
	setup_environment()
	setup_lighting()
	setup_ground()
	setup_ground_collision()
	setup_water()


func setup_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.25, 0.5, 0.8)
	sky_mat.sky_horizon_color = Color(0.65, 0.7, 0.75)
	sky_mat.sky_curve = 0.15
	sky_mat.ground_horizon_color = Color(0.55, 0.5, 0.4)
	sky_mat.ground_bottom_color = Color(0.3, 0.25, 0.2)
	sky_mat.ground_curve = 0.02

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func setup_lighting() -> void:
	var light := DirectionalLight3D.new()
	light.light_energy = 1.0
	light.shadow_enabled = true
	light.shadow_normal_bias = 0.1
	light.directional_shadow_max_distance = 60.0
	light.position = Vector3(0, 10, 0)
	light.rotation = Vector3(-0.4, 0.5, 0)
	add_child(light)


func setup_ground() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(80, 80)

	var mat := ORMMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.62, 0.4)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var ground := MeshInstance3D.new()
	ground.mesh = mesh
	ground.material_override = mat
	ground.position = Vector3(0, -0.1, -7)
	add_child(ground)


func setup_ground_collision() -> void:
	var body := StaticBody3D.new()
	body.position = Vector3(0, -0.35, -7)

	var shape := BoxShape3D.new()
	shape.size = Vector3(80, 0.5, 80)

	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func setup_water() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(50, 50)

	var mat := ORMMaterial3D.new()
	mat.albedo_color = Color(0.0, 0.35, 0.6, 0.6)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var water := MeshInstance3D.new()
	water.mesh = mesh
	water.material_override = mat
	water.position = Vector3(0, 0, -7)
	add_child(water)
