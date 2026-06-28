extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var fishing_mechanic: Node3D = $FishingMechanic


func _ready() -> void:
	randomize()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if not InputMap.has_action("cast_line"):
		InputMap.add_action("cast_line")
		var mouse_event = InputEventMouseButton.new()
		mouse_event.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("cast_line", mouse_event)


func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("cast_line"):
		fishing_mechanic.cast(global_position, -global_transform.basis.z)

	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		fishing_mechanic.cast(global_position, -global_transform.basis.z)

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * 0.002)
		camera.rotate_x(-event.relative.y * 0.002)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))
