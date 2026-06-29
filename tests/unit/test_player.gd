extends GutTest

var player: CharacterBody3D


func before_each() -> void:
	var player_node := CharacterBody3D.new()

	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.6, 0)
	player_node.add_child(head)

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	head.add_child(camera)

	var hand_left := MeshInstance3D.new()
	hand_left.name = "HandLeft"
	head.add_child(hand_left)

	var hand_right := MeshInstance3D.new()
	hand_right.name = "HandRight"
	head.add_child(hand_right)

	var body_mesh := MeshInstance3D.new()
	body_mesh.name = "BodyMesh"
	player_node.add_child(body_mesh)

	var fishing_scene = load("res://systems/fishing/fishing_mechanic.tscn")
	var fishing_mechanic = autofree(fishing_scene.instantiate())
	fishing_mechanic.name = "FishingMechanic"
	player_node.add_child(fishing_mechanic)

	player_node.set_script(load("res://entities/player/player.gd"))

	player = autofree(player_node)
	add_child(player)
	await get_tree().process_frame

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_is_yelling_starts_false() -> void:
	assert_false(player.is_yelling, "is_yelling should be false initially")


func test_is_yelling_true_when_yell_pressed() -> void:
	Input.action_press("yell")
	player._process(0.016)

	assert_true(player.is_yelling, "is_yelling should be true when yell action is pressed")

	Input.action_release("yell")


func test_is_yelling_false_when_yell_released() -> void:
	Input.action_press("yell")
	player._process(0.016)

	Input.action_release("yell")
	player._process(0.016)

	assert_false(player.is_yelling, "is_yelling should be false when yell action is released")
