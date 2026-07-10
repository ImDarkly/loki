extends GutTest

var player


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

	var voice_chat_manager := Node.new()
	voice_chat_manager.name = "VoiceChatManager"
	voice_chat_manager.set_script(load("res://systems/voice_chat/voice_chat_manager.gd"))
	player_node.add_child(voice_chat_manager)

	player_node.set_script(load("res://entities/player/player.gd"))

	player = autofree(player_node)
	add_child(player)
	await get_tree().process_frame

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_is_yelling_starts_false() -> void:
	assert_false(player.is_yelling, "is_yelling should be false initially")


func test_enable_player_turns_on_voice_chat_process() -> void:
	var vcm = player.get_node("VoiceChatManager")
	vcm.set_process(false)
	player._enable_player()
	assert_true(vcm.is_processing(), "VoiceChatManager process should be on after _enable_player")


func test_disable_player_turns_off_voice_chat_process() -> void:
	var vcm = player.get_node("VoiceChatManager")
	vcm.set_process(true)
	player._disable_player()
	assert_false(vcm.is_processing(), "VoiceChatManager process should be off after _disable_player")


func test_enable_player_connects_yelling_signal() -> void:
	player._enable_player()
	var vcm = player.get_node("VoiceChatManager")
	assert_true(vcm.yelling_state_changed.is_connected(player._on_yelling_state_changed), "yelling_state_changed should be connected after _enable_player")


func test_disable_player_disconnects_yelling_signal() -> void:
	player._enable_player()
	player._disable_player()
	var vcm = player.get_node("VoiceChatManager")
	assert_false(vcm.yelling_state_changed.is_connected(player._on_yelling_state_changed), "yelling_state_changed should be disconnected after _disable_player")


func test_sync_yelling_updates_is_yelling() -> void:
	player.is_yelling = false
	player.sync_yelling(true)
	assert_true(player.is_yelling, "is_yelling should be true after sync_yelling(true)")
	player.sync_yelling(false)
	assert_false(player.is_yelling, "is_yelling should be false after sync_yelling(false)")


func test_voice_chat_process_off_by_default_on_remote() -> void:
	player._disable_player()
	var vcm = player.get_node("VoiceChatManager")
	assert_false(vcm.is_processing(), "VoiceChatManager process should be off for remote player")
