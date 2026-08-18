extends Node3D


var _sky_material: ProceduralSkyMaterial
var _directional_light: DirectionalLight3D
var _ground_mat: ORMMaterial3D
var _water_mat: ORMMaterial3D
var _round_manager: Node = null
var _fps_label: Label = null
var _last_fishing_active: bool = false


func _ready() -> void:
	setup_environment()
	setup_lighting()
	setup_ground()
	setup_ground_collision()
	setup_water()
	_setup_danger_system()
	_add_fps_counter()


func setup_environment() -> void:
	_sky_material = ProceduralSkyMaterial.new()
	_sky_material.sky_top_color = Color(0.30, 0.61, 0.90)
	_sky_material.sky_horizon_color = Color(0.56, 0.83, 1.0)
	_sky_material.sky_curve = 0.15
	_sky_material.ground_horizon_color = Color(0.04, 0.54, 0.56)
	_sky_material.ground_bottom_color = Color(0.02, 0.25, 0.30)
	_sky_material.ground_curve = 0.4

	var sky := Sky.new()
	sky.sky_material = _sky_material

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.56, 0.83, 1.0)
	env.fog_density = 0.02
	env.fog_sky_affect = 0.05

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func setup_lighting() -> void:
	_directional_light = DirectionalLight3D.new()
	_directional_light.light_energy = 1.0
	_directional_light.light_color = Color.WHITE
	_directional_light.shadow_enabled = true
	_directional_light.shadow_normal_bias = 0.1
	_directional_light.directional_shadow_max_distance = 60.0
	_directional_light.position = Vector3(0, 10, 0)
	_directional_light.rotation = Vector3(-0.4, 0.5, 0)
	add_child(_directional_light)


func setup_ground() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = MapConfig.ISLAND_RADIUS
	mesh.bottom_radius = MapConfig.ISLAND_RADIUS
	mesh.height = 1.0
	mesh.radial_segments = 48

	_ground_mat = ORMMaterial3D.new()
	_ground_mat.albedo_color = Color(0.90, 0.56, 0.31)
	_ground_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var ground := MeshInstance3D.new()
	ground.mesh = mesh
	ground.material_override = _ground_mat
	ground.position = Vector3(0, -0.5, MapConfig.MAP_CENTER.z)
	add_child(ground)


func setup_ground_collision() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	body.position = Vector3(0, -0.5, MapConfig.MAP_CENTER.z)

	var shape := CylinderShape3D.new()
	shape.radius = MapConfig.ISLAND_RADIUS
	shape.height = 1.0

	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func setup_water() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(MapConfig.OCEAN_RADIUS * 2.0, MapConfig.OCEAN_RADIUS * 2.0)

	_water_mat = ORMMaterial3D.new()
	_water_mat.albedo_color = Color(0.04, 0.54, 0.56)
	_water_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var water := MeshInstance3D.new()
	water.mesh = mesh
	water.material_override = _water_mat
	water.position = Vector3(0, -0.5, MapConfig.MAP_CENTER.z)
	add_child(water)


func _setup_danger_system() -> void:
	pass


func _add_fps_counter() -> void:
	var layer := CanvasLayer.new()
	layer.name = "FPSLayer"
	var label := Label.new()
	label.name = "FPSLabel"
	label.add_theme_font_size_override("font_size", 14)
	label.position = Vector2(10, 50)
	layer.add_child(label)
	add_child(layer)
	_fps_label = label


func _process(_delta: float) -> void:
	if _fps_label:
		_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

	if _round_manager == null:
		_round_manager = get_node_or_null("/root/main/RoundManager")
	if _round_manager and _round_manager.fishing_active != _last_fishing_active:
		_last_fishing_active = _round_manager.fishing_active
		if _round_manager.fishing_active:
			_apply_night()
		else:
			_apply_day()


func _apply_night() -> void:
	_sky_material.sky_top_color = Color(0.18, 0.13, 0.18)
	_sky_material.sky_horizon_color = Color(0.27, 0.16, 0.25)
	_sky_material.ground_horizon_color = Color(0.22, 0.31, 0.29)
	_sky_material.ground_bottom_color = Color(0.18, 0.13, 0.18)
	_directional_light.light_energy = 0.15
	_directional_light.light_color = Color(0.20, 0.20, 0.33)
	_ground_mat.albedo_color = Color(0.24, 0.21, 0.27)
	_water_mat.albedo_color = Color(0.04, 0.37, 0.40)


func _apply_day() -> void:
	_sky_material.sky_top_color = Color(0.30, 0.61, 0.90)
	_sky_material.sky_horizon_color = Color(0.56, 0.83, 1.0)
	_sky_material.ground_horizon_color = Color(0.04, 0.54, 0.56)
	_sky_material.ground_bottom_color = Color(0.02, 0.25, 0.30)
	_sky_material.ground_curve = 0.4
	_directional_light.light_energy = 1.0
	_directional_light.light_color = Color.WHITE
	_ground_mat.albedo_color = Color(0.90, 0.56, 0.31)
	_water_mat.albedo_color = Color(0.04, 0.54, 0.56)
