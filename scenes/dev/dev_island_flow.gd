extends "res://world/world_setup.gd"

@onready var _player: Player = $Players/Player_1
@onready var _danger = $DangerManager
@onready var _round = $RoundManager
@onready var _hud: Label = $HUD/Panel/Label
@onready var _hud_panel: Control = $HUD/Panel

var _overview: Camera3D
var _measurements: Node3D
var _zone_name := "Ship pier"


func _ready() -> void:
	super._ready()
	_round.timer.stop()
	_round.round_active = false
	_round.fishing_active = false
	_danger.spawn_timer.stop()
	_danger.return_timer.stop()
	$CoinManager.debug_action("toggle_fireplace")
	_overview = Camera3D.new()
	_overview.name = "OverviewCamera"
	_overview.projection = Camera3D.PROJECTION_ORTHOGONAL
	_overview.size = 58.0
	_overview.position = MapConfig.layout.point3(MapConfig.layout.island_center, 30.0)
	add_child(_overview)
	_overview.look_at(MapConfig.layout.point3(MapConfig.layout.island_center), Vector3.FORWARD)
	_build_measurements()
	_jump_to(MapConfig.layout.spawn_positions()[0], "Ship pier")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	super._process(delta)
	var layout := MapConfig.layout
	if _overview.current:
		_hud.text = "Fishing rings: %d | +X east right | +Z north down | O walk | 1–8 zone jumps | F fog | M measurements" % $ZoneManager.zone_nodes.size()
		_hud_panel.reset_size()
		_hud_panel.position = Vector2(12, get_viewport().get_visible_rect().size.y - _hud_panel.get_combined_minimum_size().y - 12)
		return
	_hud_panel.position = Vector2(12, 90)
	var pier: Rect2 = layout.decks["CreaturePier"]
	var connector: Rect2 = layout.decks["ShoreConnector"]
	var gangway: Rect2 = layout.decks["Gangway"]
	var danger_start := layout.creature_water_center.y - layout.creature_water_radius
	_hud.text = (
		"ISLAND GREYBOX | %s | Player %s | %s\n"
		+ "WASD + mouse: walk/look  Space: jump  Click: capture mouse  Esc: release / close\n"
		+ "1 dock  2 ship pier  3 ship/storage  4 shop  5 pad 2  6 pad 3  7 fireplace  8 creature pier\n"
		+ "O overhead / player  M measurements  F existing fog  K nearby shark  R restore pier  T fishing / shop phase\n"
		+ "Channel %.1f m | Paths %.1f m | Shore connector %.1f x %.1f m | Gangway %.1f x %.1f m\n"
		+ "Creature pier %.1f m clear; final %.1f m above future danger footprint (r %.1f m).\n"
		+ "Ladders are placeholders. Creature-water death and highlights are deferred. R exits a water test."
	) % [
		_zone_name, str(_player.global_position.snapped(Vector3.ONE * 0.1)),
		Player.PlayerState.keys()[_player.player_state], layout.channel.size.x, layout.path_width,
		connector.size.x, connector.size.y, gangway.size.x, gangway.size.y,
		pier.size.x, maxf(0.0, pier.end.y - danger_start), layout.creature_water_radius,
	]
	_hud_panel.reset_size()


func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not _overview.current:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var layout := MapConfig.layout
	match event.keycode:
		KEY_1:
			_jump_to(layout.point3(layout.decks["Dock"].get_center()), "Dock")
		KEY_2, KEY_R:
			_jump_to(layout.spawn_positions()[0], "Ship pier")
		KEY_3:
			_jump_to(layout.point3(layout.decks["Ship"].get_center() + Vector2(0, 1)), "Ship / storage")
		KEY_4:
			_jump_to(layout.point3(layout.pads[0] + Vector2(0, -layout.pad_size.y * 0.5 - 1)), "Shop entrance")
		KEY_5:
			_jump_to(layout.point3(layout.pads[1]), "Empty pad 2")
		KEY_6:
			_jump_to(layout.point3(layout.pads[2]), "Empty pad 3")
		KEY_7:
			_jump_to(layout.point3(layout.fireplace + Vector2(0, -layout.fireplace_size.y * 0.5 - 0.5)), "Fireplace")
		KEY_8:
			_jump_to(layout.point3(Vector2(layout.decks["CreaturePier"].get_center().x, layout.decks["CreaturePier"].position.y + 0.5)), "Creature pier")
		KEY_O:
			_set_overview(not _overview.current)
		KEY_M:
			_measurements.visible = not _measurements.visible
		KEY_F:
			var environment := ($WorldEnvironment as WorldEnvironment).environment
			environment.fog_enabled = not environment.fog_enabled
		KEY_K:
			_spawn_nearby_shark()
		KEY_T:
			_round.fishing_active = not _round.fishing_active
		KEY_ESCAPE:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				get_tree().quit()
		_:
			return
	get_viewport().set_input_as_handled()


func _jump_to(destination: Vector3, zone_name: String) -> void:
	_player._on_restart()
	_player.global_position = destination + Vector3.UP * 0.1
	_player.velocity = Vector3.ZERO
	_zone_name = zone_name
	_set_overview(false)
	_player.rotation.y = PI
	_player.head.rotation.x = 0.0
	_danger.debug_action("reset_inactive")
	_danger.spawn_timer.stop()
	_danger.return_timer.stop()


func _set_overview(enabled: bool) -> void:
	_player.set_physics_process(not enabled)
	_player.set_process_unhandled_input(not enabled)
	if enabled:
		_overview.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		_player.camera.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _spawn_nearby_shark() -> void:
	var layout := MapConfig.layout
	var target := _player.global_position + Vector3(0, 0, -6)
	if layout.is_land(target):
		target = layout.nearest_water(target)
	_danger._debug_spawn_override = Vector3(target.x, 0, target.z)
	_danger.debug_action("force_spawn")
	_danger._debug_spawn_override = Vector3.INF


func _label(text: String, point: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = point
	label.font_size = 32
	label.pixel_size = 0.008
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	_measurements.add_child(label)


func _line(points: PackedVector3Array, color: Color) -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for point in points:
		mesh.surface_add_vertex(point)
	mesh.surface_end()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.no_depth_test = true
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	_measurements.add_child(visual)


func _build_measurements() -> void:
	var layout := MapConfig.layout
	_measurements = Node3D.new()
	_measurements.name = "Measurements"
	add_child(_measurements)
	var cyan := Color(0.5, 1, 1)
	for path in layout.path_segments():
		var offset := (path[1] - path[0]).normalized().orthogonal() * layout.path_width * 0.5
		for side in [-1.0, 1.0]:
			_line(PackedVector3Array([layout.point3(path[0] + offset * side, 0.04), layout.point3(path[1] + offset * side, 0.04)]), cyan)
	_label("Paths %.1f m clear" % layout.path_width, layout.point3(layout.plaza, 2), cyan)
	var channel := layout.channel
	var channel_outline := PackedVector3Array()
	for point in layout.rect_polygon(channel):
		channel_outline.append(layout.point3(point, 0.1))
	channel_outline.append(channel_outline[0])
	_line(channel_outline, cyan)
	_label("Water opening %.1f m\nz %.1f to %.1f" % [channel.size.x, channel.position.y, channel.end.y], layout.point3(Vector2(channel.get_center().x, channel.end.y), 1), cyan)
	for key: String in ["ShoreConnector", "Gangway", "CreaturePier"]:
		var rect: Rect2 = layout.decks[key]
		var corners := layout.rect_polygon(rect)
		var points := PackedVector3Array()
		for point in corners:
			points.append(layout.point3(point, 0.06))
		points.append(points[0])
		_line(points, cyan)
		_label("%s %.1f x %.1f m" % [key, rect.size.x, rect.size.y], layout.point3(rect.get_center(), 1.8), cyan)
	var danger := PackedVector3Array()
	for i in range(65):
		var angle := TAU * float(i) / 64.0
		var point := layout.creature_water_center + Vector2(cos(angle), sin(angle)) * layout.creature_water_radius
		danger.append(layout.point3(point, 0.08))
	_line(danger, Color(1, 0.25, 0.25))
	_label("Creature water r %.1f m\nFuture danger; no instant death in greybox" % layout.creature_water_radius, layout.point3(layout.creature_water_center, 1.5), Color(1, 0.4, 0.4))
	var pier: Rect2 = layout.decks["CreaturePier"]
	var danger_start := layout.creature_water_center.y - layout.creature_water_radius
	_line(PackedVector3Array([Vector3(pier.position.x, 0.08, danger_start), Vector3(pier.end.x, 0.08, danger_start)]), Color(1, 0.25, 0.25))
	_label("Final %.1f m over footprint" % maxf(0, pier.end.y - danger_start), Vector3(pier.end.x + 2, 1.5, danger_start + 0.5), Color(1, 0.4, 0.4))
