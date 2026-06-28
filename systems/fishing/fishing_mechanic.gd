extends Node3D

enum State { IDLE, WAITING, BITE, REELING, SUCCESS, ESCAPE }

signal bite_occurred(fish_position: Vector3)
signal reel_success(quota: int)
signal reel_failure()

@export var min_cast_distance: float = 5.0
@export var max_cast_distance: float = 15.0
@export var min_bite_delay: float = 3.0
@export var max_bite_delay: float = 8.0

@export var player_rise_speed: float = 80.0
@export var player_fall_speed: float = 60.0
@export var green_zone_width: float = 25.0
@export var zone_move_interval: float = 0.1
@export var zone_move_amount: float = 15.0

@export var min_reel_duration: float = 10.0
@export var max_reel_duration: float = 20.0

var current_state: State = State.IDLE
var is_line_cast: bool = false
var visual_line_node: MeshInstance3D = null
var cast_target_position: Vector3

var player_bar_position: float = 50.0
var green_zone_position: float = 50.0
var green_zone_target: float = 50.0
var green_zone_lerp_speed: float = 4.0

var quota: int = 0
var reel_duration: float = 0.0

@onready var bite_timer: Timer = $BiteTimer
@onready var bite_audio: AudioStreamPlayer = $BiteAudio
@onready var green_zone_timer: Timer = $GreenZoneTimer
@onready var reel_timer: Timer = $ReelTimer
@onready var reel_meter: Control = $CanvasLayer/ReelMeter
@onready var meter_bg: ColorRect = $CanvasLayer/ReelMeter/MeterBg
@onready var green_zone_rect: ColorRect = $CanvasLayer/ReelMeter/GreenZone
@onready var player_bar_rect: ColorRect = $CanvasLayer/ReelMeter/PlayerBar
@onready var quota_label: Label = $CanvasLayer/QuotaLabel

var original_line_vertices: PackedVector3Array = []
var twitch_directions: PackedVector3Array = []
var active_twitch_tween: Tween = null

const LINE_SEGMENTS: int = 10


func is_reeling() -> bool:
	return current_state in [State.BITE, State.REELING]


func _ready() -> void:
	bite_timer.one_shot = true
	bite_timer.timeout.connect(_on_bite_timer_timeout)
	bite_audio.stream = _generate_rumble_stream()

	green_zone_timer.wait_time = zone_move_interval
	green_zone_timer.one_shot = false
	green_zone_timer.timeout.connect(_on_green_zone_timer_timeout)

	reel_timer.one_shot = true
	reel_timer.timeout.connect(_on_reel_timer_timeout)

	quota_label.text = "Quota: 0"

	if not InputMap.has_action("reel"):
		InputMap.add_action("reel")
		var reel_mouse := InputEventMouseButton.new()
		reel_mouse.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("reel", reel_mouse)
		var reel_key := InputEventKey.new()
		reel_key.physical_keycode = KEY_SPACE
		InputMap.action_add_event("reel", reel_key)

	reel_meter.visible = false


func _process(delta: float) -> void:
	if current_state == State.BITE:
		if Input.is_action_just_pressed("reel"):
			_enter_reeling()
		return

	if current_state != State.REELING:
		return

	var holding: bool = Input.is_action_pressed("reel")

	if holding:
		player_bar_position += player_rise_speed * delta
	else:
		player_bar_position -= player_fall_speed * delta

	player_bar_position = clamp(player_bar_position, 0.0, 100.0)

	green_zone_position = lerp(green_zone_position, green_zone_target, green_zone_lerp_speed * delta)
	_update_reel_meter()


func _update_reel_meter() -> void:
	if not is_instance_valid(reel_meter):
		return
	var meter_height: float = reel_meter.size.y

	var zone_height: float = meter_height * (green_zone_width / 100.0)
	var zone_y: float = meter_height * (green_zone_position / 100.0)
	green_zone_rect.position = Vector2(0, zone_y)
	green_zone_rect.size = Vector2(reel_meter.size.x, zone_height)

	var bar_height: float = 16.0
	var bar_y: float = (meter_height - bar_height) * (player_bar_position / 100.0)
	player_bar_rect.position = Vector2(0, bar_y)
	player_bar_rect.size = Vector2(reel_meter.size.x, bar_height)


func _on_green_zone_timer_timeout() -> void:
	if current_state != State.REELING:
		return
	green_zone_target += randf_range(-zone_move_amount, zone_move_amount)
	green_zone_target = clamp(green_zone_target, 0.0, 100.0 - green_zone_width)


func _enter_reeling() -> void:
	current_state = State.REELING
	player_bar_position = 50.0
	green_zone_position = 50.0
	green_zone_target = 50.0
	green_zone_timer.start()
	reel_duration = randf_range(min_reel_duration, max_reel_duration)
	reel_timer.start(reel_duration)
	reel_meter.visible = true


func _exit_reeling() -> void:
	green_zone_timer.stop()
	reel_timer.stop()
	reel_meter.visible = false


func _is_bar_in_zone() -> bool:
	var meter_height: float = reel_meter.size.y
	if meter_height <= 0:
		return false
	var bar_y: float = (meter_height - 16.0) * (player_bar_position / 100.0)
	var bar_center: float = bar_y + 8.0
	var zone_y: float = meter_height * (green_zone_position / 100.0)
	var zone_bottom: float = zone_y + meter_height * (green_zone_width / 100.0)
	return bar_center >= zone_y and bar_center <= zone_bottom


func _on_reel_timer_timeout() -> void:
	if current_state != State.REELING:
		return
	if _is_bar_in_zone():
		current_state = State.SUCCESS
		quota += 1
		quota_label.text = "Quota: %d" % quota
		reel_success.emit(quota)
	else:
		current_state = State.ESCAPE
		reel_failure.emit()
	_exit_reeling()
	print("Reel ended. State: %s, Quota: %d" % ["SUCCESS" if current_state == State.SUCCESS else "ESCAPE", quota])


func cast(from_position: Vector3, forward_direction: Vector3) -> void:
	if current_state in [State.BITE, State.REELING, State.SUCCESS, State.ESCAPE]:
		_exit_reeling()
	$FishManager.cleanup()

	current_state = State.WAITING
	is_line_cast = true

	var random_distance: float = randf_range(min_cast_distance, max_cast_distance)
	cast_target_position = from_position + (forward_direction * random_distance)
	cast_target_position.y = 0.0

	create_visual_line(from_position, cast_target_position)

	var delay: float = randf_range(min_bite_delay, max_bite_delay)
	bite_timer.start(delay)
	print("Cast: waiting %.2f seconds for bite" % delay)


func _on_bite_timer_timeout() -> void:
	current_state = State.BITE
	_play_bite_feedback()
	$FishManager.spawn(cast_target_position)
	bite_occurred.emit(cast_target_position)
	print("Bite! Click/Space to start reeling")


func create_visual_line(start_pos: Vector3, end_pos: Vector3) -> void:
	if is_instance_valid(visual_line_node):
		visual_line_node.queue_free()

	visual_line_node = MeshInstance3D.new()
	if active_twitch_tween and active_twitch_tween.is_valid():
		active_twitch_tween.kill()
		active_twitch_tween = null
	original_line_vertices.clear()
	twitch_directions.clear()

	var line_dir: Vector3 = (end_pos - start_pos).normalized()
	var up: Vector3 = Vector3(0, 1, 0)
	var perp: Vector3 = up.cross(line_dir).normalized()
	if perp.length_squared() < 0.001:
		perp = Vector3(1, 0, 0).cross(line_dir).normalized()
	var perp2: Vector3 = line_dir.cross(perp).normalized()

	original_line_vertices.resize(LINE_SEGMENTS + 1)
	twitch_directions.resize(LINE_SEGMENTS + 1)

	for i in range(LINE_SEGMENTS + 1):
		var t: float = float(i) / float(LINE_SEGMENTS)
		original_line_vertices[i] = start_pos.lerp(end_pos, t)

		var angle: float = randf_range(0.0, TAU)
		twitch_directions[i] = (perp * cos(angle) + perp2 * sin(angle)) * randf_range(0.8, 1.2)

	twitch_directions[0] = Vector3.ZERO
	twitch_directions[LINE_SEGMENTS] = Vector3.ZERO

	get_tree().root.add_child(visual_line_node)
	_build_line_mesh(0.0)


func _build_line_mesh(twitch_strength: float) -> void:
	if not is_instance_valid(visual_line_node):
		return

	var immediate_mesh: ImmediateMesh = ImmediateMesh.new()
	var material: ORMMaterial3D = ORMMaterial3D.new()
	material.albedo_color = Color(1.0, 1.0, 1.0)
	material.shading_mode = ORMMaterial3D.SHADING_MODE_UNSHADED

	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for i in range(LINE_SEGMENTS):
		var v0: Vector3 = original_line_vertices[i] + twitch_directions[i] * twitch_strength
		var v1: Vector3 = original_line_vertices[i + 1] + twitch_directions[i + 1] * twitch_strength
		immediate_mesh.surface_add_vertex(v0)
		immediate_mesh.surface_add_vertex(v1)
	immediate_mesh.surface_end()

	visual_line_node.mesh = immediate_mesh


func _generate_rumble_stream() -> AudioStreamWAV:
	var duration: float = 0.35
	var sample_rate: int = 44100
	var sample_count: int = int(duration * sample_rate)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false

	var data := PackedByteArray()
	data.resize(sample_count * 2)

	for i in range(sample_count):
		var t: float = float(i) / float(sample_rate)

		var attack: float = min(t / 0.012, 1.0)
		var body: float = exp(-t * 8.0)
		var envelope: float = attack * body

		var tone1: float = sin(t * TAU * 220.0) * 0.35
		var tone2: float = sin(t * TAU * 330.0) * 0.25
		var tone3: float = sin(t * TAU * 440.0) * 0.15
		var tone4: float = sin(t * TAU * 550.0) * 0.08
		var low: float = tone1 + tone2 + tone3 + tone4

		var snap_env: float = clamp(1.0 - t / 0.025, 0.0, 1.0)
		var snap: float = randf_range(-1.0, 1.0) * snap_env * 0.3

		var sample: float = (low + snap) * envelope
		sample = clamp(sample, -1.0, 1.0)

		var s: int = clampi(int(sample * 16384), -32768, 32767)
		var offset: int = i * 2
		data[offset] = s & 0xFF
		data[offset + 1] = (s >> 8) & 0xFF

	wav.data = data
	return wav


func _play_bite_feedback() -> void:
	if active_twitch_tween and active_twitch_tween.is_valid():
		active_twitch_tween.kill()

	bite_audio.stop()
	bite_audio.play()

	active_twitch_tween = create_tween().set_parallel(false)
	active_twitch_tween.tween_method(_apply_twitch, 0.0, 1.0, 0.04).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	active_twitch_tween.tween_method(_apply_twitch, 1.0, 0.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _apply_twitch(factor: float) -> void:
	_build_line_mesh(factor * 0.3)
