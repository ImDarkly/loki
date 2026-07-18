extends Node3D

enum State { IDLE, CASTING, WAITING, BITE, SUCCESS }

signal bite_occurred(fish_position: Vector3)
signal reel_success(quota: int)
signal reel_failure()
signal personal_catch_changed(count: int)

@export var min_bite_delay: float = 3.0
@export var max_bite_delay: float = 8.0

@export var gravity_strength: float = 9.8

var _current_flight_duration: float

@onready var bite_timer: Timer = $BiteTimer
@onready var bite_audio: AudioStreamPlayer = $BiteAudio
@onready var casting_timer: Timer = $CastingTimer
@onready var quota_label: Label = $CanvasLayer/QuotaLabel
@onready var personal_label: Label = $CanvasLayer/PersonalLabel
@onready var catch_feedback_manager: Node3D = $CatchFeedbackManager

var current_state: State = State.IDLE
var _base_min_bite_delay: float
var _base_max_bite_delay: float
var visual_line_node: MeshInstance3D = null
var line_material: ORMMaterial3D = null
var bobber_node: MeshInstance3D = null
var cast_target_position: Vector3
var _flight_start_position: Vector3
var _flight_start_time: int
var _launch_velocity: Vector3

var personal_catch_count: int = 0

var _quota_manager_ref: Node3D = null
var _zone_manager_ref: Node3D = null
var _active_zone_index: int = -1

var is_local_render: bool = true:
	set(value):
		is_local_render = value
		if is_node_ready():
			$CanvasLayer.visible = value
var _prev_remote_state: int = -1

var _line_twitch: float = 0.0
var _bite_time: float = 0.0
var _rod_tip_ref: Node3D = null
var _cached_fishing_active: bool = true

const LINE_SEGMENTS: int = 4


func can_cast() -> bool:
	return current_state == State.IDLE and _is_fishing_active()


func _is_fishing_active() -> bool:
	var rm := get_node_or_null("/root/main/RoundManager")
	if rm != null:
		_cached_fishing_active = rm.fishing_active
	return _cached_fishing_active


func on_fish_fled(target_client_id: int = -1) -> void:
	if target_client_id != -1 and target_client_id != _get_owner_client_id():
		return
	if not is_local_render:
		return
	if current_state not in [State.BITE]:
		return
	_report_zone_leave()
	_snap_bobber_to_rod()
	$FishManager.cleanup()
	current_state = State.IDLE
	reel_failure.emit()


func _on_quota_updated(value: int) -> void:
	quota_label.text = "Quota: %d" % value


func _on_personal_catch_changed(count: int) -> void:
	personal_label.text = "Your catches: %d" % count


func _report_catch_to_host(amount: int) -> void:
	if not is_instance_valid(_quota_manager_ref):
		return
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_quota_manager_ref.report_catch(amount)
	else:
		_quota_manager_ref.report_catch.rpc(amount)


func _try_find_quota_manager() -> void:
	if _quota_manager_ref:
		return
	var qm := get_node_or_null("/root/main/QuotaManager")
	if qm:
		_quota_manager_ref = qm
		qm.quota_updated.connect(_on_quota_updated)


func _try_find_zone_manager() -> void:
	if _zone_manager_ref:
		return
	var zm := get_tree().root.find_child("ZoneManager", true, false)
	if zm:
		_zone_manager_ref = zm


func _ready() -> void:
	_try_find_quota_manager()
	_try_find_zone_manager()
	bite_timer.one_shot = true
	bite_timer.timeout.connect(_on_bite_timer_timeout)
	bite_audio.stream = _generate_rumble_stream()

	casting_timer.one_shot = true
	casting_timer.timeout.connect(_on_casting_timer_timeout)

	quota_label.text = "Quota: 0"
	personal_label.text = "Your catches: 0"
	personal_catch_changed.connect(_on_personal_catch_changed)
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

	_base_min_bite_delay = min_bite_delay
	_base_max_bite_delay = max_bite_delay

	line_material = ORMMaterial3D.new()
	line_material.albedo_color = Color(1.0, 1.0, 1.0)
	line_material.shading_mode = ORMMaterial3D.SHADING_MODE_UNSHADED
	line_material.cull_mode = ORMMaterial3D.CULL_DISABLED


func set_rod_tip(tip: Node3D) -> void:
	_rod_tip_ref = tip


func get_rod_tip_position() -> Vector3:
	return _get_rod_tip_position()


func _get_rod_tip_position() -> Vector3:
	if _rod_tip_ref and is_instance_valid(_rod_tip_ref):
		return _rod_tip_ref.global_position
	return global_position + Vector3(0, 1.6, -0.5)


static func _compute_launch_velocity(
	start: Vector3, target: Vector3, duration: float, gravity: float
) -> Vector3:
	var g := Vector3(0, -gravity, 0)
	return (target - start - 0.5 * g * duration * duration) / duration


func _get_bobber_position() -> Vector3:
	if current_state == State.CASTING:
		var elapsed := (Time.get_ticks_msec() - _flight_start_time) / 1000.0
		elapsed = min(elapsed, _current_flight_duration)
		return _flight_start_position \
			+ _launch_velocity * elapsed \
			+ 0.5 * Vector3(0, -gravity_strength, 0) * elapsed * elapsed
	if current_state in [State.WAITING, State.BITE]:
		return cast_target_position
	if is_instance_valid(bobber_node):
		return bobber_node.position
	return cast_target_position


func _handle_remote_transition(to_state: int) -> void:
	match to_state:
		State.CASTING:
			_cleanup_all()
			_launch_velocity = _compute_launch_velocity(
				_flight_start_position, cast_target_position, _current_flight_duration, gravity_strength
			)
			_flight_start_time = Time.get_ticks_msec()
			_create_bobber(cast_target_position)
			_create_line_node()
			_rebuild_line()

		State.BITE:
			if is_instance_valid(bobber_node):
				bobber_node.visible = true
			_line_twitch = 0.0
			var tw := create_tween()
			tw.tween_property(self, "_line_twitch", 0.3, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_property(self, "_line_twitch", 0.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			$FishManager.spawn(cast_target_position)

		State.IDLE, State.SUCCESS:
			_snap_bobber_to_rod()
			$FishManager.cleanup()


func _process(delta: float) -> void:
	if not is_local_render and current_state != _prev_remote_state:
		_handle_remote_transition(current_state)
		_prev_remote_state = current_state

	match current_state:
		State.CASTING, State.WAITING, State.BITE:
			_update_bobber()
			_rebuild_line()

			if current_state == State.BITE:
				_bite_time += delta
				if is_local_render:
					if _bite_time >= 2.5:
						_report_zone_leave()
						_snap_bobber_to_rod()
						current_state = State.IDLE
						$FishManager.cleanup()
						reel_failure.emit()
						return

				if is_local_render and Input.is_action_just_pressed("reel"):
					current_state = State.SUCCESS
					personal_catch_count += 1
					personal_catch_changed.emit(personal_catch_count)
					reel_success.emit(personal_catch_count)
					_report_zone_leave()
					$FishManager.cleanup()
					catch_feedback_manager.play_catch_success()

			if is_local_render and current_state == State.WAITING and Input.is_action_just_pressed("reel"):
				bite_timer.stop()
				_report_zone_leave()
				_snap_bobber_to_rod()
				current_state = State.IDLE

		State.IDLE:
			if is_instance_valid(bobber_node):
				bobber_node.position = _get_rod_tip_position() + Vector3(0, -0.1, 0)
				_rebuild_line()


func cast(target_position: Vector3, flight_time: float) -> void:
	if current_state in [State.BITE, State.SUCCESS]:
		pass

	_report_zone_leave()
	_active_zone_index = -1
	_cleanup_all()

	current_state = State.CASTING

	cast_target_position = target_position
	cast_target_position.y = 0.0

	_current_flight_duration = flight_time
	_flight_start_position = _get_rod_tip_position()
	_flight_start_time = Time.get_ticks_msec()
	_launch_velocity = _compute_launch_velocity(
		_flight_start_position, cast_target_position, _current_flight_duration, gravity_strength
	)

	_create_bobber(_get_bobber_position())
	_create_line_node()
	_rebuild_line()

	casting_timer.start(_current_flight_duration)
	print("Cast: projectile arc, entering CASTING state")


func _on_casting_timer_timeout() -> void:
	if current_state != State.CASTING:
		return
	current_state = State.WAITING
	var zone_index := _get_zone_index_for_cast_target()
	if zone_index != _get_no_zone_index():
		_active_zone_index = zone_index
		_report_zone_enter(zone_index)
	var delay: float = randf_range(min_bite_delay, max_bite_delay)
	bite_timer.start(delay)
	print("Cast: waiting %.2f seconds for bite" % delay)


func _on_bite_timer_timeout() -> void:
	if _active_zone_index == -1:
		_report_zone_leave()
		current_state = State.IDLE
		_snap_bobber_to_rod()
		$FishManager.cleanup()
		catch_feedback_manager.play_dead_zone_feedback()
		return

	current_state = State.BITE
	_bite_time = 0.0
	if is_instance_valid(bobber_node):
		bobber_node.visible = true
	_play_bite_feedback()
	$FishManager.spawn(cast_target_position)
	bite_occurred.emit(cast_target_position)
	print("Bite! Press left mouse to catch")


func _get_zone_index_for_cast_target() -> int:
	_try_find_zone_manager()
	if not is_instance_valid(_zone_manager_ref):
		return _get_no_zone_index()
	return _zone_manager_ref.get_zone_index_for_point(cast_target_position)


func _get_no_zone_index() -> int:
	_try_find_zone_manager()
	if is_instance_valid(_zone_manager_ref) and _zone_manager_ref.has_method("get_no_zone_index"):
		return _zone_manager_ref.get_no_zone_index()
	return -1


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


func reset_for_restart() -> void:
	_report_zone_leave()
	_cleanup_all()
	bite_timer.stop()
	current_state = State.IDLE
	personal_catch_count = 0
	_active_zone_index = -1
	personal_catch_changed.emit(personal_catch_count)


func apply_bite_speed_multiplier(mult: float) -> void:
	min_bite_delay = _base_min_bite_delay / mult
	max_bite_delay = _base_max_bite_delay / mult


func reset_bite_speed() -> void:
	min_bite_delay = _base_min_bite_delay
	max_bite_delay = _base_max_bite_delay


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


func _get_owner_client_id() -> int:
	var parent_player := get_parent()
	if not (parent_player is Player):
		return -1
	if parent_player.spawn_index < game_manager.players.size():
		return game_manager.players[parent_player.spawn_index].id
	return -1


func _report_zone_enter(zone_index: int) -> void:
	if zone_index == -1:
		return
	_try_find_zone_manager()
	if not is_instance_valid(_zone_manager_ref):
		return
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_zone_manager_ref.enter_zone(zone_index)
	else:
		_zone_manager_ref.enter_zone.rpc(zone_index)


func _report_zone_leave() -> void:
	if _active_zone_index == -1:
		return
	_try_find_zone_manager()
	if not is_instance_valid(_zone_manager_ref):
		_active_zone_index = -1
		return
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_zone_manager_ref.leave_zone(_active_zone_index)
	else:
		_zone_manager_ref.leave_zone.rpc(_active_zone_index)
	_active_zone_index = -1
