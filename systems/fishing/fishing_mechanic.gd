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


func _ready() -> void:
	bite_timer.one_shot = true
	bite_timer.timeout.connect(_on_bite_timer_timeout)


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
	var immediate_mesh: ImmediateMesh = ImmediateMesh.new()
	var material: ORMMaterial3D = ORMMaterial3D.new()

	material.albedo_color = Color(1.0, 1.0, 1.0)
	material.shading_mode = ORMMaterial3D.SHADING_MODE_UNSHADED

	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	immediate_mesh.surface_add_vertex(start_pos)
	immediate_mesh.surface_add_vertex(end_pos)
	immediate_mesh.surface_end()

	visual_line_node.mesh = immediate_mesh
	get_tree().root.add_child(visual_line_node)
