extends Node3D

@export var min_cast_distance: float = 5.0
@export var max_cast_distance: float = 15.0

var is_line_cast: bool = false
var visual_line_node: MeshInstance3D = null


func cast(from_position: Vector3, forward_direction: Vector3) -> void:
	is_line_cast = true

	var random_distance: float = randf_range(min_cast_distance, max_cast_distance)
	var target_position: Vector3 = from_position + (forward_direction * random_distance)
	target_position.y = 0.0

	create_visual_line(from_position, target_position)


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
