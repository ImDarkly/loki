extends GutTest

class MockInteractable extends InteractableComponent:
	var can_interact_result: bool = true

	func can_interact(_interactor: Node) -> bool:
		return can_interact_result


var player
var mock_interactable_node
var mock_component
var mock_gated_component


func before_each() -> void:
	load("res://systems/interactable/interactable_component.gd")
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

	var voice_chat_manager := Node.new()
	voice_chat_manager.name = "VoiceChatManager"
	voice_chat_manager.set_script(load("res://systems/voice_chat/voice_chat_manager.gd"))
	player_node.add_child(voice_chat_manager)

	var health_component = load("res://systems/health/health_component.gd").new()
	health_component.name = "HealthComponent"
	player_node.add_child(health_component)

	var spectate_camera := Node3D.new()
	spectate_camera.name = "SpectateCamera"
	player_node.add_child(spectate_camera)

	var spectate_cam_camera := Camera3D.new()
	spectate_cam_camera.name = "Camera3D"
	spectate_camera.add_child(spectate_cam_camera)

	player_node.set_script(load("res://entities/player/player.gd"))

	player = autofree(player_node)
	add_child(player)
	await get_tree().process_frame

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	mock_interactable_node = Node.new()
	mock_interactable_node.name = "MockInteractable"
	add_child(mock_interactable_node)

	mock_component = load("res://systems/interactable/interactable_component.tscn").instantiate()
	mock_component.prompt_text = "Test Interact"
	mock_interactable_node.add_child(mock_component)

	mock_gated_component = MockInteractable.new()
	mock_gated_component.prompt_text = "Gated"
	mock_gated_component.can_interact_result = false
	mock_interactable_node.add_child(mock_gated_component)


func test_find_component_on_direct_child() -> void:
	var found = player._find_interactable_component(mock_interactable_node)
	assert_not_null(found, "Should find InteractableComponent on the node")
	assert_eq(found, mock_component, "Found component should be the mock")


func test_find_component_on_self() -> void:
	var found = player._find_interactable_component(mock_component)
	assert_not_null(found, "Should find component when searching from the component itself")
	assert_eq(found, mock_component, "Should find the correct component")


func test_find_component_returns_null_when_none() -> void:
	var empty_node := Node.new()
	add_child(empty_node)
	var found = player._find_interactable_component(empty_node)
	assert_null(found, "Should return null when no InteractableComponent exists")


func test_find_component_on_nested_parent() -> void:
	var grandparent := Node.new()
	var parent := Node.new()
	grandparent.add_child(parent)

	mock_interactable_node.get_parent().remove_child(mock_interactable_node)
	parent.add_child(mock_interactable_node)
	add_child(grandparent)

	var found = player._find_interactable_component(mock_interactable_node)
	assert_not_null(found, "Should find component on deeply nested node")


func test_prompt_visible_when_target_set() -> void:
	assert_not_null(player._interact_prompt, "Interact prompt should exist")
	var label = player._interact_prompt.get_node_or_null("PromptLabel") as Label
	assert_not_null(label, "PromptLabel should exist")

	player._target_interactable = mock_component
	player._update_prompt_visibility()

	assert_true(label.visible, "Prompt should be visible when target is set")
	assert_true(label.text.contains("Test Interact"), "Prompt should show component's prompt_text")


func test_prompt_hidden_when_target_null() -> void:
	assert_not_null(player._interact_prompt, "Interact prompt should exist")
	var label = player._interact_prompt.get_node_or_null("PromptLabel") as Label
	assert_not_null(label, "PromptLabel should exist")

	player._target_interactable = mock_component
	player._update_prompt_visibility()
	assert_true(label.visible, "Prompt should be visible initially")

	player._target_interactable = null
	player._update_prompt_visibility()
	assert_false(label.visible, "Prompt should be hidden when target is null")


func test_interact_emits_signal_on_target() -> void:
	player._target_interactable = mock_component

	watch_signals(mock_component)
	var mouse_event := InputEventMouseButton.new()
	mouse_event.button_index = MOUSE_BUTTON_RIGHT
	mouse_event.pressed = true
	player._unhandled_input(mouse_event)

	assert_signal_emitted(mock_component, "interacted")
	assert_signal_emit_count(mock_component, "interacted", 1)


func test_interact_passes_player_as_interactor() -> void:
	player._target_interactable = mock_component

	watch_signals(mock_component)
	var mouse_event := InputEventMouseButton.new()
	mouse_event.button_index = MOUSE_BUTTON_RIGHT
	mouse_event.pressed = true
	player._unhandled_input(mouse_event)

	assert_signal_emitted_with_parameters(mock_component, "interacted", [player])


func test_no_signal_when_no_target() -> void:
	var signal_fired := false
	mock_component.interacted.connect(func(_interactor) -> void:
		signal_fired = true
	)

	var mouse_event := InputEventMouseButton.new()
	mouse_event.button_index = MOUSE_BUTTON_RIGHT
	mouse_event.pressed = true
	player._unhandled_input(mouse_event)

	assert_false(signal_fired, "Signal should not fire when no interactable targeted")
	assert_null(player._target_interactable, "Target should be null")


func test_prompt_shows_right_click_prefix() -> void:
	player._target_interactable = mock_component
	player._update_prompt_visibility()
	var label = player._interact_prompt.get_node_or_null("PromptLabel") as Label
	assert_not_null(label, "PromptLabel should exist")
	assert_true(label.text.begins_with("[Right-click]"), "Prompt should start with [Right-click]")


func test_prompt_hidden_when_can_interact_false() -> void:
	player._target_interactable = mock_gated_component
	player._update_prompt_visibility()
	var label = player._interact_prompt.get_node_or_null("PromptLabel") as Label
	assert_not_null(label, "PromptLabel should exist")
	assert_false(label.visible, "Prompt should be hidden when can_interact returns false")


func test_interact_blocked_when_can_interact_false() -> void:
	player._target_interactable = mock_gated_component

	watch_signals(mock_gated_component)
	var mouse_event := InputEventMouseButton.new()
	mouse_event.button_index = MOUSE_BUTTON_RIGHT
	mouse_event.pressed = true
	player._unhandled_input(mouse_event)

	assert_signal_not_emitted(mock_gated_component, "interacted", "Signal should not fire when can_interact returns false")
