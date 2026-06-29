extends Node3D

var _fish_node: Node3D = null


func spawn(position: Vector3) -> void:
	cleanup()

	_fish_node = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.3, 0.1, 0.5)

	var mat := ORMMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.5, 0.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat

	_fish_node.mesh = mesh
	_fish_node.position = position + Vector3(0, 0.05, 0)
	get_tree().root.add_child(_fish_node)


func get_fish() -> Node3D:
	return _fish_node


func cleanup() -> void:
	if is_instance_valid(_fish_node):
		_fish_node.queue_free()
		_fish_node = null
