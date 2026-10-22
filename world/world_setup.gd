extends Node3D



const DAY_PITCH: float = -1.0
const NIGHT_PITCH: float = 1.45
const SUNSET_PITCH: float = 0.0
const SWEEP_YAW: float = 0.5
const YAW_EAST: float = SWEEP_YAW - PI / 2
const YAW_WEST: float = SWEEP_YAW + PI / 2

@export var dressing_seed: int = 334
@export var shore_cluster_count: int = 17
@export var bay_cluster_count: int = 4
@export var shore_rock_width: float = 2.4
@export var cluster_spread: float = 2.0
@export var shore_rock_offset: float = 1.0
@export var dock_clearance_depth: float = 2.0
@export var arch_offset := Vector3(0, 0, 2)
@export var arch_support_size := Vector3(3, 6, 3)
@export var arch_crown_size := Vector3(13, 1, 3.2)
@export var arch_clearance_radius: float = 6.0
@export var fog_density: float = 0.035
@export var horizon_day := Color(0.75, 0.85, 0.85)
@export var horizon_sunset := Color(0.9, 0.4, 0.1)
@export var horizon_night := Color(0.1, 0.15, 0.2)

var _sky_material: ShaderMaterial
var _fog_environment: Environment
var _directional_light: DirectionalLight3D
var _ground_mat: ORMMaterial3D
var _water_mat: ORMMaterial3D
var _ground_mesh: ArrayMesh
var _round_manager: Node = null
var _fps_label: Label = null
var _last_fishing_active: bool = false
var _fishing_anchor_msec: int = 0


func _ready() -> void:
	setup_environment()
	setup_lighting()
	setup_ground()
	setup_ground_collision()
	setup_water()
	_setup_layout()
	_setup_island_dressing()
	_setup_danger_system()
	_add_fps_counter()


func setup_environment() -> void:
	var shader := load("res://world/sky/main.gdshader") as Shader
	_sky_material = ShaderMaterial.new()
	_sky_material.shader = shader
	_sky_material.set_shader_parameter("horizon_day", horizon_day)
	_sky_material.set_shader_parameter("horizon_sunset", horizon_sunset)
	_sky_material.set_shader_parameter("horizon_night", horizon_night)
	_sky_material.set_shader_parameter("cloud_tex_01", load("res://world/sky/clouds_01.tres"))
	_sky_material.set_shader_parameter("cloud_tex_02", load("res://world/sky/clouds_02.tres"))
	_sky_material.set_shader_parameter("night_noise_01", load("res://world/sky/stars_01.tres"))
	_sky_material.set_shader_parameter("night_noise_02", load("res://world/sky/stars_02.tres"))
	_sky_material.set_shader_parameter("wind_speed", Vector2(0.025, 0.025))

	var sky := Sky.new()
	sky.sky_material = _sky_material

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_density = fog_density
	env.fog_sky_affect = 0.05
	_fog_environment = env
	_sync_fog_horizon()

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)


func setup_lighting() -> void:
	_directional_light = DirectionalLight3D.new()
	_directional_light.light_energy = 1.0
	_directional_light.light_color = Color.WHITE
	_directional_light.shadow_enabled = true
	_directional_light.shadow_normal_bias = 2.0
	_directional_light.directional_shadow_max_distance = 60.0
	_directional_light.position = Vector3(0, 10, 0)
	_directional_light.rotation = Vector3(DAY_PITCH, SWEEP_YAW, 0)
	add_child(_directional_light)
	_sync_fog_horizon()


func _sync_fog_horizon() -> void:
	var blend := -sin(DAY_PITCH)
	if _directional_light:
		var light_basis := _directional_light.global_basis if _directional_light.is_inside_tree() else _directional_light.basis
		blend = light_basis.z.y
	var daylight := horizon_sunset.lerp(horizon_day, clampf(blend, 0.0, 1.0))
	_fog_environment.fog_light_color = horizon_night.lerp(daylight, pow(clampf(1.0 + blend, 0.0, 1.0), 4.0))


func setup_ground() -> void:
	_ground_mesh = MapConfig.layout.ground_mesh()

	_ground_mat = ORMMaterial3D.new()
	_ground_mat.albedo_color = Color(0.90, 0.56, 0.31)
	_ground_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var ground := MeshInstance3D.new()
	ground.name = "IslandGround"
	ground.mesh = _ground_mesh
	ground.material_override = _ground_mat
	add_child(ground)


func setup_ground_collision() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	body.name = "IslandCollision"

	var collision := CollisionShape3D.new()
	collision.shape = _ground_mesh.create_trimesh_shape()
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
	water.position = Vector3(0, MapConfig.layout.water_height, MapConfig.MAP_CENTER.z)
	add_child(water)


func _layout_box(node_name: String, center: Vector3, size: Vector3, color: Color, solid: bool = true) -> Node3D:
	var root: Node3D = StaticBody3D.new() if solid else Node3D.new()
	root.name = node_name
	root.position = center
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	visual.material_override = material
	root.add_child(visual)
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		root.add_child(collision)
	add_child(root)
	return root


func _layout_disc(node_name: String, center: Vector3, radius: float, height: float, color: Color) -> void:
	var marker := MeshInstance3D.new()
	marker.name = node_name
	marker.position = center
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 64
	marker.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = material
	add_child(marker)


func _setup_layout() -> void:
	var layout := MapConfig.layout
	for deck_name: String in layout.decks:
		var rect: Rect2 = layout.decks[deck_name]
		_layout_box(deck_name, layout.point3(rect.get_center(), layout.deck_height - 0.15), Vector3(rect.size.x, 0.3, rect.size.y), Color(0.4, 0.3, 0.2))
	var pier: Rect2 = layout.decks["CreaturePier"]
	var rail_y := layout.deck_height + layout.rail_height * 0.5
	for side in [-1.0, 1.0]:
		var rail_x: float = pier.get_center().x + side * (pier.size.x + layout.rail_thickness) * 0.5
		_layout_box("CreatureRail", Vector3(rail_x, rail_y, pier.get_center().y), Vector3(layout.rail_thickness, layout.rail_height, pier.size.y), Color(0.3, 0.25, 0.2))
	_layout_box("CreatureEndRail", Vector3(pier.get_center().x, rail_y, pier.end.y + layout.rail_thickness * 0.5), Vector3(pier.size.x + layout.rail_thickness * 2, layout.rail_height, layout.rail_thickness), Color(0.3, 0.25, 0.2))
	for lantern in layout.lantern_boxes():
		_layout_box(lantern["name"], lantern["position"], lantern["size"], Color(0.3, 0.6, 0.35), false)
	for i in range(layout.pads.size()):
		var marker := Marker3D.new()
		marker.name = "BuildingPad%d" % (i + 1)
		marker.position = layout.point3(layout.pads[i], layout.deck_height)
		marker.set_meta("size", layout.pad_size)
		add_child(marker)
		_layout_box("PadFootprint", marker.position, Vector3(layout.pad_size.x, 0.02, layout.pad_size.y), Color(0.5, 0.45, 0.4), false)
	for ladder in layout.ladders:
		for side in [-1.0, 1.0]:
			_layout_box("LadderSide", layout.point3(ladder + Vector2(side * layout.ladder_size.x * 0.5, 0), -layout.ladder_size.y * 0.5), Vector3(0.08, layout.ladder_size.y, 0.1), Color(0.55, 0.4, 0.2), false)
		for i in range(5):
			_layout_box("LadderRung", layout.point3(ladder, -float(i) * layout.ladder_size.y / 5.0), Vector3(layout.ladder_size.x, 0.06, 0.1), Color(0.55, 0.4, 0.2), false)
	for detail in layout.ship_boxes():
		_layout_box(detail["name"], detail["position"], detail["size"], Color(0.3, 0.2, 0.15), false)
	for marker in layout.marker_discs():
		var color := Color(0.58, 0.50, 0.38) if marker["name"] == "PlazaMarker" else Color(0.42, 0.15, 0.2)
		_layout_disc(marker["name"], marker["position"], marker["radius"], marker["height"], color)
	var shop := get_node_or_null("Shops/ShopHut") as Node3D
	if shop:
		shop.position = layout.point3(layout.pads[0], layout.deck_height + 1.0)
	var fire := get_node_or_null("Shops/Fireplace") as Node3D
	if fire:
		fire.position = layout.point3(layout.fireplace, layout.deck_height)
	var storage := get_node_or_null("StorageBox") as Node3D
	if storage:
		storage.position = layout.storage_position()


func _setup_island_dressing() -> void:
	var meshes: Array[Mesh] = []
	for variant in range(1, 6):
		var path := "res://world/assets/quaternius_pirate/Environment_Rock_%d.gltf" % variant
		if not ResourceLoader.exists(path):
			push_warning("Island rocks missing or unimported: install Quaternius Pirate Kit Environment_Rock_1 through _5.gltf per ASSETS.md, then import in Godot.")
			return
		var model := (load(path) as PackedScene).instantiate()
		var visual := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		meshes.append(visual.mesh)
		model.free()
	var dressing := Node3D.new()
	dressing.name = "IslandDressing"
	add_child(dressing)
	var materials: Array[StandardMaterial3D] = []
	for tint in [Color(0.24, 0.235, 0.215), Color(0.255, 0.26, 0.27), Color(0.215, 0.225, 0.23), Color(0.27, 0.25, 0.22)]:
		var material := StandardMaterial3D.new()
		material.albedo_color = tint
		material.roughness = 1.0
		materials.append(material)
	var layout := MapConfig.layout
	var random := RandomNumberGenerator.new()
	random.seed = dressing_seed
	for coast in ["ShoreRock", "BayRock"]:
		var count := shore_cluster_count if coast == "ShoreRock" else bay_cluster_count
		var center := layout.island_center if coast == "ShoreRock" else layout.bay_center
		var radii := layout.island_half_extents if coast == "ShoreRock" else Vector2.ONE * layout.bay_radius
		for i in range(count):
			var angle := TAU * (float(i) + random.randf_range(0.15, 0.85)) / float(count)
			var anchor := center + Vector2(cos(angle), sin(angle)) * (radii + Vector2.ONE * shore_rock_offset)
			for stone in range(random.randi_range(2, 5)):
				var point := anchor + Vector2(random.randf_range(-cluster_spread, cluster_spread), random.randf_range(-cluster_spread, cluster_spread))
				var width := shore_rock_width * random.randf_range(0.9, 1.5) if stone == 0 else shore_rock_width * random.randf_range(0.3, 0.8)
				_add_shore_rock(dressing, meshes[dressing.get_child_count() % meshes.size()], point, width, random.randf_range(0, TAU), materials[dressing.get_child_count() % materials.size()], coast)
	var arch_center := layout.point3(Vector2(layout.channel.get_center().x, layout.channel.position.y), layout.water_height) + arch_offset
	var support_x: float = (layout.channel.size.x + arch_support_size.x) * 0.5 + 0.5
	for side in [-1.0, 1.0]:
		_add_dressing_rock(dressing, meshes[1], arch_center + Vector3(side * support_x, arch_support_size.y * 0.5, 0), arch_support_size, materials[1], "ArchSupport")
	_add_dressing_rock(dressing, meshes[2], arch_center + Vector3(0, arch_support_size.y, 0), arch_crown_size, materials[2], "ArchCrown")


func _add_shore_rock(parent: Node3D, mesh: Mesh, point: Vector2, width: float, yaw: float, material: Material, node_name: String) -> void:
	var rock := MeshInstance3D.new()
	rock.mesh = mesh
	var source_bounds := mesh.get_aabb()
	var scalar := width / maxf(source_bounds.size.x, source_bounds.size.z)
	rock.basis = Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scalar)
	var bounds: AABB = rock.transform * source_bounds
	rock.position = Vector3(point.x - bounds.get_center().x, MapConfig.layout.water_height - bounds.position.y, point.y - bounds.get_center().z)
	bounds = rock.transform * source_bounds
	var footprint := Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z))
	var dock: Rect2 = MapConfig.layout.decks["Dock"]
	var channel: Rect2 = MapConfig.layout.channel
	var arch_point := Vector2(channel.get_center().x + arch_offset.x, channel.position.y + arch_offset.z)
	var arch_distance := arch_point.distance_to(arch_point.clamp(footprint.position, footprint.end))
	if arch_distance < arch_clearance_radius or footprint.position.y < dock.end.y + dock_clearance_depth or footprint.intersects(channel.grow(0.5)) or not _dressing_footprint_clear(footprint):
		rock.free()
		return
	rock.name = node_name
	rock.material_override = material
	parent.add_child(rock, true)


func _dressing_footprint_clear(footprint: Rect2) -> bool:
	var layout := MapConfig.layout
	for deck: Rect2 in layout.decks.values():
		if footprint.intersects(deck.grow(0.75)):
			return false
	for pad in layout.pads:
		if footprint.intersects(Rect2(pad - layout.pad_size * 0.5, layout.pad_size).grow(0.5)):
			return false
	if footprint.intersects(Rect2(layout.fireplace - layout.fireplace_size * 0.5, layout.fireplace_size).grow(0.5)):
		return false
	for path in layout.path_segments():
		var route := Rect2(path[0], Vector2.ZERO).expand(path[1]).grow(layout.path_width * 0.5)
		if footprint.intersects(route):
			return false
	return true


func _add_dressing_rock(parent: Node3D, mesh: Mesh, center: Vector3, size: Vector3, material: Material, node_name: String) -> void:
	var rock := MeshInstance3D.new()
	rock.name = node_name
	rock.mesh = mesh
	rock.material_override = material
	var bounds := mesh.get_aabb()
	rock.scale = size / bounds.size
	rock.position = center - bounds.get_center() * rock.scale
	parent.add_child(rock, true)


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


static func pitch_for_progress(progress: float) -> float:
	var p: float = clampf(progress, 0.0, 1.0)
	if p <= 0.5:
		return lerpf(SUNSET_PITCH, NIGHT_PITCH, p / 0.5)
	else:
		return lerpf(NIGHT_PITCH, SUNSET_PITCH, (p - 0.5) / 0.5)


static func yaw_for_progress(progress: float) -> float:
	return lerpf(YAW_WEST, YAW_EAST, clampf(progress, 0.0, 1.0))


func _process(_delta: float) -> void:
	if _fps_label:
		_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

	if _round_manager == null:
		_round_manager = get_node_or_null("/root/main/RoundManager")
	if _round_manager:
		var current_fishing: bool = _round_manager.fishing_active
		if current_fishing and not _last_fishing_active:
			_fishing_anchor_msec = Time.get_ticks_msec()
			_apply_night()
		elif not current_fishing and _last_fishing_active:
			_fishing_anchor_msec = 0
			_apply_day()
			if _directional_light:
				_directional_light.rotation = Vector3(DAY_PITCH, SWEEP_YAW, 0)

		_last_fishing_active = current_fishing

		if current_fishing:
			var duration_sec: float = float(_round_manager.get("round_duration")) if _round_manager.has_method("get") and "round_duration" in _round_manager else 900.0
			var duration_msec: float = duration_sec * 1000.0
			var progress: float = float(Time.get_ticks_msec() - _fishing_anchor_msec) / duration_msec if duration_msec > 0.0 else 0.0
			if _directional_light:
				_directional_light.rotation = Vector3(pitch_for_progress(progress), yaw_for_progress(progress), 0)
	_sync_fog_horizon()


func _apply_night() -> void:
	_ground_mat.albedo_color = Color(0.24, 0.21, 0.27)
	_water_mat.albedo_color = Color(0.04, 0.37, 0.40)


func _apply_day() -> void:
	_ground_mat.albedo_color = Color(0.90, 0.56, 0.31)
	_water_mat.albedo_color = Color(0.04, 0.54, 0.56)


func shift_anchor(delta_msec: int) -> void:
	_fishing_anchor_msec += delta_msec
