class_name PlayerVisualRig extends Node3D

signal rig_ready

@onready var body_mesh: Node3D = $Knight
@onready var _locomotion_animation: AnimationPlayer = $PlayerLocomotionAnimation/AnimationPlayer
@onready var _fishing_animation: AnimationPlayer = $PlayerFishingAnimation/AnimationPlayer
@onready var _general_animations: Node = $GeneralAnimations
@onready var _movement_animations: Node = $MovementAnimations

var head: Node3D
var camera: Camera3D
var right_item_anchor: Node3D
var rod_pivot: Node3D
var _body_meshes: Array[MeshInstance3D] = []
var _locomotion_clip: StringName = &"general/Idle_A"
var _fishing_active := false
var _tools_loaded := false
var held_item_transform := Transform3D(Basis.from_euler(Vector3(0.0, deg_to_rad(90.0), 0.0)), Vector3(0.0, 0.02, -0.12))
var rod_hand_transform := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE / CHARACTER_SCALE), Vector3.ZERO)

const CHARACTER_SCALE := 0.5
const LOCOMOTION_BLEND_TIME := 0.15
const TOOLS_ANIMATION_PATH := "res://entities/player/assets/kaykit_animations/Rig_Medium_Tools.glb"
const FISHING_ROD_PATH := "res://entities/player/assets/quaternius/FishingRod_Lvl1.glb"
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

const FISHING_ANIMATIONS := {
	PlayerFishingAnimation.State.IDLE: &"tools/Fishing_Idle",
	PlayerFishingAnimation.State.CAST: &"tools/Fishing_Cast",
	PlayerFishingAnimation.State.WAIT: &"tools/Fishing_Idle",
	PlayerFishingAnimation.State.BITE: &"tools/Fishing_Bite",
	PlayerFishingAnimation.State.REEL: &"tools/Fishing_Reeling",
	PlayerFishingAnimation.State.STRUGGLE: &"tools/Fishing_Struggling",
	PlayerFishingAnimation.State.TUG: &"tools/Fishing_Tug",
	PlayerFishingAnimation.State.CATCH: &"tools/Fishing_Catch",
}

const LOOPING_FISHING_ANIMATIONS := [
	&"tools/Fishing_Idle",
	&"tools/Fishing_Reeling",
	&"tools/Fishing_Struggling",
]


func _ready() -> void:
	scale = Vector3.ONE * CHARACTER_SCALE
	body_mesh.rotation.y = PI
	_add_animation_library(_general_animations, &"general")
	_add_animation_library(_movement_animations, &"movement")
	_tools_loaded = _load_tools_animations()
	_set_looping_locomotion_animations()
	_set_looping_fishing_animations()
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
	_locomotion_clip = animation
	if _fishing_active:
		return
	if not _locomotion_animation.is_playing() or _locomotion_animation.current_animation != animation:
		_locomotion_animation.play(animation, LOCOMOTION_BLEND_TIME)


func get_locomotion_animation_length(state: PlayerLocomotionAnimation.State) -> float:
	var animation: StringName = LOCOMOTION_ANIMATIONS.get(state, &"general/Idle_A")
	return _locomotion_animation.get_animation(animation).length


func apply_fishing_state(state: PlayerFishingAnimation.State) -> void:
	if state == PlayerFishingAnimation.State.IDLE:
		_fishing_active = false
		_fishing_animation.stop()
		if not _locomotion_animation.is_playing():
			_locomotion_animation.play(_locomotion_clip, LOCOMOTION_BLEND_TIME)
		return
	if not _tools_loaded:
		return
	var animation: StringName = FISHING_ANIMATIONS.get(state, &"tools/Fishing_Idle")
	if not _fishing_animation.has_animation(animation):
		return
	_fishing_active = true
	_locomotion_animation.stop()
	if not _fishing_animation.is_playing() or _fishing_animation.current_animation != animation:
		_fishing_animation.play(animation, LOCOMOTION_BLEND_TIME)


func _add_animation_library(source: Node, library_name: StringName, target: AnimationPlayer = null) -> void:
	if target == null:
		target = _locomotion_animation
	var players := source.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	var source_player := players[0] as AnimationPlayer
	var library := source_player.get_animation_library(&"")
	if library:
		target.add_animation_library(library_name, library)


func _load_tools_animations() -> bool:
	if not ResourceLoader.exists(TOOLS_ANIMATION_PATH, "PackedScene"):
		push_error("Fishing animation setup error: missing %s. Install and import it as documented in ASSETS.md." % TOOLS_ANIMATION_PATH)
		return false
	var tools_scene := ResourceLoader.load(TOOLS_ANIMATION_PATH, "PackedScene") as PackedScene
	if tools_scene == null:
		push_error("Fishing animation setup error: could not load %s. Reimport it as documented in ASSETS.md." % TOOLS_ANIMATION_PATH)
		return false
	var tools_animations := tools_scene.instantiate()
	_add_animation_library(tools_animations, &"tools", _fishing_animation)
	tools_animations.free()
	return _fishing_animation.has_animation(&"tools/Fishing_Idle")


func _set_looping_locomotion_animations() -> void:
	for animation_name in LOOPING_LOCOMOTION_ANIMATIONS:
		_locomotion_animation.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR


func _set_looping_fishing_animations() -> void:
	for animation_name in LOOPING_FISHING_ANIMATIONS:
		if _fishing_animation.has_animation(animation_name):
			_fishing_animation.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR


func set_local_view(is_local: bool) -> void:
	for mesh in _body_meshes:
		mesh.visible = not is_local


func apply_rod_tension(intensity: float) -> void:
	rod_pivot.transform = rod_hand_transform
	rod_pivot.basis = rod_hand_transform.basis * Basis(Vector3.FORWARD, deg_to_rad(25.0) * clampf(intensity, 0.0, 1.0))


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

	var tip := Marker3D.new()
	tip.name = "RodTip"
	tip.position = Vector3(0, 0.8, 0)
	rod_pivot.add_child(tip)
	right_item_anchor.add_child(rod_pivot)

	if not ResourceLoader.exists(FISHING_ROD_PATH, "PackedScene"):
		push_error("Fishing rod setup error: missing %s. Install and import it as documented in ASSETS.md." % FISHING_ROD_PATH)
		return
	var rod_scene := ResourceLoader.load(FISHING_ROD_PATH, "PackedScene") as PackedScene
	if rod_scene == null:
		push_error("Fishing rod setup error: could not load %s. Reimport it as documented in ASSETS.md." % FISHING_ROD_PATH)
		return
	var rod_model := rod_scene.instantiate() as Node3D
	rod_model.name = "RodModel"
	# Fishing clips author the rod along handslot.r's local +Y axis.
	rod_model.rotation.x = atan2(0.188626, 4.9163)
	rod_model.scale = Vector3.ONE * (0.8 / Vector2(4.9163, 0.188626).length())
	rod_pivot.add_child(rod_model)
