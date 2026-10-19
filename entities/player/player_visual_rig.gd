class_name PlayerVisualRig extends Node3D

signal rig_ready

@onready var body_mesh: Node3D = $Knight
@onready var _locomotion_animation: AnimationPlayer = $PlayerLocomotionAnimation/AnimationPlayer
@onready var _general_animations: Node = $GeneralAnimations
@onready var _movement_animations: Node = $MovementAnimations

var head: Node3D
var camera: Camera3D
var right_item_anchor: Node3D
var rod_pivot: Node3D
var _body_meshes: Array[MeshInstance3D] = []
var held_item_transform := Transform3D(Basis.from_euler(Vector3(0.0, deg_to_rad(90.0), 0.0)), Vector3(0.0, 0.02, -0.12))
var rod_hand_transform := Transform3D(Basis.from_euler(Vector3(deg_to_rad(45.0), 0.0, 0.0)), Vector3(0.0, 0.02, -0.08))

const LOCOMOTION_BLEND_TIME := 0.15
const LOCOMOTION_ANIMATIONS := {
	PlayerLocomotionAnimation.State.IDLE: &"general/Idle_A",
	PlayerLocomotionAnimation.State.WALK: &"movement/Walking_A",
	PlayerLocomotionAnimation.State.JUMP: &"movement/Jump_Start",
	PlayerLocomotionAnimation.State.AIRBORNE: &"movement/Jump_Idle",
	PlayerLocomotionAnimation.State.LAND: &"movement/Jump_Land",
}

const LOOPING_LOCOMOTION_ANIMATIONS := [
	&"general/Idle_A",
	&"movement/Walking_A",
	&"movement/Jump_Idle",
]


func _ready() -> void:
	body_mesh.rotation.y = PI
	_add_animation_library(_general_animations, &"general")
	_add_animation_library(_movement_animations, &"movement")
	_set_looping_locomotion_animations()
	for mesh in body_mesh.find_children("*", "MeshInstance3D", true, false):
		_body_meshes.append(mesh as MeshInstance3D)

	var skeleton := _find_skeleton(body_mesh)
	if skeleton == null:
		push_error("KayKit Knight is missing its Skeleton3D")
		return

	var head_attachment := _create_attachment(skeleton, "HeadAttachment", &"head")
	head = Node3D.new()
	head.name = "LookPivot"
	head.rotation.y = PI
	head_attachment.add_child(head)

	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.near = 0.1
	camera.far = 1000.0
	head.add_child(camera)

	right_item_anchor = _create_attachment(skeleton, "RightItemAnchor", &"handslot.r")
	_setup_fishing_rod()
	rig_ready.emit()


func apply_locomotion_state(state: PlayerLocomotionAnimation.State) -> void:
	var animation: StringName = LOCOMOTION_ANIMATIONS.get(state, &"general/Idle_A")
	if _locomotion_animation.current_animation != animation:
		_locomotion_animation.play(animation, LOCOMOTION_BLEND_TIME)


func get_locomotion_animation_length(state: PlayerLocomotionAnimation.State) -> float:
	var animation: StringName = LOCOMOTION_ANIMATIONS.get(state, &"general/Idle_A")
	return _locomotion_animation.get_animation(animation).length


func _add_animation_library(source: Node, library_name: StringName) -> void:
	var players := source.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	var source_player := players[0] as AnimationPlayer
	var library := source_player.get_animation_library(&"")
	if library:
		_locomotion_animation.add_animation_library(library_name, library)


func _set_looping_locomotion_animations() -> void:
	for animation_name in LOOPING_LOCOMOTION_ANIMATIONS:
		_locomotion_animation.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR


func set_local_view(is_local: bool) -> void:
	for mesh in _body_meshes:
		mesh.visible = not is_local


func attach_held_item(item: Node3D) -> void:
	item.transform = held_item_transform
	right_item_anchor.add_child(item)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var skeleton := _find_skeleton(child)
		if skeleton:
			return skeleton
	return null


func _create_attachment(skeleton: Skeleton3D, attachment_name: String, bone: StringName) -> BoneAttachment3D:
	var attachment := BoneAttachment3D.new()
	attachment.name = attachment_name
	attachment.bone_name = bone
	skeleton.add_child(attachment)
	return attachment


func _setup_fishing_rod() -> void:
	rod_pivot = Node3D.new()
	rod_pivot.name = "FishingRod"
	rod_pivot.transform = rod_hand_transform

	var rod_mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.height = 0.8
	cylinder.top_radius = 0.005
	cylinder.bottom_radius = 0.015
	rod_mesh.mesh = cylinder
	rod_mesh.rotation.x = deg_to_rad(-90.0)
	rod_mesh.position = Vector3(0, 0, -0.4)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.2, 0.1)
	material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	rod_mesh.material_override = material
	rod_pivot.add_child(rod_mesh)

	var tip := Marker3D.new()
	tip.name = "RodTip"
	tip.position = Vector3(0, 0, -0.8)
	rod_pivot.add_child(tip)
	right_item_anchor.add_child(rod_pivot)
