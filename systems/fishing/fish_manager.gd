extends Node3D

var _fish_node: Node3D = null
var _shadow_nodes: Array[Node3D] = []
var _shadow_angles: Array[float] = []
var _shadow_center: Vector3 = Vector3.ZERO

const SHADOW_RADIUS := 0.55
const SHADOW_Y_OFFSET := -0.35
const SHADOW_ANGULAR_SPEED := 1.5
const SHADOW_SCALE := Vector3(0.15, 0.15, 0.15)

const GOLDFISH_SCENE := preload("res://systems/fishing/assets/Goldfish.glb")
const CLOWNFISH_SCENE := preload("res://systems/fishing/assets/Clownfish.glb")
const SHADOW_MATERIAL := preload("res://systems/fishing/assets/fish_shadow_material.tres")


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


func spawn_shadows(center: Vector3) -> void:
	despawn_shadows()
	_shadow_center = center

	var scenes = [GOLDFISH_SCENE, CLOWNFISH_SCENE]
	for i in range(scenes.size()):
		var scene: PackedScene = scenes[i]
		var inst := scene.instantiate() as Node3D
		if not inst:
			continue

		_apply_shadow_material_recursive(inst)
		inst.scale = SHADOW_SCALE

		add_child(inst)
		inst.top_level = true
		_shadow_nodes.append(inst)
		_shadow_angles.append(float(i) * PI)
		_place_shadow_on_circle(i)


func _apply_shadow_material_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.material_override = SHADOW_MATERIAL
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_apply_shadow_material_recursive(child)


func despawn_shadows() -> void:
	for node in _shadow_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_shadow_nodes.clear()
	_shadow_angles.clear()
	_shadow_center = Vector3.ZERO


func has_shadows() -> bool:
	for node in _shadow_nodes:
		if is_instance_valid(node):
			return true
	return false


func _place_shadow_on_circle(index: int) -> void:
	var node := _shadow_nodes[index]
	if not is_instance_valid(node):
		return
	var angle := _shadow_angles[index]
	node.global_position = _shadow_center \
		+ Vector3(cos(angle) * SHADOW_RADIUS, SHADOW_Y_OFFSET, sin(angle) * SHADOW_RADIUS)
	var vel := Vector3(-sin(angle), 0.0, cos(angle))
	node.rotation.y = atan2(vel.x, vel.z)


func _process(delta: float) -> void:
	if _shadow_nodes.is_empty():
		return
	for i in range(_shadow_nodes.size()):
		var node := _shadow_nodes[i]
		if not is_instance_valid(node):
			continue
		_shadow_angles[i] += delta * SHADOW_ANGULAR_SPEED
		_place_shadow_on_circle(i)


func _exit_tree() -> void:
	cleanup()
	despawn_shadows()
