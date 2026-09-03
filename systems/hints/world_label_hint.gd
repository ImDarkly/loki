class_name WorldLabelHint
extends Node3D

const FADE_START: float = 12.0
const FADE_END: float = 20.0

@export var label_text: String = "":
	set(v):
		label_text = v
		if _label:
			_label.text = label_text

var _label: Label3D


func _ready() -> void:
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.double_sided = true
	_label.font_size = 48
	_label.outline_size = 12
	_label.pixel_size = 0.005
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.modulate = Color(1, 1, 1, 1)
	_label.outline_modulate = Color(0, 0, 0, 1)
	_label.position = Vector3(0, 0.9, 0)
	_label.text = label_text
	add_child(_label)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var d := global_position.distance_to(cam.global_position)
	var a := _compute_alpha(d, FADE_START, FADE_END)
	_label.modulate.a = a
	_label.outline_modulate.a = a
	_label.visible = a > 0.0


static func _compute_alpha(distance: float, fade_start: float, fade_end: float) -> float:
	if distance <= fade_start:
		return 1.0
	if distance >= fade_end:
		return 0.0
	return clamp(1.0 - (distance - fade_start) / (fade_end - fade_start), 0.0, 1.0)


static func compute_alpha(distance: float, fade_start: float, fade_end: float) -> float:
	return _compute_alpha(distance, fade_start, fade_end)
