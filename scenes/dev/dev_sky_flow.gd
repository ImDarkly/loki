extends Node3D

var _world_setup: Node3D
var _label: Label
var _is_shader_preview: bool = false
var _fast_wind: bool = false

func _ready() -> void:
	_world_setup = get_node_or_null("WorldSetup")
	_label = get_node_or_null("HUD/Label") as Label

	if _world_setup and _world_setup.has_method("_apply_day"):
		_world_setup._apply_day()

	if _label:
		_label.text = "Dev Sky Flow"

func _process(_delta: float) -> void:
	if not OS.is_debug_build():
		return
	if _world_setup == null or _label == null:
		return

	var light: DirectionalLight3D = _world_setup.get("_directional_light") as DirectionalLight3D
	var sky_mat: ShaderMaterial = _world_setup.get("_sky_material") as ShaderMaterial

	var rot_str = "(none)"
	var light_y = 0.0
	if light:
		rot_str = "%.2f, %.2f, %.2f" % [light.rotation.x, light.rotation.y, light.rotation.z]
		var light_dir := -light.global_transform.basis.z
		light_y = light_dir.y

	var wind_val = Vector2.ZERO
	if sky_mat:
		wind_val = sky_mat.get_shader_parameter("wind_speed")

	var day_night_mix = 0.8
	if sky_mat and sky_mat.has_shader_parameter("day_night_mix"):
		day_night_mix = sky_mat.get_shader_parameter("day_night_mix")

	var mode_label = "GAME-TRUTH" if not _is_shader_preview else "SHADER-PREVIEW"
	var renderer = "gl_compatibility"
	if RenderingServer.has_method("get_current_rendering_method"):
		renderer = RenderingServer.get_current_rendering_method()
	else:
		renderer = ProjectSettings.get_setting("renderer/rendering_method", "gl_compatibility")

	var time_scale = Engine.time_scale

	_label.text = "Mode: %s | Renderer: %s | Light Rot: (%s) | LightY: %.2f | Wind: %s | DayNightMix: %.2f | TimeScale: %.1fx\n[F5] Game-Truth Day  [F6] Sunset Preview  [F7] Night Preview  [G] Wind Drift  [H] Speed 1x/2x  [R] Reset" % [
		mode_label, renderer, rot_str, light_y, str(wind_val), day_night_mix, time_scale
	]

func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F5:
				_apply_game_truth_day()
			KEY_F6:
				_apply_sunset_preview()
			KEY_F7:
				_apply_night_preview()
			KEY_G:
				_toggle_wind()
			KEY_H:
				Engine.time_scale = 1.0 if Engine.time_scale > 1.5 else 2.0
			KEY_R:
				_reset_to_production()

func _apply_game_truth_day() -> void:
	_is_shader_preview = false
	if _world_setup:
		if _world_setup.has_method("_apply_day"):
			_world_setup._apply_day()
		var light: DirectionalLight3D = _world_setup.get("_directional_light") as DirectionalLight3D
		if light:
			light.rotation = Vector3(-0.4, 0.5, 0)
		var sky_mat: ShaderMaterial = _world_setup.get("_sky_material") as ShaderMaterial
		if sky_mat and not _fast_wind:
			sky_mat.set_shader_parameter("wind_speed", Vector2(0.025, 0.025))

func _apply_sunset_preview() -> void:
	_is_shader_preview = true
	if _world_setup:
		var light: DirectionalLight3D = _world_setup.get("_directional_light") as DirectionalLight3D
		if light:
			light.rotation = Vector3(0.0, 0.5, 0)

func _apply_night_preview() -> void:
	_is_shader_preview = true
	if _world_setup:
		if _world_setup.has_method("_apply_night"):
			_world_setup._apply_night()
		var light: DirectionalLight3D = _world_setup.get("_directional_light") as DirectionalLight3D
		if light:
			light.rotation = Vector3(0.8, 0.5, 0)

func _toggle_wind() -> void:
	_fast_wind = not _fast_wind
	if _world_setup:
		var sky_mat: ShaderMaterial = _world_setup.get("_sky_material") as ShaderMaterial
		if sky_mat:
			if _fast_wind:
				sky_mat.set_shader_parameter("wind_speed", Vector2(0.2, 0.2))
			else:
				sky_mat.set_shader_parameter("wind_speed", Vector2(0.025, 0.025))

func _reset_to_production() -> void:
	_is_shader_preview = false
	_fast_wind = false
	if _world_setup:
		if _world_setup.has_method("_apply_day"):
			_world_setup._apply_day()
		var light: DirectionalLight3D = _world_setup.get("_directional_light") as DirectionalLight3D
		if light:
			light.rotation = Vector3(-0.4, 0.5, 0)
		var sky_mat: ShaderMaterial = _world_setup.get("_sky_material") as ShaderMaterial
		if sky_mat:
			sky_mat.set_shader_parameter("wind_speed", Vector2(0.025, 0.025))
	Engine.time_scale = 1.0
