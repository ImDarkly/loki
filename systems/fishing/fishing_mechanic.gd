extends Node3D

enum State { IDLE, CASTING, WAITING, BITE, REELING, SUCCESS }

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

@onready var bite_timer: Timer = $BiteTimer
@onready var bite_audio: AudioStreamPlayer = $BiteAudio
@onready var casting_timer: Timer = $CastingTimer
@onready var green_zone_timer: Timer = $GreenZoneTimer
@onready var reel_timer: Timer = $ReelTimer
@onready var reel_meter: Control = $CanvasLayer/ReelMeter
@onready var meter_bg: ColorRect = $CanvasLayer/ReelMeter/MeterBg
@onready var green_zone_rect: ColorRect = $CanvasLayer/ReelMeter/GreenZone
@onready var player_bar_rect: ColorRect = $CanvasLayer/ReelMeter/PlayerBar
@onready var quota_label: Label = $CanvasLayer/QuotaLabel
@onready var catch_feedback_manager: Node3D = $CatchFeedbackManager

var current_state: State = State.IDLE
var visual_line_node: MeshInstance3D = null
var line_material: ORMMaterial3D = null
var bobber_node: MeshInstance3D = null
var cast_target_position: Vector3

var player_bar_position: float = 50.0
var green_zone_position: float = 50.0
var green_zone_target: float = 50.0
var green_zone_lerp_speed: float = 4.0

var quota: int = 0
var reel_duration: float = 0.0

var _line_twitch: float = 0.0
var _bite_time: float = 0.0
var _reel_elapsed: float = 0.0
var _rod_tip_ref: Node3D = null

const LINE_SEGMENTS: int = 4


func is_reeling() -> bool:
	return current_state in [State.BITE, State.REELING]


func can_cast() -> bool:
	return current_state == State.IDLE


func on_fish_fled() -> void:
	if current_state not in [State.BITE, State.REELING]:
		return
	_snap_bobber_to_rod()
	$FishManager.cleanup()
	current_state = State.IDLE
	reel_failure.emit()
	_exit_reeling()


func apply_quota_penalty(amount: int) -> void:
	quota = max(0, quota - amount)
	quota_label.text = "Quota: %d" % quota


func _ready() -> void:
	bite_timer.one_shot = true
	bite_timer.timeout.connect(_on_bite_timer_timeout)
	bite_audio.stream = _generate_rumble_stream()

	casting_timer.one_shot = true
	casting_timer.timeout.connect(_on_casting_timer_timeout)

	green_zone_timer.wait_time = zone_move_interval
	green_zone_timer.one_shot = false
	green_zone_timer.timeout.connect(_on_green_zone_timer_timeout)

	reel_timer.one_shot = true
	reel_timer.timeout.connect(_on_reel_timer_timeout)

	quota_label.text = "Quota: 0"
	catch_feedback_manager.feedback_completed.connect(_on_catch_feedback_completed)

	if not InputMap.has_action("reel"):
		InputMap.add_action("reel")
		var reel_mouse := InputEventMouseButton.new()
		reel_mouse.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("reel", reel_mouse)

	if not InputMap.has_action("cast_line"):
		InputMap.add_action("cast_line")
	var cast_mouse := InputEventMouseButton.new()
	cast_mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("cast_line", cast_mouse)

	reel_meter.visible = false

	line_material = ORMMaterial3D.new()
	line_material.albedo_color = Color(1.0, 1.0, 1.0)
	line_material.shading_mode = ORMMaterial3D.SHADING_MODE_UNSHADED
	line_material.cull_mode = ORMMaterial3D.CULL_DISABLED



func set_rod_tip(tip: Node3D) -> void:
	_rod_tip_ref = tip


func _get_rod_tip_position() -> Vector3:
	if _rod_tip_ref and is_instance_valid(_rod_tip_ref):
		return _rod_tip_ref.global_position
	return global_position + Vector3(0, 1.6, -0.5)


func _get_bobber_position() -> Vector3:
	if current_state == State.REELING:
		var fish: Node3D = $FishManager.get_fish()
		if is_instance_valid(fish):
			return fish.position
	if is_instance_valid(bobber_node):
		return bobber_node.position
	return cast_target_position


func _process(delta: float) -> void:
	match current_state:
		State.CASTING, State.WAITING, State.BITE:
			_update_bobber()
			_rebuild_line()

			if current_state == State.BITE:
				_bite_time += delta
				if _bite_time >= 2.5:
					_snap_bobber_to_rod()
					current_state = State.IDLE
					$FishManager.cleanup()
					reel_failure.emit()
					return

				if Input.is_action_just_pressed("reel"):
					_enter_reeling()

			if current_state == State.WAITING and Input.is_action_just_pressed("reel"):
				bite_timer.stop()
				_snap_bobber_to_rod()
				current_state = State.IDLE

		State.REELING:
			_update_bobber()
			_reel_elapsed += delta
			_rebuild_line()

			var holding: bool = Input.is_action_pressed("reel")

			if holding:
				player_bar_position += player_rise_speed * delta
			else:
				player_bar_position -= player_fall_speed * delta

			player_bar_position = clamp(player_bar_position, 0.0, 100.0)

			green_zone_position = lerp(green_zone_position, green_zone_target, green_zone_lerp_speed * delta)
			_update_reel_meter()

		State.IDLE:
			if is_instance_valid(bobber_node):
				bobber_node.position = _get_rod_tip_position() + Vector3(0, -0.1, 0)
				_rebuild_line()


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
	_reel_elapsed = 0.0
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
	var was_success: bool = _is_bar_in_zone()
	if was_success:
		current_state = State.SUCCESS
		quota += 1
		quota_label.text = "Quota: %d" % quota
		reel_success.emit(quota)
		_exit_reeling()
		$FishManager.cleanup()
		catch_feedback_manager.play_catch_success()
	else:
		_snap_bobber_to_rod()
		$FishManager.cleanup()
		current_state = State.IDLE
		reel_failure.emit()
		_exit_reeling()
	print("Reel ended. State: %s, Quota: %d" % ["SUCCESS" if was_success else "ESCAPE", quota])


func cast(from_position: Vector3, forward_direction: Vector3) -> void:
	if current_state in [State.BITE, State.REELING, State.SUCCESS]:
		_exit_reeling()

	_cleanup_all()

	current_state = State.CASTING

	var random_distance: float = randf_range(min_cast_distance, max_cast_distance)
	cast_target_position = from_position + (forward_direction * random_distance)
	cast_target_position.y = 0.0

	_create_bobber(cast_target_position)
	_create_line_node()
	_rebuild_line()

	casting_timer.start(0.3)
	print("Cast: line in water, entering CASTING state")


func _on_casting_timer_timeout() -> void:
	if current_state != State.CASTING:
		return
	current_state = State.WAITING
	var delay: float = randf_range(min_bite_delay, max_bite_delay)
	bite_timer.start(delay)
	print("Cast: waiting %.2f seconds for bite" % delay)


func _on_bite_timer_timeout() -> void:
	current_state = State.BITE
	_bite_time = 0.0
	if is_instance_valid(bobber_node):
		bobber_node.visible = true
	_play_bite_feedback()
	$FishManager.spawn(cast_target_position)
	bite_occurred.emit(cast_target_position)
	print("Bite! Press left mouse to start reeling")


func _create_line_node() -> void:
	visual_line_node = MeshInstance3D.new()
	get_tree().root.add_child(visual_line_node)
	visual_line_node.material_override = line_material


func _rebuild_line() -> void:
	if not is_instance_valid(visual_line_node):
		return

	var start := _get_rod_tip_position()
	var end := _get_bobber_position()

	line_material.albedo_color.a = 1.0

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)

	var line_width: float = 0.025
	var dir := (end - start).normalized()
	var right := dir.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.001:
		right = Vector3.RIGHT
	var half_w := right * line_width * 0.5

	for i in range(LINE_SEGMENTS + 1):
		var t := float(i) / float(LINE_SEGMENTS)
		var pos := start.lerp(end, t)
		if t > 0.0 and t < 1.0:
			pos.y += sin(t * PI * LINE_SEGMENTS) * _line_twitch

		st.add_vertex(pos - half_w)
		st.add_vertex(pos + half_w)

	visual_line_node.mesh = st.commit()


func _create_bobber(position: Vector3) -> void:
	bobber_node = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.04
	sphere.height = 0.08
	bobber_node.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.2, 0.2)
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	bobber_node.material_override = mat

	bobber_node.position = position
	get_tree().root.add_child(bobber_node)


func _update_bobber() -> void:
	if current_state == State.REELING:
		var fish: Node3D = $FishManager.get_fish()
		if is_instance_valid(fish):
			var t := _reel_elapsed / reel_duration if reel_duration > 0 else 1.0
			var rod_pos := _get_rod_tip_position()
			var pos := rod_pos.lerp(cast_target_position, 1.0 - t)
			pos.y = cast_target_position.y
			var xz_dist := Vector2(pos.x - rod_pos.x, pos.z - rod_pos.z).length()
			if xz_dist < 1.0:
				pos.y = lerp(cast_target_position.y, rod_pos.y, 1.0 - xz_dist / 1.0)
			fish.position = pos
		if is_instance_valid(bobber_node):
			bobber_node.visible = false
		return

	if not is_instance_valid(bobber_node):
		return

	bobber_node.position = _get_bobber_position()
	if current_state == State.BITE:
		bobber_node.position.y += sin(_bite_time * 3.0) * 0.008


func _play_bite_feedback() -> void:
	bite_audio.stop()
	bite_audio.play()

	_line_twitch = 0.0
	var tw := create_tween()
	tw.tween_property(self, "_line_twitch", 0.3, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_line_twitch", 0.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _cleanup_bobber() -> void:
	if is_instance_valid(bobber_node):
		bobber_node.queue_free()
		bobber_node = null


func _cleanup_line() -> void:
	if is_instance_valid(visual_line_node):
		visual_line_node.queue_free()
		visual_line_node = null
	_line_twitch = 0.0


func _cleanup_all() -> void:
	_cleanup_line()
	_cleanup_bobber()
	if casting_timer:
		casting_timer.stop()
	$FishManager.cleanup()


func _snap_bobber_to_rod() -> void:
	if is_instance_valid(bobber_node):
		bobber_node.visible = true
		bobber_node.position = _get_rod_tip_position() + Vector3(0, -0.1, 0)
	_rebuild_line()


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


func _on_catch_feedback_completed() -> void:
	if current_state == State.SUCCESS:
		_snap_bobber_to_rod()
		current_state = State.IDLE
