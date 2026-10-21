extends Node3D

const MODEL_PATH := "res://systems/danger/assets/quaternius/Characters_Shark.gltf"

var _previous_position := Vector3.ZERO
var _has_position := false
var _heading := 0.0


func _ready() -> void:
	get_parent().visibility_changed.connect(_reset_position_sample)
	var scene: PackedScene
	if ResourceLoader.exists(MODEL_PATH):
		scene = load(MODEL_PATH) as PackedScene
	if scene == null:
		push_warning("Shark model missing or unimported. Install Characters_Shark.gltf following ASSETS.md, then open Godot to import it.")
		return
	var model := scene.instantiate() as Node3D
	model.name = "SharkModel"
	model.rotation.y = PI
	model.scale = Vector3.ONE * 0.5
	model.position.y = -0.7
	add_child(model)
	for player: AnimationPlayer in model.find_children("*", "AnimationPlayer", true, false):
		if player.has_animation("Swim"):
			player.get_animation("Swim").loop_mode = Animation.LOOP_LINEAR
			player.play("Swim")
			break


func _reset_position_sample() -> void:
	_has_position = false


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		_has_position = false
		return
	var current_position: Vector3 = get_parent().global_position
	if _has_position:
		var movement := current_position - _previous_position
		movement.y = 0.0
		if movement.length_squared() > 0.000001:
			_heading = atan2(-movement.x, -movement.z)
	else:
		_heading = 0.0
	_previous_position = current_position
	_has_position = true
	global_rotation = Vector3(0.0, _heading, 0.0)
