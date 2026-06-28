extends Node3D

enum State { IDLE, CASTING, BITE }

signal bite_occurred(fish_position: Vector3)

@export var min_cast_distance: float = 5.0
@export var max_cast_distance: float = 15.0
@export var min_bite_delay: float = 3.0
@export var max_bite_delay: float = 8.0

var current_state: State = State.IDLE
var is_line_cast: bool = false
var visual_line_node: MeshInstance3D = null
var fish_node: Node3D = null
var cast_target_position: Vector3

@onready var bite_timer: Timer = $BiteTimer
@onready var bite_audio: AudioStreamPlayer = $BiteAudio

var original_line_vertices: PackedVector3Array = []
var twitch_directions: PackedVector3Array = []
var active_twitch_tween: Tween = null

const LINE_SEGMENTS: int = 10


func _ready() -> void:
	bite_timer.one_shot = true
	bite_timer.timeout.connect(_on_bite_timer_timeout)
	bite_audio.stream = _generate_rumble_stream()


func cast(from_position: Vector3, forward_direction: Vector3) -> void:
	cleanup_fish()

	current_state = State.CASTING
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
	spawn_fish_placeholder(cast_target_position)
	bite_occurred.emit(cast_target_position)
	print("Bite! Fish spawned at %s" % cast_target_position)


func spawn_fish_placeholder(position: Vector3) -> void:
	if is_instance_valid(fish_node):
		fish_node.queue_free()

	fish_node = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.3, 0.1, 0.5)

	var mat := ORMMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.5, 0.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat

	fish_node.mesh = mesh
	fish_node.position = position + Vector3(0, 0.05, 0)
	get_tree().root.add_child(fish_node)


func cleanup_fish() -> void:
	if is_instance_valid(fish_node):
		fish_node.queue_free()
		fish_node = null


func create_visual_line(start_pos: Vector3, end_pos: Vector3) -> void:
	if is_instance_valid(visual_line_node):
		visual_line_node.queue_free()

	visual_line_node = MeshInstance3D.new()
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
